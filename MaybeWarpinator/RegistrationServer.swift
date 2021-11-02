//
//  RegistrationServer.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-01.
//

import Foundation

import NIO
import NIOSSL

import GRPC
import Network





class RegistrationConnection {
    
    private var DEBUG_TAG: String = "RegistrationConnection"
    
    var endpoint: NWEndpoint
    var connection: NWConnection?
    
    var onReady: ()->Void
    
    init?(to destinationEndpoint: NWEndpoint, onReady: @escaping ()->Void = {} ){
        
        self.onReady = onReady
        
        switch destinationEndpoint {
        case .hostPort(host: _, port: _):
            print(DEBUG_TAG+"creating connection to host/port")
            endpoint = destinationEndpoint
        case .service(name: _, type: _, domain: _, interface: _):
            print(DEBUG_TAG+"creating connection to service")
            endpoint = destinationEndpoint
        default: print(DEBUG_TAG+"unknown service endpoint type: \(destinationEndpoint)"); return nil
        }
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.allowFastOpen = true
        
        connection = NWConnection(to: endpoint, using: params)
        connection?.stateUpdateHandler = { newState in
            switch newState {
            case .ready: print(self.DEBUG_TAG+"connection to \(self.endpoint) ready");
                self.onReady()
            default: print(self.DEBUG_TAG+"connection to \(self.endpoint) state updated: \(newState)")
            }
        }
        connection?.start(queue: .main)
    }
    
}

class RegistrationServer {
    
    private let DEBUG_TAG: String = "RegistrationServer: "
    
    public static let REGISTRATION_PORT: Int = 42001
    
    private var registration_port: Int = RegistrationServer.REGISTRATION_PORT
    
    private lazy var uuid: String = Server.SERVER_UUID
    
    
    var mDNSServiceBrowser: MDNSBrowser?
    var mDNSServiceListener: MDNSListener?
    
    var registrationConnections: [NWEndpoint: NWConnection] = [:]
    
    var certificateServer = CertificateServer()
    
    
    var mDNSBrowser: MDNSBrowser?
    var mDNSListener: MDNSListener?
    
    var registrationCandidates: [String: UnregisteredRemote] = [:]
    
    private var registrationServer: GRPC.Server?
    private var eventLoopGroup: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1,
                                                                                          networkPreference: .best)

    
    private var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    private var warpinatorRegistrationProvider: WarpinatorRegistrationProvider = WarpinatorRegistrationProvider()
    
    
    
    func start(){
        
        mDNSBrowser = MDNSBrowser()
        mDNSBrowser?.delegate = self
        
        mDNSListener = MDNSListener()
        mDNSListener?.delegate = self
        mDNSListener?.start()
        
        
        
        let serverBuilder = GRPC.Server.insecure(group: eventLoopGroup)
        
        
        let registrationServerFuture = serverBuilder.withServiceProviders([warpinatorRegistrationProvider])
            .bind(host: "\(Utils.getIPV4Address())", port: registration_port)
            
        
        registrationServerFuture.whenComplete { result in
            if let server = try? result.get() {
                self.registrationServer = server
            } else { print(self.DEBUG_TAG+"Failed to get registration server") }
        }
        
        registrationServerFuture.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            print(self.DEBUG_TAG+"registration server started on: \(String(describing: address))")
        }
        
        
        let closefuture = registrationServerFuture.flatMap {
            $0.onClose
        }
        
        closefuture.whenCompleteBlocking(onto: .main) { _ in
            print(self.DEBUG_TAG+" registration server exited")
        }
        closefuture.whenCompleteBlocking(onto: DispatchQueue(label: "cleanup-queue")){ _ in
            try! self.eventLoopGroup.syncShutdownGracefully()
        }
        
    }
    
    
    
    
    func register(_ candidate: UnregisteredRemote){
        
//        // establish connection with unregistered remote
//        let params = NWParameters.udp
//        params.allowLocalEndpointReuse = true
//        params.allowFastOpen = true
//
//        let connection = NWConnection(to: endpoint, using: params)
//        connection?.stateUpdateHandler = { newState in
//            switch newState {
//            case .ready: print(self.DEBUG_TAG+"connection ready");
//
//                self.api_v1_fetchCertificate()
//            default: print(self.DEBUG_TAG+"state updated: \(newState)")
//            }
//        }
//        connection?.start(queue: .main)
        
        
        
    }
    
    
    
}





// MARK: - MDNSListenerDelegate
extension RegistrationServer: MDNSListenerDelegate {

    func mDNSListenerIsReady() {
        mDNSServiceBrowser?.startBrowsing()
    }
    
    func mDNSListenerDidEstablishIncomingConnection(_ connection: NWConnection) {
        
            print(DEBUG_TAG+"BOOM nothing")
    }
}



// MARK: - MDNSBrowserDelegate
extension RegistrationServer: MDNSBrowserDelegate {
    
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result) {
        
        // if the metadata has a record "type",
        // and if type is 'flush', then ignore this service
        if case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata,
           let type = record.dictionary["type"],
           type == "flush" {
            print(DEBUG_TAG+"service is flushing; ignore"); return
        }
        
        
        switch result.endpoint {
        case .hostPort(host: _, port: _): break
            
        case .service(name: let name, type: _, domain: _, interface: _):
            if name == uuid {
                print(DEBUG_TAG+"Found myself (\(result.endpoint)"); return
            } else {
                print(DEBUG_TAG+"service discovered: \(name)")
            }
        default: print(DEBUG_TAG+"unknown service endpoint type: \(result.endpoint)"); return
        }
        
        
        print(DEBUG_TAG+"mDNSBrowser did add result:")
        print("\t\(result.endpoint)")
        print("\t\(result.metadata)")
        print("\t\(result.interfaces)")
        
        
        var candidate = UnregisteredRemote(endpoint: result.endpoint)
        
        
        if case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata {
            if let hn = record.dictionary["hostname"] {
                candidate.hostname = hn
            }
        }
        
        print(DEBUG_TAG+"adding remote")

    }
    
}
