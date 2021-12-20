//
//  Server.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-04.
//

import UIKit

import GRPC
import NIO
//import NIOSSL
//import SwiftProtobuf

import Network

import Logging

//import CryptoKit
//import Sodium


public class Server: NSObject {
    
    
    private let DEBUG_TAG: String = "Server: "
    
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "local"
    
    
    public static var transfer_port: Int = 42000
    public static var registration_port: Int = 42001
    
    
    public var transfer_port: Int = Server.transfer_port
    private var registration_port: Int = Server.registration_port
    
    public static var displayName: String = "iOS_DeviceName"
    
    public static var SERVER_UUID: String = "WarpinatorIOS"
    
    private lazy var uuid: String = Server.SERVER_UUID
    public lazy var hostname = Server.SERVER_UUID
    
    
    
    
    private var transferServer: GRPC.Server?
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
        
        Authenticator.shared.generateNewCertificate(forHostname: "\(Server.SERVER_UUID)")
        
        guard let serverCertificate = Authenticator.shared.serverCert else {
            print(DEBUG_TAG+"Error with server certificate")
            return
        }
        
        guard let serverPrivateKey = Authenticator.shared.serverKey else {
            print(DEBUG_TAG+"Error with server certificate")
            return
        }
//        let authority = Authenticator.shared.getServerCertificateBundle()      //getSigningAuthority()
//        let serverCertificate = Authenticator.shared.getServerCertificate()
//        let serverPrivateKey = Authenticator.shared.getServerPrivateKey()
        
        
//        print(DEBUG_TAG+"CA is \(authority)")
//        print(DEBUG_TAG+"certificate is \(serverCertificate)")
//        print(DEBUG_TAG+"privatekey is \(serverPrivateKey)")
        
        
        var logger = Logger(label: "warpinator.Server", factory: StreamLogHandler.standardOutput)
        logger.logLevel = .debug
        
        
        
        let serverBuilder = GRPC.Server.usingTLSBackedByNIOSSL(on: serverELG,
                                                               certificateChain: [ serverCertificate  ],
                                                               privateKey: serverPrivateKey)
            .withTLS(trustRoots: .certificates( [serverCertificate] ) )
            .withServiceProviders([warpinatorProvider])
//            .withLogger(logger)
        
        let transferFuture = serverBuilder
            .bind(host: "\(Utils.getIPV4Address())", port: transfer_port)
        
        
        
        transferFuture.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            print(self.DEBUG_TAG+"transfer server started on port: \(String(describing: address))")
        }
        
        
        let closefuture = transferFuture.flatMap {
            $0.onClose
        }
        
        closefuture.whenCompleteBlocking(onto: .main) { _ in
            print(self.DEBUG_TAG+"transfer server exited")
        }
        closefuture.whenCompleteBlocking(onto: DispatchQueue(label: "cleanup-queue")){ _ in
            try! self.serverELG.syncShutdownGracefully()
        }
    }
    
}

