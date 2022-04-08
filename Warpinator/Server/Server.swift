//
//  Server.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-04.
//

import UIKit

import GRPC
import NIO
import NIOSSL

import Network

import Logging


final class Server {
    
    //
    // MARK: ServerError
    enum ServerError: Error {
        case NO_EVENTLOOP
        case CREDENTIALS_INVALID
        case CREDENTIALS_UNAVAILABLE
        case CREDENTIALS_GENERATION_ERROR
        case SERVER_FAILURE
        case UKNOWN_ERROR
        
        var localizedDescription: String {
            switch self {
            case .NO_EVENTLOOP: return "No available eventloop"
            case .CREDENTIALS_INVALID: return "Server certificate and/or private key are invalid"
            case .CREDENTIALS_UNAVAILABLE: return "Server certificate and/or private key could not be found"
            case .CREDENTIALS_GENERATION_ERROR: return "Server credentials could not be created"
            case .SERVER_FAILURE: return "Server failed to start"
            case .UKNOWN_ERROR: return "Server has encountered an unknown error"
            }
        }
    }
    
    
    private let DEBUG_TAG: String = "Server: "
    
    // TODO: turn into static Settings properties
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "local"
    
    var eventLoopGroup: EventLoopGroup
    
    private lazy var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    
    var remoteManager: RemoteManager
    
//    var settingsManager: SettingsManager
//
//    var authenticationManager: Authenticator
    
    var errorDelegate: ErrorDelegate?
    
    var server: GRPC.Server?
    var attempts = 0
    
    let queueLabel = "WarpinatorServerQueue"
    lazy var serverQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    var logger: Logger = {
        var log = Logger(label: "warpinator.Server", factory: StreamLogHandler.standardOutput)
        log.logLevel = .debug
        return log
    }()
    
    
    init(eventloopGroup group: EventLoopGroup,
//         settingsManager settings: SettingsManager,
//         authenticationManager authenticator: Authenticator,
         remoteManager: RemoteManager, errorDelegate delegate: ErrorDelegate) {
        
        eventLoopGroup = group
//        settingsManager = settings
//        authenticationManager = authenticator
        self.remoteManager = remoteManager
        
        errorDelegate = delegate
        
//        warpinatorProvider.settingsManager = settingsManager
        warpinatorProvider.remoteManager = remoteManager
    }
    
    
    //
    // MARK: start
    func start() -> EventLoopFuture<GRPC.Server>  {
        
        // don't create a new server if we have one going already
//        if let server = server {
//            return  server.channel.eventLoop.makeSucceededFuture(server)
//        }
        
        guard let credentials = try? Authenticator.shared.getServerCredentials() else {
            return eventLoopGroup.next().makeFailedFuture( ServerError.CREDENTIALS_GENERATION_ERROR )
        }
        
        let serverCertificate =  credentials.certificate
        let serverPrivateKey = credentials.key
        
        //
        // if we don't capture 'future' here, it will be deallocated before .whenSuccess can be called
        let future = GRPC.Server.usingTLSBackedByNIOSSL(on: eventLoopGroup,
                                                        certificateChain: [ serverCertificate  ],
                                                        privateKey: serverPrivateKey )
            .withTLS(trustRoots: .certificates( [serverCertificate ] ) )
            .withServiceProviders( [ warpinatorProvider ] )
            .withLogger(logger)
            .bind(host: "\(Utils.getIP_V4_Address())",
                  port: Int( SettingsManager.shared.transferPortNumber ))
        
        // onError: attempt restart after 2 seconds
        .flatMapError { error in
            
            print( self.DEBUG_TAG + "transfer server failed: \(error))")
            
//            let scheduledTask =
            return self.eventLoopGroup.next().flatScheduleTask(in: .seconds(2)) {
                self.start()
            }.futureResult
//            return scheduledTask.futureResult
        }
        
        future.whenSuccess { [weak self] server in
            print((self?.DEBUG_TAG ?? "(server is nil): ")+"transfer server started on: \(String(describing: server.channel.localAddress))")
            self?.server = server
        }
        
//        future.whenFailure { [weak self] error in
//
//            print( (self?.DEBUG_TAG ?? "(server is nil): ") + "transfer server failed: \(error))")
//        }
        
        return future
    }
    
    
    // MARK: stop
    func stop() -> EventLoopFuture<Void> {
        guard let server = server else {
            return eventLoopGroup.next().makeSucceededVoidFuture()
        }
        
        return server.initiateGracefulShutdown()
    }
    
    
}

