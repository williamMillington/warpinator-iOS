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
    
//    var mDNSBrowser: MDNSBrowser
//    var mDNSListener: MDNSListener
    
    var eventLoopGroup: EventLoopGroup

    private lazy var warpinatorRegistrationProvider: WarpinatorRegistrationProvider = WarpinatorRegistrationProvider()
    
//    var remoteManager: RemoteManager
    
    var settingsManager: SettingsManager
    
    var server : GRPC.Server?
    
    init(eventloopGroup group: EventLoopGroup,
         settingsManager manager: SettingsManager) { //},remoteManager: RemoteManager) {
        
        eventLoopGroup = group
        settingsManager = manager
//        self.remoteManager = remoteManager
        
        
//        mDNSBrowser = MDNSBrowser()
//        mDNSBrowser.delegate = remoteManager
//
//        mDNSListener = MDNSListener(settingsManager: settingsManager)
        
//        defer {
//            mDNSListener.delegate = self
//        }
    }
    
    
    //
    // MARK: start
    func start() -> EventLoopFuture<GRPC.Server>  {
        
        // don't create a new server if we have one going already
        if let server = server {
            return server.channel.eventLoop.makeSucceededFuture(server)
        }
        
        let portNumber = Int( settingsManager.registrationPortNumber )
        
        let future = GRPC.Server.insecure(group: eventLoopGroup)
            .withServiceProviders([warpinatorRegistrationProvider])
            .bind(host: "\(Utils.getIP_V4_Address())", port: portNumber)
        
        future.whenSuccess { [weak self] server in
            
            print((self?.DEBUG_TAG ?? "(server is nil): ")+"registration server started on: \(String(describing: server.channel.localAddress))")
                
                self?.server = server
//                self?.startMDNSServices()
            }
        
        return future
    }
    
    
    
    //
    // MARK: stop
    func stop() -> EventLoopFuture<Void> {
        
        guard let server = server else {
            return eventLoopGroup.next().makeSucceededVoidFuture()
        }
        
//        stopMDNSServices()
        
        return server.close() //  .initiateGracefulShutdown()
    }
    
    
//    //
//    // MARK:  startMDNSServices
//    func startMDNSServices(){
//        mDNSListener.start()
//    }
    
    
//    //
//    // MARK: stop mDNS
//    func stopMDNSServices(){
//        mDNSBrowser.stop()
//        mDNSListener.stop()
//    }
    
    
}



//
//// MARK: - MDNSListenerDelegate
//extension RegistrationServer: MDNSListenerDelegate {
//    func mDNSListenerIsReady() {
//        mDNSBrowser.start()
//    }
//}






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
