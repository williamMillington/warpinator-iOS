//
//  Server.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-04.
//

import UIKit

import GRPC
import NIO

import Network

import Logging


public class Server: NSObject {
    
    
    private let DEBUG_TAG: String = "Server: "
    
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "local"
    
    
    public static var transfer_port: Int = 42000
    public static var registration_port: Int = 42001
    
    
    public var transfer_port: Int = Server.transfer_port
    private var registration_port: Int = Server.registration_port
    
    public static var displayName: String = "Display_Name"
    public static var userName: String = "username"
    public static var hostname: String = Server.SERVER_UUID
    
    public static var SERVER_UUID: String = "WarpinatorIOS"
    
    private lazy var uuid: String = Server.SERVER_UUID
    public lazy var hostname = Server.SERVER_UUID
    
    
    
    
//    private var transferServer_IPV4: GRPC.Server?
    private var serverELG: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: (System.coreCount / 2) ) //GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    private var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    
    var remoteManager: RemoteManager? {
        didSet {
            warpinatorProvider.remoteManager = remoteManager 
        }
    }
    
    func start(){
        
        startWarpinatorServer()
        
    }
    
    // MARK: Transfer Server
    func startWarpinatorServer(){
        
        Authenticator.shared.generateNewCertificate()
        
        guard let serverCertificate = Authenticator.shared.serverCert else {
            print(DEBUG_TAG+"Error with server certificate")
            return
        }
        
        guard let serverPrivateKey = Authenticator.shared.serverKey else {
            print(DEBUG_TAG+"Error with server certificate")
            return
        }
        
        
        var logger = Logger(label: "warpinator.Server", factory: StreamLogHandler.standardOutput)
        logger.logLevel = .debug
        
        
        
        let serverBuilder = GRPC.Server.usingTLSBackedByNIOSSL(on: serverELG,
                                                               certificateChain: [ serverCertificate  ],
                                                               privateKey: serverPrivateKey)
            .withTLS(trustRoots: .certificates( [serverCertificate] ) )
            .withServiceProviders([warpinatorProvider])
//            .withLogger(logger)

        let serverFuture = serverBuilder
            .bind(host: "\(Utils.getIP_V4_Address())", port: transfer_port)



        serverFuture.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            print(self.DEBUG_TAG+"transfer server started on port: \(String(describing: address))")
        }
        
        
        let closefuture = serverFuture.flatMap {
            $0.onClose
        }

        closefuture.whenCompleteBlocking(onto: .main) { _ in
            print(self.DEBUG_TAG+"transfer server exited")
        }
        closefuture.whenCompleteBlocking(onto: DispatchQueue(label: "cleanup-queue")){ _ in
            try! self.serverELG.syncShutdownGracefully()
        }
        
        
//        let v6_addr = Utils.getIP_V6_Address()
//        print(DEBUG_TAG+"v6 address is \(v6_addr)")
//
//        let serverBuilder_v6 = GRPC.Server.usingTLSBackedByNIOSSL(on: serverELG,
//                                                               certificateChain: [ serverCertificate  ],
//                                                               privateKey: serverPrivateKey)
//            .withTLS(trustRoots: .certificates( [serverCertificate] ) )
//            .withServiceProviders([warpinatorProvider])
//            .withLogger(logger)
//
//        let v6_serverFuture = serverBuilder_v6.bind(host: "[::]", port: transfer_port)
//
//
//        v6_serverFuture.map {
//            $0.channel.localAddress
//        }.whenSuccess { address in
//            print(self.DEBUG_TAG+"transfer server started on port: \(String(describing: address))")
//        }
//
//        v6_serverFuture.map {
//            $0.channel.localAddress
//        }.whenFailure { error in
//            print(self.DEBUG_TAG+"transfer server failed to start on port: \(String(describing: error))")
//        }
        
        
//        let closefuture_v6 = v6_serverFuture.flatMap {
//            $0.onClose
//        }
//
//        closefuture_v6.whenCompleteBlocking(onto: .main) { _ in
//            print(self.DEBUG_TAG+"V6 transfer server exited")
//        }
//        closefuture_v6.whenCompleteBlocking(onto: DispatchQueue(label: "cleanup-queue")){ _ in
//            try! self.serverELG.syncShutdownGracefully()
//        }
        
        
        
        
    }
    
}

