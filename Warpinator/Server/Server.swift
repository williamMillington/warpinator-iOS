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
    
    enum ServerError: Error {
        case NO_EVENTLOOP
        case CREDENTIALS_INVALID
        case UKNOWN_ERROR
        
        var localizedDescription: String {
            switch self {
            case .NO_EVENTLOOP: return "No available eventloop"
            case .CREDENTIALS_INVALID: return "Server certificate and/or private key are invalid"
            case .UKNOWN_ERROR: return "Server has encountered an unknown error"
            }
        }
    }
    
    
    private let DEBUG_TAG: String = "Server: "
    
    // TODO: turn into static Settings properties
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "local"
    
    var eventLoopGroup: EventLoopGroup?
    
    private lazy var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    
    weak var remoteManager: RemoteManager? {
        didSet {  warpinatorProvider.remoteManager = remoteManager  }
    }
    
    var settingsManager: SettingsManager
    
    var authenticationManager: Authenticator
    
    
    // We have to capture the serverBuilder future here or it will sometimes be
    // deallocated before it can finish
    var future: EventLoopFuture<GRPC.Server>?
    var server: GRPC.Server?
    
    
    let queueLabel = "WarpinatorServerQueue"
    lazy var serverQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
//    var logger: Logger = {
//        var log = Logger(label: "warpinator.Server", factory: StreamLogHandler.standardOutput)
//        log.logLevel = .debug
//        return log
//    }()
    
    
    init(settingsManager settings: SettingsManager, authenticationManager authenticator: Authenticator) {
        
        settingsManager = settings
        authenticationManager = authenticator
        
        warpinatorProvider.settingsManager = settingsManager
    }
    
    
    //
    // MARK: start
    func start() throws -> EventLoopFuture<GRPC.Server>?  {
        
        guard let serverELG = eventLoopGroup else {
            throw ServerError.NO_EVENTLOOP
        }
        
        // TODO: check if this needs to be regenerated
//        authenticationManager.generateNewCertificate()
        
        
        do {
            let serverCertificate = try authenticationManager.getServerCertificate()
            let serverPrivateKey = try authenticationManager.getServerPrivateKey()
        
        
            print(DEBUG_TAG+"verifying certificate")
            print(DEBUG_TAG+"\t certificate is valid: \(authenticationManager.verify(certificate: serverCertificate))")
            
        
        //
        // if we don't capture 'future' here, it will be deallocated before .whenSuccess can be called
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
            
        } catch {
            print(DEBUG_TAG+"Error retrieving server credentials: \n\t\t \(error)")
            throw ServerError.CREDENTIALS_INVALID
        }

        return future
    }
    
    
    // MARK: stop
    func stop() -> EventLoopFuture<Void>? {
        guard let server = server else {
            return eventLoopGroup?.next().makeSucceededVoidFuture()
        }
        return server.initiateGracefulShutdown()
    }
    
    
}

