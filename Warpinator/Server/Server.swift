//
//  Server.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-04.
//

import UIKit

import GRPC
import NIO

import Network

import Logging


final class Server {
    
    
    private let DEBUG_TAG: String = "Server: "
    
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "local"
    
    var eventLoopGroup: EventLoopGroup?
    
    private lazy var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    
    weak var remoteManager: RemoteManager? {
        didSet {  warpinatorProvider.remoteManager = remoteManager  }
    }
    
    var settingsManager: SettingsManager
    
    weak var authenticationManager: Authenticator?
    
    
    // We have to capture the serverBuilder future here or it will sometimes randomly be
    // deallocated before it can return
    var future: EventLoopFuture<GRPC.Server>?
    var server: GRPC.Server?
    
    
    let queueLabel = "WarpinatorServerQueue"
    lazy var serverQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
//    var logger: Logger = {
//        var log = Logger(label: "warpinator.Server", factory: StreamLogHandler.standardOutput)
//        log.logLevel = .debug
//        return log
//    }()
    
    
    init(settingsManager manager: SettingsManager) {
        settingsManager = manager
        
        warpinatorProvider.settingsManager = settingsManager
    }
    
    
    //
    // MARK: start
    func start(){
        
        guard let serverELG = eventLoopGroup else {
            print(DEBUG_TAG+"Error: no eventloop group"); return
        }
        
        // TODO: check if this needs to be regenerated
        authenticationManager?.generateNewCertificate()
        
        //
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
    
    
    // MARK: stop
    func stop() -> EventLoopFuture<Void>? {
        guard let server = server else {
            return eventLoopGroup?.next().makeSucceededVoidFuture()
        }
        return server.initiateGracefulShutdown()
    }
    
    
}

