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

//import CryptoKit
//import Sodium


public class Server: NSObject {
    
    
//    public static var shared: Server!
    
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
    
    
//    var certificateServer = CertificateServer()
    
    
    private var transferServer: GRPC.Server?
    private var eventLoopGroup: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    
//    private var registrationServer: GRPC.Server?
//    private var eventLoopGroup2: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)

    
    private var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
//    private var warpinatorRegistrationProvider: WarpinatorRegistrationProvider = WarpinatorRegistrationProvider()
    
    
//    var mDNSBrowser: MDNSBrowser?
//    var mDNSListener: MDNSListener?
    
    
//    var registrationConnections: [NWEndpoint: NWConnection] = [:]
//    var remotes: [String: Remote] = [:]
    
    
    var remoteManager: RemoteManager? {
        didSet {
            warpinatorProvider.remoteManager = remoteManager 
        }
    }
    
    func start(){
        
//        Server.shared = self
        
//        do {
//            try certificateServer.start()
//        }catch {
//            (DEBUG_TAG+"certificateServer failed: \(error.localizedDescription)")
//        }
        
//        publishWarpinatorService()
        
//        startRegistrationServer()
        startWarpinatorServer()
        
//        mDNSBrowser = MDNSBrowser()
//        mDNSBrowser?.delegate = self
//
//        mDNSListener = MDNSListener()
//        mDNSListener?.delegate = self
//        mDNSListener?.start()  //publishServiceAndListen()
        
    }
    
    
    
    // MARK Registration Server
//    func startRegistrationServer(){
//        
//        let serverBuilder = GRPC.Server.insecure(group: eventLoopGroup2)
//        
//        
//        let registrationServerFuture = serverBuilder.withServiceProviders([warpinatorRegistrationProvider])
//            .bind(host: "\(Utils.getIPV4Address())", port: registration_port)
//            
//        
//        registrationServerFuture.whenComplete { result in
////            print(self.DEBUG_TAG+"fetch registration server object")
//            if let server = try? result.get() {
////                print(self.DEBUG_TAG+"registration server stored")
//                self.registrationServer = server
//            } else { print(self.DEBUG_TAG+"Failed to get registration server") }
//        }
//        
//        registrationServerFuture.map {
//            $0.channel.localAddress
//        }.whenSuccess { address in
//            print(self.DEBUG_TAG+"registration server started on: \(String(describing: address))")
//        }
//        
//        
//        let closefuture = registrationServerFuture.flatMap {
//            $0.onClose
//        }
//        
//        closefuture.whenCompleteBlocking(onto: .main) { _ in
//            print(self.DEBUG_TAG+" registration server exited")
//        }
//        closefuture.whenCompleteBlocking(onto: DispatchQueue(label: "cleanup-queue")){ _ in
//            try! self.eventLoopGroup2.syncShutdownGracefully()
//        }
//    }
    
    
    
    
    
    
    // MARK: Transfer Server
    func startWarpinatorServer(){
        
        
//        let _ = Authenticator.shared.generateNewCertificate(forHostname: "\(Server.SERVER_UUID)")
        
        
//        let authority = Authenticator.shared.getServerCertificateBundle()      //getSigningAuthority()
        guard let serverCertificate = Authenticator.shared.getServerCertificate() else { return }
        guard let serverPrivateKey = Authenticator.shared.getServerPrivateKey() else { return }
        
        
//        print(DEBUG_TAG+"CA is \(authority)")
        print(DEBUG_TAG+"certificate is \(serverCertificate)")
        print(DEBUG_TAG+"privatekey is \(serverPrivateKey)")
        
        
        let keepalive = ServerConnectionKeepalive(interval: .milliseconds(10_000),
                                                  timeout: .milliseconds(5000),
                                                  permitWithoutCalls: true,
                                                  maximumPingsWithoutData: 0,
                                                  minimumSentPingIntervalWithoutData: .milliseconds(5000),
                                                  minimumReceivedPingIntervalWithoutData: .milliseconds(5000) )
        
        let serverBuilder = GRPC.Server.usingTLSBackedByNIOSSL(on: eventLoopGroup,
                                                               certificateChain: [ serverCertificate  ],
                                                               privateKey: serverPrivateKey)
            .withTLS(trustRoots: .certificates( [serverCertificate] ) )
            .withServiceProviders([warpinatorProvider])
            .withKeepalive(keepalive)
        
        let transferFuture = serverBuilder
            .bind(host: "\(Utils.getIPV4Address())", port: transfer_port)
        
        
        
        
        transferFuture.whenComplete { result in
//            print("fetch transfer server object")
            if let server = try? result.get() {
//                print("transfer server stored")
                self.transferServer = server
            } else { print(self.DEBUG_TAG+"Failed to get transfer server") }
        }
        
        
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
            try! self.eventLoopGroup.syncShutdownGracefully()
        }
    }
    
    
    // MARK Add remote
//    func addRemote(_ remote: Remote){
//        remotes[remote.uuid] = remote
//    }
    
}




// MARK  MDNSListenerDelegate
//extension Server: MDNSListenerDelegate {
//
//    func mDNSListenerIsReady() {
//        print("listener is ready")
//        mDNSBrowser?.startBrowsing()
//    }
//
//    func mDNSListenerDidEstablishIncomingConnection(_ connection: NWConnection) {
//        print(DEBUG_TAG+"BOOM nothing")
//        print(DEBUG_TAG+"listener established connection")
//
//        registrationConnections[connection.endpoint] = connection
//
//        connection.stateUpdateHandler = { [self] newState in
////            print("state updated")
//            switch newState {
//            case.ready: print(DEBUG_TAG+"established connection to \(connection.endpoint) is ready")
//                self.certificateServer.serveCertificate(to: connection) {
//                    self.registrationConnections.removeValue(forKey: connection.endpoint)
//                }
//            default: print(DEBUG_TAG+"new connection \(connection.endpoint), state: \(newState)")
//            }
//        }
//        connection.start(queue: .main)
//
//    }
//}



// MARK MDNSBrowserDelegate
//extension Server: MDNSBrowserDelegate {
    
//    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result) {
        
//        switch result.endpoint {
//        case .hostPort(host: _, port: _): break
//
//        case .service(name: let name, type: _, domain: _, interface: _):
//            if name == uuid {
//                print(DEBUG_TAG+"Found myself (\(result.endpoint)"); return
//            } else {
//                print(DEBUG_TAG+"service discovered: \(name)")
//            }
//        default: print(DEBUG_TAG+"unknown service endpoint: \(result.endpoint)"); return
//        }
//
//
//        print(DEBUG_TAG+"mDNSBrowser did add result:")
//        print("\t\(result.endpoint)")
//        print("\t\(result.metadata)")
//        print("\t\(result.interfaces)")
        
//        let remote = RegisteredRemote(endpoint: result.endpoint)
        
        
//        if case let NWEndpoint.hostPort(host: host, port: port) = result.endpoint {
//            remote.IPAddress = host // String(describing: host)
//            remote.port = port
//        }
        
        
        // if the metadata has a record "type",
        // and if type is 'flush', then ignore this service
//        if case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata,
//           let type = record.dictionary["type"],
//           type == "flush" {
//            print(DEBUG_TAG+"service is flushing; ignore"); return
//        }
        
//        if case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata {
//            if let hn = record.dictionary["hostname"] {
//                remote.hostname = hn
//            }
//        }
//
//        print(DEBUG_TAG+"adding remote")
//
////        remote.hostname = hostname
//        remote.serviceAvailable = true
//
//        addRemote(remote)
//        remote.connect()
//    }
//
//}
