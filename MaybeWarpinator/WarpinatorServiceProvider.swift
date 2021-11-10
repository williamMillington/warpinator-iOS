//
//  WarpinatorServiceProvider.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-06.
//

import Foundation
import GRPC
import NIO


public class WarpinatorServiceProvider: WarpProvider {
    
    private let DEBUG_TAG: String = "WarpinatorServiceProvider: "
    
    public var interceptors: WarpServerInterceptorFactoryProtocol?
    
    var remoteManager: RemoteManager?
    
    // MARK: Duplex API v1
    public func checkDuplexConnection(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        let id = request.id
        var duplexCheck = false
        
        print(DEBUG_TAG+"(API_V1) Duplex is being checked by \(request.readableName) (\(request.id))")
        
        if let remote = remoteManager?.containsRemote(for: id) {
            print(DEBUG_TAG+"(API_V1) Remote known")
            if remote.details.status == .VerifyingDuplex || remote.details.status == .Connected {
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
    public func waitingForDuplex(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        
        let id = request.id
        var duplexCheck = false
        
        print(DEBUG_TAG+"(API_V2) Duplex is being waited for by \(request.readableName) (\(request.id))")
        
        if let remote = remoteManager?.containsRemote(for: id) {
            print(DEBUG_TAG+"(API_V2) Remote known")
            if remote.details.status == .VerifyingDuplex || remote.details.status == .Connected {
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
    
    public func getRemoteMachineInfo(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<RemoteMachineInfo> {
        
        print(DEBUG_TAG+"Info is being retrieved by \(request.readableName) (\(request.id))")
        
        let displayName = "\(Server.displayName)" //Server.shared.displayName
        let userName = "iOS_Username"
        
        var info = RemoteMachineInfo()
        info.displayName = displayName
        info.userName = userName
        
        return context.eventLoop.makeSucceededFuture(info)
    }
    
    public func getRemoteMachineAvatar(request: LookupName, context: StreamingResponseCallContext<RemoteMachineAvatar>) -> EventLoopFuture<GRPCStatus> {
        
        print(DEBUG_TAG+"Avatar is being retrieved by \(request.readableName) (\(request.id))")
        
        return context.eventLoop.makeSucceededFuture(GRPC.GRPCStatus.ok)
    }
    
    
    
    public func processTransferOpRequest(request: TransferOpRequest, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        let remoteUUID: String = request.info.ident
        
//        guard var remote = MainService.shared.remotes[remoteUUID] else {
//            print("No remote with uuid \"\(remoteUUID)\" exists")
//            let voidType = VoidType()
//            return context.eventLoop.makeSucceededFuture(voidType)
//        }
        
        var transfer = Transfer(direction: Transfer.Direction.RECEIVING,
                                status: Transfer.Status.WAITING_FOR_PERMISSION,
                                remoteUUID: remoteUUID,
                                startTime: Double(request.info.timestamp),
                                totalSize: Double(request.size),
                                fileCount: Double(request.count),
                                singleName: request.nameIfSingle,
                                singleMime: request.mimeIfSingle,
                                topDirBaseNames: request.topDirBasenames )
        
        
        
        
        return context.eventLoop.makeSucceededFuture(VoidType())
    }
    
    public func pauseTransferOp(request: OpInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        return context.eventLoop.makeCompletedFuture(Result(catching: {
            return VoidType()
        }))
    }
    
    public func startTransfer(request: OpInfo, context: StreamingResponseCallContext<FileChunk>) -> EventLoopFuture<GRPCStatus> {
        
        return context.eventLoop.makeSucceededFuture(GRPC.GRPCStatus.ok)
    }
    
    public func cancelTransferOpRequest(request: OpInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        return context.eventLoop.makeCompletedFuture(Result(catching: {
            return VoidType()
        }))
    }
    
    public func stopTransfer(request: StopInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        return context.eventLoop.makeCompletedFuture(Result(catching: {
            return VoidType()
        }))
    }
    
    public func ping(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        
        var debugString = "Server Ping from "
        
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
