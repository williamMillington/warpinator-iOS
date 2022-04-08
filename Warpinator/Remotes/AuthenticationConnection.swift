//
//  AuthenticationConnection.swift
//  Warpinator
//
//  Created by William Millington on 2021-12-12.
//

import Foundation

import NIO
import NIOSSL

import GRPC
import Network

import Logging







//
// MARK: AuthenticationError
enum AuthenticationError: Error {
    case TimeOut
    case ConnectionError
    case CertificateError
}


//
// MARK: protocol: Connection
protocol AuthenticationConnection {
    
    var details: RemoteDetails { get }
    var delegate: AuthenticationConnectionDelegate { get }
    
    func requestCertificate()
}


//
// MARK:  protocol: Recipient
protocol AuthenticationConnectionDelegate {
    var details: RemoteDetails { get  set }
    func certificateObtained(forRemote details: RemoteDetails,
                                           certificate: NIOSSLCertificate)
    func certificateRequestFailed(forRemote details: RemoteDetails,
                                   _ error: AuthenticationError)
}






//
// MARK: - UDPConnection
final class UDPConnection: AuthenticationConnection {
    
    private let DEBUG_TAG: String = "UDPConnection: "
    
    var details: RemoteDetails
    var delegate: AuthenticationConnectionDelegate
    
    var attempts: Int = 0
    
    var endpoint: NWEndpoint
    var connection: NWConnection
    
    
    init(delegate: AuthenticationConnectionDelegate) {
        self.delegate = delegate
        self.details = delegate.details
        
        endpoint = details.endpoint
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .wifi
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        connection = NWConnection(to: endpoint, using: params)
        
    }
    
    
    //
    // MARK: requestCertificate
    func requestCertificate(){
        
        connection.stateUpdateHandler = { [weak self] state in
            
            guard let self = self else { return }
            
            if case .ready = state {
                
                if let addressInfo = Utils.extractAddressInfo(fromConnection: self.connection) {
                    self.details.ipAddress = addressInfo.address
                    self.details.port = addressInfo.port
                }
                
                self.sendCertificateRequest()
            } else {
                print(self.DEBUG_TAG+" state is \(state)")
            }
        }
        
        print(DEBUG_TAG+"requesting certificate from \(details.endpoint)")
//        details.status = .FetchingCredentials
        
        connection.start(queue: .global())
    }
    
    
    //
    // MARK: receiveCertificate
    private func sendCertificateRequest(  ){
        
        details.status = .FetchingCredentials
        connection.send(content: "REQUEST".bytes ,
                        completion: .contentProcessed { error in
            
            guard error == nil else {
                print(self.DEBUG_TAG+"request failed: \(String(describing: error))")
                return
            }
            
            // if "Request" was successfully received,
            // proceed with receiving the certificate
            self.receiveCertificate()
            
        })
    }
    
    
    //
    // MARK: receiveCertificate
    private func receiveCertificate(){
        
        // RECEIVING CERTIFICATE
        connection.receiveMessage  { [weak self] (data, context, isComplete, error) in
//            guard let self = self else { return }
            guard let self = self ,error == nil else {
                print("AuthenticationError: \(String(describing: error))"); return
            } 
            
            if isComplete {

                guard let concrete_data = data else {
                    print(self.DEBUG_TAG+"Error: data is nil")
                    return
                }
                guard let decodedCertificateData = Data(base64Encoded: concrete_data, options: .ignoreUnknownCharacters  ) else {
                    print("Failed to decode certificate")
                    return
                }
                
                guard let certificate = Authenticator.shared.unlockCertificate(decodedCertificateData) else {
                    print(self.DEBUG_TAG+"failed to unlock certificate"); return
                }
                
                self.delegate.certificateObtained(forRemote: self.details,
                                                                 certificate: certificate)

                self.connection.cancel() //finish()
                
            } else {
                print("No data received")
            }
        }
    }
    
    
    //
    // MARK finish
//    func finish(){
//        connection.cancel()
//    }
    
}






//
// MARK: - GRPCConnection
final class GRPCConnection: AuthenticationConnection {
    
    private lazy var DEBUG_TAG: String = "GRPCConnection (\(details.endpoint)): "
    
    var details: RemoteDetails
    var delegate: AuthenticationConnectionDelegate
    
    let ipConnection: NWConnection
    
    var attempts: Int = 0
    
    let request: RegRequest = .with {
        $0.hostname = SettingsManager.shared.hostname
        $0.ip = Utils.getIP_V4_Address()
    }
    
//    var channel: ClientConnection?
    var warpClient: WarpRegistrationClient?
    
    weak var group: EventLoopGroup? //= GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    init(onRventLoopGroup group: EventLoopGroup, delegate: AuthenticationConnectionDelegate) {
//        self.details = candidate
        
        self.group = group
        self.delegate = delegate
        details = delegate.details
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .wifi
        
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
//            print(DEBUG_TAG+"restrict connection to v4")
            inetOptions.version = .v4
        }
        
        
        // We need to start by resolving a regular ol' NWConnection in order
        // to secure an IP address
        ipConnection = NWConnection(to: details.endpoint, using: params)
        
    }
    
    
    //
    // MARK: start request
    func requestCertificate(){
        
        ipConnection.stateUpdateHandler = { [weak self] state in
            
            guard let self = self else { print("GRPC deallocated?"); return }
            
            if case .ready = state {
                
                if let addressInfo = Utils.extractAddressInfo(fromConnection: self.ipConnection) {
                    self.details.ipAddress = addressInfo.address
                    self.details.port = addressInfo.port
                }
                
                self.ipConnection.cancel()
                self.sendCertificateRequest()
            } else {
                print(self.DEBUG_TAG+" state is \(state)")
            }
        }
        
        ipConnection.start(queue: .main)
    }
    
    
    //
    // MARK: send request
    func sendCertificateRequest() {
        
        guard let group = group else { return }
        
        let channel = ClientConnection.insecure(group: group).connect(host: details.ipAddress,
                                                                      port: details.authPort)
        
        warpClient = WarpRegistrationClient(channel: channel)
        
        print(DEBUG_TAG+"requesting certificate from \(details.hostname) (\(details.ipAddress):\(details.authPort))")
        details.status = .FetchingCredentials
        
//        let logger: Logger = {
//            var logger = Logger(label: "warpinator.GRPCConnection", factory: StreamLogHandler.standardOutput)
//            logger.logLevel = .debug
//            return logger }()
        
//        let options = CallOptions(timeLimit: .timeout( .seconds(10)), logger: logger )
//        let options = CallOptions(logger: logger )

        let requestFuture = warpClient?.requestCertificate(request).response

        requestFuture?.whenComplete { [weak self] response in
            guard let self = self else { return }
            
            do {
                let result = try response.get()
//                print(self.DEBUG_TAG + "result is \(result)")
                
                if let certificate = Authenticator.shared.unlockCertificate(result.lockedCert) {
                    self.delegate.certificateObtained(forRemote: self.details, certificate: certificate)
                } else {
                    self.delegate.certificateRequestFailed(forRemote: self.details, .CertificateError)
                }
                
            } catch {
                print( self.DEBUG_TAG + "request failed because: \(error)")
                self.delegate.certificateRequestFailed(forRemote: self.details, .ConnectionError)
            }
            
//            self.finish()
            let _ = self.warpClient?.channel.close()
        }
        
    }
    
    
    //
    // MARK finish
//    func finish(){
        
//        let future = warpClient?.channel.close()
        
//        future?.whenComplete { [weak self] response in
////            print((self?.DEBUG_TAG ?? "(GRPCConnction is nil): ")+"channel finished closing")
//            do {
//                let _ = try response.get()
////                print((self?.DEBUG_TAG ?? "(GRPCConnction is nil): ")+"\t\tresult retrieved")
//            } catch  {
//                    print((self?.DEBUG_TAG ?? "(GRPCConnction is nil): ")+"\t\terror: \(error)")
//            }
//            self?.warpClient = nil
//        }
//    }
}










