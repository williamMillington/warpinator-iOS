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


public class Server { //}: NSObject {
    
    
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
    
    private lazy var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    
    weak var remoteManager: RemoteManager? {
        didSet {  warpinatorProvider.remoteManager = remoteManager  }
    }
    
    var settingsManager: SettingsManager
    
    weak var authenticationManager: Authenticator?
    
    
    // We have to capture the serverBuilder future here or it will sometimes randomly be
    // deallocated before it can finish for some idiot reason
    var future: EventLoopFuture<GRPC.Server>?
    var server: GRPC.Server?
    
    
    lazy var queueLabel = "WarpinatorServerQueue"
    lazy var serverQueue = DispatchQueue(label: queueLabel, qos: .utility)
    var logger: Logger = {
        var log = Logger(label: "warpinator.Server", factory: StreamLogHandler.standardOutput)
        log.logLevel = .debug
        return log
    }()
    
    init(settingsManager manager: SettingsManager) {
        settingsManager = manager
        
        warpinatorProvider.settingsManager = settingsManager
    }
    
    
    //
    // MARK: start server
    func start(){
        
        guard let serverELG = eventLoopGroup else { return }
        
        
        authenticationManager?.generateNewCertificate()
        
        
        let serverCertificate = authenticationManager!.serverCert!
        let serverPrivateKey = authenticationManager!.serverKey!
        
        // 'future' will be deallocated before .whenSuccess can be called if we don't capture it here
        future = GRPC.Server.usingTLSBackedByNIOSSL(on: serverELG,
                                           certificateChain: [ serverCertificate  ],
                                           privateKey: serverPrivateKey )
            .withTLS(trustRoots: .certificates( [serverCertificate ] ) )
            .withServiceProviders( [ warpinatorProvider ] )
            .bind(host: "\(Utils.getIP_V4_Address())",
                  port: Int( settingsManager.transferPortNumber ))
            
        future?.whenSuccess { server in
            print(self.DEBUG_TAG+"transfer server started on: \(String(describing: server.channel.localAddress))")
            self.server = server
        }
        
        future?.whenFailure { error in
            print(self.DEBUG_TAG+"transfer server failed: \(error))")
        }

    }
    
    
    // MARK: stop server
    func stop() -> EventLoopFuture<Void>? {
        guard let server = server else {
            return eventLoopGroup?.next().makeSucceededVoidFuture()
        }
        return server.initiateGracefulShutdown()
    }
    
    
}

