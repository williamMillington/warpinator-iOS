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



enum RegistrationError: Error {
    case TimeOut
    case ConnectionError
    case CertificateError
}

// MARK: - RegistrationConnection
protocol RegistrationConnection {
    
    var details: RemoteDetails { get }
    var registrationServer: RegistrationServer { get }
    
    var uuid: Int { get }
    var attempts: Int { get set }
    
    func register()
}



// MARK: - UDPConnection
class UDPConnection: RegistrationConnection {
    
    private let DEBUG_TAG: String = "UDPConnection: "
    
    var details: RemoteDetails
    var registrationServer: RegistrationServer
    
    var uuid: Int {
        return details.endpoint.hashValue
    }
    
    var attempts: Int = 0
    
    var endpoint: NWEndpoint
    var connection: NWConnection
    
    
    init(_ candidate: RemoteDetails, server: RegistrationServer) {
        self.details = candidate
        registrationServer = server
        
        endpoint = candidate.endpoint
        
        let params = NWParameters.udp
        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
//            print(DEBUG_TAG+"restrict connection to v4")
            inetOptions.version = .v4
        }
        
        connection = NWConnection(to: endpoint, using: params)
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready: print(self.DEBUG_TAG+"connection to \(self.endpoint) ready");
                self.sendCertificateRequest()
            default: print(self.DEBUG_TAG+"connection to \(self.endpoint) state updated: \(newState)")
            }
        }
        
    }
    
    
    func register(){
        
        print(DEBUG_TAG+"Registering with \(details.endpoint)")
        details.status = .FetchingCredentials
        
        connection.start(queue: .main)
    }
    
    
    private func sendCertificateRequest(  ){
//        print(DEBUG_TAG+"api_v1_fetching certificate")

        let requestStringBytes = "REQUEST".bytes
        connection.send(content: requestStringBytes,
                        completion: NWConnection.SendCompletion.contentProcessed { error in

                            if error == nil {
                                self.receiveCertificate()
                            } else {
                                print(self.DEBUG_TAG+"request failed: \(String(describing: error))")
                            }

                        })
    }
    
    
    private func receiveCertificate(){
        
        // RECEIVING CERTIFICATE
        connection.receiveMessage  { (data, context, isComplete, error) in

            if isComplete {

                if let concrete_data = data,
                   let decodedCertificateData = Data(base64Encoded: concrete_data, options: .ignoreUnknownCharacters  ) {

                    guard let certificate = Authenticator.shared.unlockCertificate(decodedCertificateData) else {
                        print(self.DEBUG_TAG+"failed to unlock certificate"); return
                    }
                    
                    self.registrationServer.registrationSucceeded(forRemote: self.details, certificate: certificate)

                } else {  print("Failed to decode certificate")  }

            } else {   print("No data received") }
        }
        
    }
    
}




// MARK: - GRPCConnection
class GRPCConnection: RegistrationConnection {
    
    private let DEBUG_TAG: String = "GRPCConnection: "
    
    var details: RemoteDetails
    var registrationServer: RegistrationServer
    
    var uuid: Int {
        return details.endpoint.hashValue
    }
    
    var attempts: Int = 0
    
    var channel: ClientConnection
    var warpClient: WarpRegistrationClient
    
    let group = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    
    init(_ candidate: RemoteDetails, server: RegistrationServer) {
        self.details = candidate
        registrationServer = server
        
        
        let port = details.authPort
        let hostname = details.hostname
        
        channel = ClientConnection.insecure(group: group).connect(host: hostname, port: port)
        warpClient = WarpRegistrationClient(channel: channel)
    }
    
    
    func register(){
        print(DEBUG_TAG+"Registering with \(details.endpoint)")
        details.status = .FetchingCredentials
        sendCertificateRequest()
    }
    
    
    func sendCertificateRequest() {
        let request: RegRequest = .with {
            $0.hostname = Server.SERVER_UUID
            $0.ip = Utils.getIPV4Address()
        }
        let options = CallOptions(timeLimit: .timeout( .seconds(5)) )

        let registrationRequest = warpClient.requestCertificate(request, callOptions: options)

        registrationRequest.response.whenSuccess { result in
            if let certificate = Authenticator.shared.unlockCertificate(result.lockedCert){
                self.registrationServer.registrationSucceeded(forRemote: self.details, certificate: certificate)
            } else {
                self.registrationServer.registrationFailed(forRemote: self.details, .CertificateError)
            }
        }
        
        registrationRequest.response.whenFailure { error in
            self.registrationServer.registrationFailed(forRemote: self.details, .ConnectionError)
        }
    }
}






// MARK: - Registration Server
class RegistrationServer {
    
    private let DEBUG_TAG: String = "RegistrationServer: "
    
    public static let REGISTRATION_PORT: Int = 42001
    
    private var registration_port: Int = RegistrationServer.REGISTRATION_PORT
    
    private lazy var uuid: String = Server.SERVER_UUID
    
    var registrationConnections: [NWEndpoint: NWConnection] = [:]
    
    var certificateServer = CertificateServer()
    
    var mDNSBrowser: MDNSBrowser?
    var mDNSListener: MDNSListener?
    
    var registrationCandidates: [Int: RegistrationConnection] = [:]
    
    private var eventLoopGroup: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1,
                                                                                          networkPreference: .best)

    private var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    private var warpinatorRegistrationProvider: WarpinatorRegistrationProvider = WarpinatorRegistrationProvider()
    
    
    var remoteManager: RemoteManager? {
        didSet {
            warpinatorRegistrationProvider.remoteManager = remoteManager
        }
    }
    
    // MARK: - start server
    func start(){
        
        mDNSBrowser = MDNSBrowser()
        mDNSBrowser?.delegate = self
//        mDNSBrowser?.startBrowsing()
        
        mDNSListener = MDNSListener()
        mDNSListener?.delegate = self
        mDNSListener?.start()
        
        
        let registrationServerFuture = GRPC.Server.insecure(group: eventLoopGroup)
            .withServiceProviders([warpinatorRegistrationProvider])
            .bind(host: "\(Utils.getIPV4Address())", port: registration_port)
            
        
        
//        registrationServerFuture.whenComplete { result in
//            if let server = try? result.get() {
//                self.registrationServer = server
//            } else { print(self.DEBUG_TAG+"Failed to get registration server") }
//        }
        
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
    
    
    
    
    // MARK: - register
    func register(_ candidate: RemoteDetails){
        
//        print(DEBUG_TAG+"attempting to register remote")
        
        // api_1: use udp to authenticate
        // api_2: use GRPC call
        let newConnection: RegistrationConnection
        if candidate.api == "1" {
            newConnection = UDPConnection(candidate, server: self)
        } else {
            newConnection = GRPCConnection(candidate, server: self)
        }
        
        registrationCandidates[newConnection.uuid] = newConnection
        
        
        newConnection.register()
        
    }
    
    
    // MARK: - registrations success
    func registrationSucceeded(forRemote details: RemoteDetails, certificate: NIOSSLCertificate){
        
//        print(DEBUG_TAG+"registration succeeded")
        
        let newRemote = Remote(details: details, certificate: certificate)
        
        remoteManager?.addRemote(newRemote)
        newRemote.connect()
    }
    
    
    
    // MARK: - registrations failure
    func registrationFailed(forRemote details: RemoteDetails, _ error: RegistrationError){
        
        print(DEBUG_TAG+"registration failed, error: \(error)")
        
    }
    
    
}










// MARK: - MDNSListenerDelegate
extension RegistrationServer: MDNSListenerDelegate {

    func mDNSListenerIsReady() {
        mDNSBrowser?.startBrowsing()
    }
    
    func mDNSListenerDidEstablishIncomingConnection(_ connection: NWConnection) {
            print(DEBUG_TAG+"BOOM nothing")
    }
}



// MARK: - MDNSBrowserDelegate
extension RegistrationServer: MDNSBrowserDelegate {
    
    // MARK: didAddResult
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result) {
        
        // if the metadata has a record "type",
        // and if type is 'flush', then ignore this service
        if case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata,
           let type = record.dictionary["type"],
           type == "flush" {
            print(DEBUG_TAG+"service is flushing; ignore"); return
        }
        
        
        var serviceName = "unknown_service"
        switch result.endpoint {
        case .service(name: let name, type: _, domain: _, interface: _):
            
            serviceName = name
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
        
        
        if let remote = remoteManager?.containsRemote(for: serviceName) {
                print(DEBUG_TAG+"Service already known")
            if remote.details.status == .Disconnected ||
                remote.details.status == .Error {
                print(DEBUG_TAG+"\tstatus is disconnected/error: reconnecting...")
                remote.connect()
                return
            }
            
        }
        
        
        var details = RemoteDetails(endpoint: result.endpoint)
        details.serviceName = serviceName
        details.uuid = serviceName
        details.api = "1"
        details.port = 42000
        details.authPort = 42000 //"42000"
        details.status = .Disconnected
        
        // parse TXT record for metadata
        if case let NWBrowser.Result.Metadata.bonjour(TXTrecord) = result.metadata {
            
            for (key, value) in TXTrecord.dictionary {
                switch key {
                case "hostname": details.hostname = value
                case "api-version": details.api = value
                case "auth-port": details.authPort = Int(value) ?? 42000
                case "type": break
                default: print("unknown TXT record type: \(key)-\(value)")
                }
            }
        }
        
        
        register(details)
    }
    
}
