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
    
    
//    public static var transfer_port: Int = 42000
//    public static var registration_port: Int = 42001
    
    
//    public var transfer_port: Int = Server.transfer_port
//    private var registration_port: Int = Server.registration_port
    
//    public static var displayName: String = "Display_Name"
//    public static var userName: String = "username"
//    public static var hostname: String = Server.SERVER_UUID
    
//    public static var SERVER_UUID: String = "WarpinatorIOS"
    
//    private lazy var uuid: String = Server.SERVER_UUID
//    public lazy var hostname = Server.SERVER_UUID
    
    
    
    var eventLoopGroup: EventLoopGroup?
    
    private var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    
    weak var remoteManager: RemoteManager? {
        didSet {  warpinatorProvider.remoteManager = remoteManager  }
    }
    
    weak var settingsManager: SettingsManager? {
        didSet {  warpinatorProvider.settingsManager = settingsManager  }
    }
    
    weak var authenticationManager: Authenticator?
    
    
    func start(){
        
        startWarpinatorServer()
        
    }
    
    
    // MARK: Transfer Server
    func startWarpinatorServer(){
        
        guard let serverELG = eventLoopGroup else { return }
        
        authenticationManager?.generateNewCertificate()
        
        guard let serverCertificate = authenticationManager?.serverCert,
              let serverPrivateKey = authenticationManager?.serverKey else {
                print(DEBUG_TAG+"Error with server credentials")
            return
        }
        
        
        guard let port = settingsManager?.transferPortNumber else {
            print(DEBUG_TAG+"No transfer port number (whomp whomp)")
            return
        }
        let portNumber = Int(port)
        
        var logger = Logger(label: "warpinator.Server", factory: StreamLogHandler.standardOutput)
        logger.logLevel = .debug
        
        
        
        let serverBuilder = GRPC.Server.usingTLSBackedByNIOSSL(on: serverELG,
                                                               certificateChain: [ serverCertificate  ],
                                                               privateKey: serverPrivateKey)
            .withTLS(trustRoots: .certificates( [serverCertificate] ) )
            .withServiceProviders([warpinatorProvider])
//            .withLogger(logger)

        let serverFuture = serverBuilder.bind(host: "\(Utils.getIP_V4_Address())", port: portNumber)



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
            try! self.eventLoopGroup?.syncShutdownGracefully()
        }
        
        
    }
    
}

