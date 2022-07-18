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
    
    // TODO: I thiiiiiink there needs to be a timer for each remote, otherwise we can only handle one duplex at a time?
    // I think. I think?
    var timer: Timer?
    
    
    //
    // MARK: - Duplex
    
    
    
    // MARK: v1
    // receive request for status of connection to remote specified in LookupName
    public func checkDuplexConnection(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        print(DEBUG_TAG+"(API_V1) Duplex is being checked by \(request.readableName) (\(request.id))")
        
        let duplexPromise = checkDuplex(forUUID: request.id, context)
        return duplexPromise.futureResult
    }
    
    
    // MARK: v2
    // receive request for status of connection to remote specified in LookupName
    public func waitingForDuplex(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        print(DEBUG_TAG+"(API_V2) Duplex is being waited for by \(request.readableName) (\(request.id))")

        let duplexPromise = checkDuplex(forUUID: request.id, context)
        return duplexPromise.futureResult
    }
    
    
    
    // MARK: checkDuplex
    private func checkDuplex(forUUID uuid: String, _ context: StatusOnlyCallContext) -> EventLoopPromise<HaveDuplex> {

        func checkDuplex() -> Bool {
            print(DEBUG_TAG+"\t\tchecking duplex for uuid: \(uuid)")
            if let remote = self.remoteManager?.containsRemote(for: uuid) {
                
                print(DEBUG_TAG+"\t\t\t remote found (status: \(remote.details.status))")
                if [.AquiringDuplex, .Connected].contains( remote.details.status ) {
                    return true
                }
                
                print(DEBUG_TAG+"\t\t\t\trestarting connection...")
                remote.startupConnection()
            }
            return false
        }
        
        
        let duplexPromise = context.eventLoop.makePromise(of: HaveDuplex.self)

        // for some reason this only works on main queue
        DispatchQueue.main.async {
            
            var count = 0
            
            // repeats 4 times a second, for a total of 10 times if client times out at ~5 seconds
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { timer in
                count += 1
                guard count < 10 else {
                    timer.invalidate();
                    duplexPromise.fail(DuplexError.DuplexTimeout)
                    return
                }
                
                let duplexExists = checkDuplex()
                if duplexExists {
                    duplexPromise.succeed( .with { $0.response = true })
                    timer.invalidate()
                }
            }
        }
        
        return duplexPromise
    }
    
    
    
    //MARK: - Device info
    
    
    //
    // MARK: get info
    // handle request for information about this device
    public func getRemoteMachineInfo(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<RemoteMachineInfo> {
        
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
    public func getRemoteMachineAvatar(request: LookupName, context: StreamingResponseCallContext<RemoteMachineAvatar>) -> EventLoopFuture<GRPCStatus> {
        
        print(DEBUG_TAG+"Avatar is being requested by \(request.readableName) (\(request.id))")
        
        let promise = context.eventLoop.makePromise(of: GRPCStatus.self)

        
        if let avatarImg = SettingsManager.shared.avatarImage,
           let bytes = avatarImg.pngData() {
            
            sendingAvaratChunksQueue.async {
                bytes.extended.iterator(withChunkSize: 1024 * 1024).enumerated().forEach { (index, chunk) in
                    do {
                        print(self.DEBUG_TAG+"\t\t sending  chunk #\(index + 1) ")
                        try context.sendResponse( RemoteMachineAvatar.with {
                            $0.avatarChunk = chunk
                        }).wait() // wait for confirmation of this chunk before sending the next one
                        print(self.DEBUG_TAG+"\t\t chunk #\(index + 1) sent successfully")
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
        
        print(DEBUG_TAG+"Received PROCESS TRANSFER request from \(request.info.ident)")
        
        let remoteUUID: String = request.info.ident
        
        guard let remote = remoteManager?.containsRemote(for: remoteUUID) else {
            print(DEBUG_TAG+"No remote with uuid \"\(remoteUUID)\" exists")
            let error = AuthenticationError.ConnectionError
            return context.eventLoop.makeFailedFuture(error)
        }
        
        print(DEBUG_TAG+"\t\(request)")
        
        // if this is a retry of a previous operation
        if let operation = remote.findTransferOperation(for: request.info.timestamp) as? ReceiveFileOperation {
            operation.prepareReceive()
            return context.eventLoop.makeSucceededFuture(VoidType())
        }
        
        let operation = ReceiveFileOperation(request, forRemote: remote)
        operation.prepareReceive()
        
        print(DEBUG_TAG+"processing request, compression is \( request.info.useCompression ? "on" : "off" )")
        
        remote.addReceivingOperation(operation)
        
        
        if SettingsManager.shared.automaticAccept {
            print(DEBUG_TAG+"Transfer was automatically accepted")
            remote.callClientStartTransfer(for: operation)
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
            print(DEBUG_TAG+"No remote with uuid \"\(remoteUUID)\" exists")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        guard let transfer = remote.findSendOperation(withStartTime: request.timestamp) else {
            print(DEBUG_TAG+"Remote has no sending operations with requested timestamp")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        let promise = transfer.start(using: context)
        
        return promise.futureResult
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
        
        guard let transfer = remote.findTransferOperation(for: request.timestamp) else {
            print(DEBUG_TAG+"Remote has no operations with requested timestamp")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        
        if let receive = transfer as? ReceiveFileOperation {
            receive.receiveWasCancelled()
        }
        
        if let send = transfer as? SendFileOperation {
            send.onDecline()
        }
        
        
        return context.eventLoop.makeSucceededFuture( VoidType() )
    }
    
    
    // MARK: stop transfer
    // (other device is requesting that a given operation -sending or receiving- be stopped)
    // receive instruction to stop operation (transfer) specified in OpInfo
    public func stopTransfer(request: StopInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        print(DEBUG_TAG+"Received STOP request for transfer - \(request.info)")
        
        let remoteUUID: String = request.info.ident
        
        guard let remote = remoteManager?.containsRemote(for: remoteUUID) else {
            print(DEBUG_TAG+"No remote with uuid \"\(remoteUUID)\" exists")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        
        guard let transfer = remote.findTransferOperation(for: request.info.timestamp) else {
            print(DEBUG_TAG+"Remote has no operations with requested timestamp")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        
        if request.error {
            transfer.stopRequested( TransferError.UnknownError )
        } else {
            transfer.stopRequested(nil)
        }
        
        
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
        
//        print(DEBUG_TAG+debugString)
        
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
