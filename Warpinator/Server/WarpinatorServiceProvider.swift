//
//  WarpinatorServiceProvider.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-06.
//

import UIKit
import GRPC
import NIO



// MARK: Duplex Error
enum DuplexError: GRPCErrorProtocol {
    case UnknownRemote
    case DuplexNotEstablished
    case DuplexTimeout
    func makeGRPCStatus() -> GRPCStatus {
        
        switch self {
        case .UnknownRemote: return GRPCStatus(code: GRPCStatus.Code.failedPrecondition,
                                               message: description)
        case .DuplexNotEstablished: return GRPCStatus(code: GRPCStatus.Code.failedPrecondition,
                                                      message: description)
        case .DuplexTimeout: return GRPCStatus(code: GRPCStatus.Code.deadlineExceeded,
                                                      message: description)
        }
    }
    
    var description: String {
        switch self {
        case .UnknownRemote: return  "This remote is not known to the server"
        case .DuplexNotEstablished: return "This remote has not yet established duplex"
        case .DuplexTimeout: return "Duplex timed out"
        }
    }
}












//
// MARK: - WarpinatorServiceProvider
final public class WarpinatorServiceProvider: WarpProvider {
    
    private let DEBUG_TAG: String = "WarpinatorServiceProvider: "
    
    public var interceptors: WarpServerInterceptorFactoryProtocol?
    
    var remoteManager: RemoteManager?
    
    let duplexQueueLabel = "Serve_Duplex"
    lazy var duplexQueue = DispatchQueue(label: duplexQueueLabel, qos: .userInitiated)
    
    let avatarQueueLabel = "Serve_Avatar"
    lazy var sendingAvaratChunksQueue = DispatchQueue(label: avatarQueueLabel, qos: .utility)
    
    // MARK: - Duplex
    
    
    // MARK: v1
    // receive request for status of connection to remote specified in LookupName
    public func checkDuplexConnection(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        print(DEBUG_TAG+"(API_V1) Duplex is being checked by \(request.readableName) (\(request.id))")
        
        return checkDuplex(forUUID: request.id, context)
    }
    
    
    // MARK: v2
    // receive request for status of connection to remote specified in LookupName
    public func waitingForDuplex(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        print(DEBUG_TAG+"(API_V2) Duplex is being waited for by \(request.readableName) (\(request.id))")

        return checkDuplex(forUUID: request.id, context)  // duplexPromise.futureResult
    }
    
    
    // MARK: checkDuplex
    private func checkDuplex(forUUID uuid: String, _ context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        print(DEBUG_TAG+"checking duplex for uuid: \(uuid)")
        if let remote = self.remoteManager?.containsRemote(for: uuid) {
            
            print(DEBUG_TAG+"\t remote found (status: \(remote.details.status))")
            
            // return true if we're already connected, or also trying to connect
            if [.AquiringDuplex, .Connected].contains( remote.details.status ) {
                return context.eventLoop.makeSucceededFuture( .with{ $0.response = true } )
            }
            
            print(DEBUG_TAG+"\t re-initiating connection...")
            remote.startupConnection()
        }
        
        return context.eventLoop.makeFailedFuture(DuplexError.DuplexNotEstablished)
    }
    
    
    
    //MARK: - Device info
    
    
    //
    // MARK: get info
    // handle request for information about this device
    public func getRemoteMachineInfo(request: LookupName,
                                     context: StatusOnlyCallContext) -> EventLoopFuture<RemoteMachineInfo> {
        
        print(DEBUG_TAG+"Info is being retrieved by \(request.readableName) (\(request.id))")
        
        let info: RemoteMachineInfo = .with {
            $0.displayName = SettingsManager.shared.displayName
            $0.userName = SettingsManager.shared.userName
        }
        
        return context.eventLoop.makeSucceededFuture(info)
    }
    
    
    //
    // MARK: get avatar image
    // handle request for avatar image
    public func getRemoteMachineAvatar(request: LookupName,
                                       context: StreamingResponseCallContext<RemoteMachineAvatar>) -> EventLoopFuture<GRPCStatus> {
        
//        print(DEBUG_TAG+"Avatar is being requested by \(request.readableName) (\(request.id))")
        
        let promise = context.eventLoop.makePromise(of: GRPCStatus.self)

        
        if let avatarImg = SettingsManager.shared.avatarImage,
           let bytes = avatarImg.pngData() {
            
            sendingAvaratChunksQueue.async {
                bytes.extended.iterator(withChunkSize: 1024 * 1024).enumerated().forEach { (index, chunk) in
                    do {
                        try context.sendResponse( RemoteMachineAvatar.with {
                            $0.avatarChunk = chunk
                        }).wait() // wait for confirmation of this chunk before sending the next one
                    }
                    catch {
                        print(self.DEBUG_TAG+"avatar chunk \(index) prevented from waiting. Reason: \(error)")
                    }
                }
                
                promise.succeed(.ok)
            }
        } else {
            // no image
            promise.succeed(GRPCStatus.init(code: .notFound, message: "No avatar image found"))
        }
        
        return promise.futureResult
    }
    
    
    
    
    //
    // MARK: - Transfers
    
    
    
    //
    // MARK: process transfer request
    // receive request from remote to transfer data to this device
    public func processTransferOpRequest(request: TransferOpRequest, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        print(DEBUG_TAG+"Received request from \(request.info.ident)")
        
        let remoteUUID: String = request.info.ident
        
        guard let remote = remoteManager?.containsRemote(for: remoteUUID) else {
            print(DEBUG_TAG+"\tNo remote with uuid \"\(remoteUUID)\" exists")
            return context.eventLoop.makeFailedFuture(AuthenticationError.ConnectionError)
        }
        
        print(DEBUG_TAG+"\t\(request)")
        
        // if this is a retry of a previous operation
        let operation: ReceiveFileOperation
        if let op = remote.findTransfer(withUUID: request.info.timestamp) as? ReceiveFileOperation {
            operation = op
        } else {
            operation = ReceiveFileOperation(request, forRemote: remote)
            remote.addTransfer(operation)
        }

        operation.owningRemote = remote
        operation.prepareReceive()
        
        print(DEBUG_TAG+"\tprocessing request, compression is \( request.info.useCompression ? "on" : "off" )")
        
        
        if SettingsManager.shared.automaticAccept {
            print(DEBUG_TAG+"\ttransfer was automatically accepted")
            remote.startTransfer(for: operation)
        }
        
        
        return context.eventLoop.makeSucceededFuture(VoidType())
    }
    
    
    //
    // MARK: start transfer
    // called by remote to indicate that they are ready to begin receiving the specified transfer
    public func startTransfer(request: OpInfo, context: StreamingResponseCallContext<FileChunk>) -> EventLoopFuture<GRPCStatus> {
        
        print(DEBUG_TAG+"Received START request from \(request.ident)")
        
        let remoteUUID: String = request.ident
        
        guard let remote = remoteManager?.containsRemote(for: remoteUUID) else {
            print(DEBUG_TAG+"\tNo remote with uuid \"\(remoteUUID)\" exists")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        guard let transfer = remote.findTransfer(withUUID: request.timestamp) as? SendFileOperation else {
            print(DEBUG_TAG+"\tRemote has no sending operations with requested timestamp")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        
        return transfer.start(using: context)
    }
    
    
    //
    // MARK: cancel transer
    // (other device is declining our send operation)
    // handle instruction to cancel the specified sendingOperation
    public func cancelTransferOpRequest(request: OpInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        print(DEBUG_TAG+"Received CANCEL request from \(request.ident)")
        
        let remoteUUID: String = request.ident
        
        guard let remote = remoteManager?.containsRemote(for: remoteUUID) else {
            print(DEBUG_TAG+"No remote with uuid \"\(remoteUUID)\" exists")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        guard let transfer = remote.findTransfer(withUUID: request.timestamp) else {
            print(DEBUG_TAG+"Remote has no operations with requested timestamp")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        
        transfer.stop( TransferError.TransferCancelled )
        
        return context.eventLoop.makeSucceededFuture( VoidType() )
    }
    
    
    // MARK: stop transfer
    // (other device is requesting that a given operation -sending or receiving- be stopped)
    // receive instruction to stop operation (transfer) specified in OpInfo
    public func stopTransfer(request: StopInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        print(DEBUG_TAG+"Received STOP request for transfer \(request.info.readableName)")
        print(DEBUG_TAG+"\t\t error: \(request.error )")
        print(DEBUG_TAG+"\t\t\t\t full request: (\( request ))")
        
        let remoteUUID: String = request.info.ident
        
        guard let remote = remoteManager?.containsRemote(for: remoteUUID) else {
            print(DEBUG_TAG+"\t No remote with uuid \"\(remoteUUID)\" exists")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        
        guard let transfer = remote.findTransfer(withUUID: request.info.timestamp) else {
            print(DEBUG_TAG+"\t Remote has no operations with requested timestamp")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
//        print(DEBUG_TAG+"\( request.info.readableName )")
        
        transfer.stop( request.error ?  TransferError.UnknownError :  TransferError.TransferCancelled )
        
        return context.eventLoop.makeSucceededFuture( VoidType() )
    }
    
    
    // MARK: ping
    // receive ping
    public func ping(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        var debugString = "Receiving ping from "
        
        if let remote = remoteManager?.containsRemote(for: request.id) {
            debugString = debugString + "remote: \(remote.details.hostname)"
        } else {
            debugString = debugString + "UNKNOWN REMOTE: \(request.readableName)"
        }
        
        return context.eventLoop.makeCompletedFuture(Result(catching: {
            return VoidType()
        }))
    }
    
}





// MARK: - Deprecated(?) API
extension WarpinatorServiceProvider {
    
    // MARK: pause
    // receive instruction to pause operation (transfer) specified in OpInfo
    public func pauseTransferOp(request: OpInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        print(DEBUG_TAG+"received pauseTransferOp request (this API call is deprecated (unimplemented?) )")
        return context.eventLoop.makeCompletedFuture(Result(catching: { return VoidType() }))
    }
     
}
