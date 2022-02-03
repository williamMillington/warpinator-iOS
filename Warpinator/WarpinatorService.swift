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
    public var interceptors: WarpServerInterceptorFactoryProtocol?
    
    public func checkDuplexConnection(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        
        let id = request.id
        var duplexCheck = false
        
        return context.eventLoop.makeCompletedFuture(Result(catching: {
            var duplexExists = HaveDuplex()
            duplexExists.response = duplexCheck
            return duplexExists
        }))
        
    }
    
    public func waitingForDuplex(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<HaveDuplex> {
        <#code#>
    }
    
    public func getRemoteMachineInfo(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<RemoteMachineInfo> {
        <#code#>
    }
    
    public func getRemoteMachineAvatar(request: LookupName, context: StreamingResponseCallContext<RemoteMachineAvatar>) -> EventLoopFuture<GRPCStatus> {
        <#code#>
    }
    
    public func processTransferOpRequest(request: TransferOpRequest, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        <#code#>
    }
    
    public func pauseTransferOp(request: OpInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        <#code#>
    }
    
    public func startTransfer(request: OpInfo, context: StreamingResponseCallContext<FileChunk>) -> EventLoopFuture<GRPCStatus> {
        <#code#>
    }
    
    public func cancelTransferOpRequest(request: OpInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        <#code#>
    }
    
    public func stopTransfer(request: StopInfo, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        <#code#>
    }
    
    public func ping(request: LookupName, context: StatusOnlyCallContext) -> EventLoopFuture<VoidType> {
        <#code#>
    }
    
    
}
