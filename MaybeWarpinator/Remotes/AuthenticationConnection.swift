//
//  AuthenticationConnection.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-12.
//

import Foundation

import NIO
import NIOSSL

import GRPC
import Network

import Logging



enum AuthenticationError: Error {
    case TimeOut
    case ConnectionError
    case CertificateError
}

// MARK: - AuthenticationConnection
protocol AuthenticationConnection {
    
    var details: RemoteDetails { get }
    var registree: AuthenticationRecipient { get }
    
    var uuid: Int { get }
    var attempts: Int { get set }
    
    func requestCertificate()
}


// MARK:  AuthenticationRecipient
protocol AuthenticationRecipient {
    func authenticationCertificateObtained(forRemote details: RemoteDetails, certificate: NIOSSLCertificate)
    func failedToObtainCertificate(forRemote details: RemoteDetails, _ error: AuthenticationError)
}


// MARK: - UDPConnection
class UDPConnection: AuthenticationConnection {
    
    private let DEBUG_TAG: String = "UDPConnection: "
    
    var details: RemoteDetails
    var registree: AuthenticationRecipient
    
    var uuid: Int {
        return details.endpoint.hashValue
    }
    
    var attempts: Int = 0
    
    var endpoint: NWEndpoint
    var connection: NWConnection
    
    
    init(_ candidate: RemoteDetails, manager: AuthenticationRecipient) {
        self.details = candidate
        registree = manager
        
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
            case .ready:
                
                if let ip4_string = self.connection.currentPath?.remoteEndpoint?.debugDescription {
//                    print(self.DEBUG_TAG+"connection to \(self.endpoint) ready (ipv4 address: \(ip4))");
                    // ip4_string should be a string formatted as 0.0.0.0%en0:0000. IP address is section of string before the '%'
                    let components = ip4_string.split(separator: Character("%"))
                    let ip4_address: String = String(components[0])
                    print(self.DEBUG_TAG+"extracted IP Address: \(ip4_address)")
                    self.details.ipAddress = ip4_address //String(components[0])
                }
                
                
                self.sendCertificateRequest()
            default: print(self.DEBUG_TAG+"connection to \(self.endpoint) state updated: \(newState)")
            }
        }
        
    }
    
    
    func requestCertificate(){
        
        print(DEBUG_TAG+"requesting certificate from \(details.endpoint)")
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
                    
                    self.registree.authenticationCertificateObtained(forRemote: self.details, certificate: certificate)

                } else {  print("Failed to decode certificate")  }

            } else {   print("No data received") }
        }
        
    }
    
}




// MARK: - GRPCConnection
class GRPCConnection: AuthenticationConnection {
    
    private let DEBUG_TAG: String = "GRPCConnection: "
    
    var details: RemoteDetails
    var registree: AuthenticationRecipient
    
    var uuid: Int {
        return details.endpoint.hashValue
    }
    
    var attempts: Int = 0
    
    var channel: ClientConnection
    var warpClient: WarpRegistrationClient
    
    let group = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    init(_ candidate: RemoteDetails, manager: AuthenticationRecipient) {
        self.details = candidate
        registree = manager
        
        
        let hostname = details.ipAddress // "192.168.2.18"
//        let hostname = details.hostname
        let port = details.authPort
        
        print(DEBUG_TAG+"created for \"\(hostname):\(port)\"")
        
        
        channel = ClientConnection.insecure(group: group).connect(host: hostname, port: port)
        warpClient = WarpRegistrationClient(channel: channel)
    }
    
    
    func requestCertificate(){
        print(DEBUG_TAG+"requesting certificate from \(details.hostname):\(details.authPort)")
        details.status = .FetchingCredentials
        sendCertificateRequest()
    }
    
    
    func sendCertificateRequest() {
        let request: RegRequest = .with {
            $0.hostname = Server.SERVER_UUID
            $0.ip = Utils.getIPV4Address()
        }
        
//        let logger: Logger = {
//            var logger = Logger(label: "warpinator.GRPCConnection", factory: StreamLogHandler.standardOutput)
//            logger.logLevel = .debug
//            return logger }()
        
        
//        let options = CallOptions(timeLimit: .timeout( .seconds(10)), logger: logger )
//        let options = CallOptions(logger: logger )

//        let registrationRequest = warpClient.requestCertificate(request, callOptions: options)
        let registrationRequest = warpClient.requestCertificate(request)

        registrationRequest.response.whenSuccess { result in
            if let certificate = Authenticator.shared.unlockCertificate(result.lockedCert){
                self.registree.authenticationCertificateObtained(forRemote: self.details, certificate: certificate)
            } else {
                self.registree.failedToObtainCertificate(forRemote: self.details, .CertificateError)
            }
        }
        
        registrationRequest.response.whenFailure { error in
            print(self.DEBUG_TAG+"Certificate request failed: \(error)")
            self.registree.failedToObtainCertificate(forRemote: self.details, .ConnectionError)
        }
    }
}
