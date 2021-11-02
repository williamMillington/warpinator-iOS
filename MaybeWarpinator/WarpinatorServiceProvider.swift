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
    
    // API v1
    public func checkDuplexConnection(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        
        let id = request.id
        let duplexCheck = true
        
        print(DEBUG_TAG+"duplex is being checked by \(id)")
        
        return context.eventLoop.makeCompletedFuture( Result(catching: {
            var duplexExists = HaveDuplex()
            duplexExists.response = duplexCheck
            return duplexExists
        }))
    }
    
    // API v2
    public func waitingForDuplex(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        
        let id = request.id
        let duplexCheck = true
        
        print(DEBUG_TAG+"duplex is being waited for by: \(id)")
        
        return context.eventLoop.makeCompletedFuture( Result(catching: {
            var duplexExists = HaveDuplex()
            duplexExists.response = duplexCheck
            return duplexExists
        }))
        
    }
    
    public func getRemoteMachineInfo(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<RemoteMachineInfo> {
        
        print("machine info is being retrieved!")
        
        let displayName = "" //Server.shared.displayName
        let userName = "iOS_Username"
        
        var info = RemoteMachineInfo()
        info.displayName = displayName
        info.userName = userName
        
        return context.eventLoop.makeSucceededFuture(info)
    }
    
    public func getRemoteMachineAvatar(request: LookupName, context: StreamingResponseCallContext<RemoteMachineAvatar>) -> EventLoopFuture<GRPCStatus> {
        
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
        return context.eventLoop.makeCompletedFuture(Result(catching: {
            return VoidType()
        }))
    }
    
    
}
