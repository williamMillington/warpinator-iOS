//
//  RegistrationServer.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-01.
//

import Foundation

import NIO
import NIOSSL

import GRPC
import Network

import Logging


// MARK: - Registration Server
final class RegistrationServer {
    
    private let DEBUG_TAG: String = "RegistrationServer: "
    
    var eventLoopGroup: EventLoopGroup
    
    var server : GRPC.Server?
    var isRunning: Bool = false
    
    
    init(eventloopGroup group: EventLoopGroup ){
        eventLoopGroup = group
    }
    
    
    //
    // MARK: start
    func start() -> EventLoopFuture<Void>  {
        
        
//        let portNumber = Int( SettingsManager.shared.registrationPortNumber )
        
//        let future = GRPC.Server.insecure(group: eventLoopGroup)
//            .withServiceProviders([ WarpinatorRegistrationProvider() ])
//            .bind(host: "\(Utils.getIP_V4_Address())", port: portNumber)
//            .flatMapError { error in
//
//                print( self.DEBUG_TAG + "registration server failed: \(error))")
//
//                return self.eventLoopGroup.next().flatScheduleTask(in: .seconds(2)) {
//                    self.start()
//                }.futureResult
//            }
        
        
        return startupServer().map { server in
            print(self.DEBUG_TAG + "registration server started on: \(String(describing: server.channel.localAddress))")

            self.server = server
            self.isRunning = true
        }
//        future.whenSuccess { [weak self] server in
//
//            print((self?.DEBUG_TAG ?? "(server is nil): ")+"registration server started on: \(String(describing: server.channel.localAddress))")
//
//            self?.server = server
//            self?.isRunning = true
//        }
//
//        return future
    }
    
    
    private func startupServer() -> EventLoopFuture<GRPC.Server> {
        
        
        return GRPC.Server.insecure(group: eventLoopGroup)
            .withServiceProviders([ WarpinatorRegistrationProvider() ])
            .bind(host: "\(Utils.getIP_V4_Address())",
                  port: Int( SettingsManager.shared.registrationPortNumber ) )
        
            // try again on error
            .flatMapError { error in
                
                print( self.DEBUG_TAG + "registration server failed: \(error))")
                
                return self.eventLoopGroup.next().flatScheduleTask(in: .seconds(2)) {
                    self.startupServer()
                }.futureResult
            }
    }
    
    
    
    //
    // MARK: stop
    func stop() -> EventLoopFuture<Void> {
        
        guard let server = server, isRunning else {
            return eventLoopGroup.next().makeSucceededVoidFuture()
        }
        
        isRunning = false
        return server.initiateGracefulShutdown()
    }
}


//// MARK: - Mock functions
//extension RegistrationServer {
//
//    func mockStart(){
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
//            print((self?.DEBUG_TAG ?? "(server is nil): ")+"mocking registration")
//            self?.mockRegistration()
//        }
//    }
//
//
//    func mockRegistration(){
//
//        for i in 0...5 {
//
//            var mockDetails = RemoteDetails.MOCK_DETAILS
//            mockDetails.uuid = mockDetails.uuid + "__\(i)"
//
//            let mockRemote = Remote(details: mockDetails)
//
//            remoteManager.addRemote(mockRemote)
//        }
//
//    }
//}
