//
//  WarpinatorServiceProvider.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-06.
//

import Foundation
import GRPC
import NIO



enum DuplexError: GRPCErrorProtocol {
    case UnknownRemote
    case DuplexNotEstablished
    func makeGRPCStatus() -> GRPCStatus {
        switch self {
        case .UnknownRemote: return GRPCStatus(code: GRPCStatus.Code.failedPrecondition,
                                               message: "This remote is not known to the server")
        case .DuplexNotEstablished: return GRPCStatus(code: GRPCStatus.Code.failedPrecondition,
                                                      message: "This remote has not yet established duplex")
        }
    }
    
    var description: String {
        switch self {
        case .UnknownRemote: return  "This remote is not known to the server"
        case .DuplexNotEstablished: return "This remote has not yet established duplex"
        }
    }
    
    
}


public class WarpinatorServiceProvider: WarpProvider {
    
    private let DEBUG_TAG: String = "WarpinatorServiceProvider: "
    
    public var interceptors: WarpServerInterceptorFactoryProtocol?
    
    var remoteManager: RemoteManager?
    
    // MARK: Duplex API v1
    // receive request for status of connection to remote specified in LookupName
    public func checkDuplexConnection(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        let id = request.id
        var duplexCheck = false
        
        print(DEBUG_TAG+"(API_V1) Duplex is being checked by \(request.readableName) (\(request.id))")
        
        if let remote = remoteManager?.containsRemote(for: id) {
            print(DEBUG_TAG+"(API_V1) Remote known")
            if remote.details.status == .DuplexAquired || remote.details.status == .Connected {
                print(DEBUG_TAG+"(API_V1) Duplex verified by remote")
                duplexCheck = true
            }
        }
        
        return context.eventLoop.makeCompletedFuture( Result(catching: {
            var duplexExists = HaveDuplex()
            duplexExists.response = duplexCheck
            return duplexExists
        }))
    }
    
    // MARK: Duplex API v2
    // receive request for status of connection to remote specified in LookupName
    public func waitingForDuplex(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        let id = request.id
        var duplexCheck = false
        
        print(DEBUG_TAG+"(API_V2) Duplex is being waited for by \(request.readableName) (\(request.id))")
        
        if let remote = remoteManager?.containsRemote(for: id) {
            print(DEBUG_TAG+"(API_V2) Remote known")
            if remote.details.status == .DuplexAquired || remote.details.status == .Connected {
                print(DEBUG_TAG+"(API_V2) Duplex verified by remote")
                duplexCheck = true
            }
        }
        
        return context.eventLoop.makeCompletedFuture( Result(catching: {
            var duplexExists = HaveDuplex()
            duplexExists.response = duplexCheck
            return duplexExists
        }))
        
    }
    
    // MARK: get info
    // receive request for information about this device
    public func getRemoteMachineInfo(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<RemoteMachineInfo> {
        
        print(DEBUG_TAG+"Info is being retrieved by \(request.readableName) (\(request.id))")
        
        let displayName = "\(Server.displayName)" //Server.shared.displayName
        let userName = "iOS_Username"
        
        var info = RemoteMachineInfo()
        info.displayName = displayName
        info.userName = userName
        
        return context.eventLoop.makeSucceededFuture(info)
    }
    
    
    // MARK: get avatar image
    // receive request for avatar image
    public func getRemoteMachineAvatar(request: LookupName, context: StreamingResponseCallContext<RemoteMachineAvatar>) -> EventLoopFuture<GRPCStatus> {
        
        print(DEBUG_TAG+"Avatar is being retrieved by \(request.readableName) (\(request.id))")
        
        return context.eventLoop.makeSucceededFuture(GRPC.GRPCStatus.ok)
    }
    
    
    
    // MARK: process transfer request
    // receive request from remote to transfer data to this device
    public func processTransferOpRequest(request: TransferOpRequest, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        let remoteUUID: String = request.info.ident
        
        guard let remote = MainService.shared.remoteManager.containsRemote(for: remoteUUID) else {
            print(DEBUG_TAG+"No remote with uuid \"\(remoteUUID)\" exists")
            let error = RegistrationError.ConnectionError
            return context.eventLoop.makeFailedFuture(error)
        }
        
        let transfer = TransferOperation()
        transfer.owningRemote = remote
        transfer.status = .INITIALIZING
        transfer.remoteUUID = remoteUUID
        transfer.startTime = request.info.timestamp
        transfer.totalSize =  Double(request.size)
        transfer.fileCount = Int(request.count)
        transfer.singleName = request.nameIfSingle
        transfer.singleMime = request.mimeIfSingle
        transfer.topDirBaseNames = request.topDirBasenames
        transfer.prepareReceive()
        
        print(DEBUG_TAG+"processing request, compression is \( request.info.useCompression ? "on" : "off" )")
        
        remote.addTransferOperation(transfer)
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            transfer.startReceive()
        }
        
        
        return context.eventLoop.makeSucceededFuture(VoidType())
    }
    
    
    // MARK: pause transer
    // receive instruction to pause operation (transfer) specified in OpInfo
    public func pauseTransferOp(request: OpInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        
        // TODO: implement pause transfer function
        
        
        return context.eventLoop.makeCompletedFuture(Result(catching: { return VoidType() }))
    }
    
    
    // MARK: start transer
    // called by remote to indicate that they are ready to begin receiving transfer (specified in OpInfo)
    public func startTransfer(request: OpInfo, context: StreamingResponseCallContext<FileChunk>) -> EventLoopFuture<GRPCStatus> {
        
        // TODO: implement start transfer function
        
        let remoteUUID: String = request.ident
        
        guard let remote = MainService.shared.remoteManager.containsRemote(for: remoteUUID) else {
            print(DEBUG_TAG+"No remote with uuid \"\(remoteUUID)\" exists")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        
        guard let transfer = remote.findTransferFor(startTime: request.timestamp) else {
            print(DEBUG_TAG+"Remote has no transfer with requested timestamp")
            let error = TransferError.TransferNotFound
            return context.eventLoop.makeFailedFuture(error)
        }
        
        transfer.startSending()
        
        return context.eventLoop.makeSucceededFuture(GRPC.GRPCStatus.ok)
    }
    
    
    // MARK: cancel transer
    // receive instruction to cancel operation (transfer) specified in OpInfo
    public func cancelTransferOpRequest(request: OpInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        // TODO: implement cnacel transfer function
        
        return context.eventLoop.makeCompletedFuture(Result(catching: {  return VoidType()   }))
    }
    
    
    // MARK: stop transer
    // receive instruction to stop operation (transfer) specified in OpInfo
    public func stopTransfer(request: StopInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        // TODO: implement stop transfer function
        
        return context.eventLoop.makeCompletedFuture(Result(catching: {  return VoidType()  }))
    }
    
    
    // MARK: ping
    // receive ping from LookupName
    public func ping(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        var debugString = "Receiving ping from "
        
        if let remote = remoteManager?.containsRemote(for: request.id) {
            debugString = debugString + "remote: \(remote.details.hostname)"
        } else {
            debugString = debugString + "UNKNOWN REMOTE: \(request.readableName)"
        }
        
        print(DEBUG_TAG+debugString)
        
        return context.eventLoop.makeCompletedFuture(Result(catching: {
            return VoidType()
        }))
    }
    
}
