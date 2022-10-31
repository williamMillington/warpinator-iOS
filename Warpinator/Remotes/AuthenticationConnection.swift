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
//
protocol AuthenticationConnection {
    func requestCertificate() -> EventLoopFuture<AuthenticationInfo>
}

//
//
typealias AuthenticationInfo = (certificate: NIOSSLCertificate, address: String, port: Int)


//
//
enum AuthenticationError: Error {
    case TimeOut
    case ConnectionError
    case CertificateError
}







//
// MARK: - UDPConnection
final class UDPConnection: AuthenticationConnection {
    
    private let DEBUG_TAG: String = "UDPConnection: "
    
    let endpoint: NWEndpoint
    var connection: NWConnection
    
    let eventloopGroup: EventLoopGroup
    
    init(onEventLoopGroup group: EventLoopGroup, endpoint: NWEndpoint) {
        
        eventloopGroup = group
        
        self.endpoint = endpoint

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
    func requestCertificate() -> EventLoopFuture<AuthenticationInfo> {
        
        let promise = eventloopGroup.next().makePromise(of: AuthenticationInfo.self)
        
        connection.stateUpdateHandler = { [weak self] state in
            
            guard let self = self else { return }
            
            if case .ready = state {
                
                var address = "No Address"
                var port = -1
                if let addressInfo = Utils.extractAddressInfo(fromConnection: self.connection) {
                    address = addressInfo.address
                    port = addressInfo.port
                }
                
                self.sendCertificateRequest()
                    .whenComplete { result in
                    switch result {
                    case .success(let certificate):
                        promise.succeed( AuthenticationInfo(certificate: certificate,
                                                           address: address,
                                                           port: port) )
                    case .failure(let error):
                        promise.fail(error)
                    }
                }
                
            } else {
                print(self.DEBUG_TAG+" state is \(state)")
            }
        }
        
        print(DEBUG_TAG+"requesting certificate from \(endpoint)")
        
        connection.start(queue: .global())
        
        return promise.futureResult
    }
    
    
    //
    // MARK: sendRequest
    private func sendCertificateRequest() -> EventLoopFuture<NIOSSLCertificate> {
        
        let promise = eventloopGroup.next().makePromise(of: NIOSSLCertificate.self)
        
        connection.send(content: "REQUEST".bytes ,
                        completion: .contentProcessed { error in
            
            guard error == nil else {
                print(self.DEBUG_TAG+"request failed: \(String(describing: error))")
                promise.fail( AuthenticationError.ConnectionError )
                return
            }
            
            // if "Request" was successfully received,
            // proceed with receiving the certificate
            self.receiveCertificate().whenComplete { result in
                switch result {
                case .success(let certificate): promise.succeed(certificate)
                case .failure(let error):       promise.fail(error)
                }
            }
        })
        
        return promise.futureResult
    }
    
    
    //
    // MARK: receiveCertificate
    private func receiveCertificate() -> EventLoopFuture<NIOSSLCertificate> {
        
        let promise = eventloopGroup.next().makePromise(of: NIOSSLCertificate.self)
        
        // RECEIVING CERTIFICATE
        connection.receiveMessage  { [weak self] (data, context, isComplete, error) in
            
            guard let self = self ,error == nil else {
                print("AuthenticationError: \(String(describing: error))");
                promise.fail( AuthenticationError.ConnectionError )
                return
            } 
            
            if isComplete {

                if let concrete_data = data,
                   let decodedCertificateData = Data(base64Encoded: concrete_data,
                                                           options: .ignoreUnknownCharacters ),
                   let certificate = Authenticator.shared.unlockCertificate(decodedCertificateData) {
                    
                    promise.succeed(certificate)
                    
                } else {
                    promise.fail( AuthenticationError.CertificateError )
                }
                
                
                self.connection.cancel()
                
                
            } else {
                print("No data received")
                promise.fail( AuthenticationError.CertificateError )
            }
        }
        
        return promise.futureResult
    }
}






//
// MARK: - GRPCConnection
final class GRPCConnection: AuthenticationConnection {
    
    private lazy var DEBUG_TAG: String = "GRPCConnection (\(details.endpoint)): "
    
    var details: Remote.Details
    
    let ipConnection: NWConnection
    
    let request: RegRequest = .with {
        $0.hostname = SettingsManager.shared.hostname
        $0.ip = Utils.getIP_V4_Address()
    }
    
    var warpClient: WarpRegistrationClient?
    
    let eventloopGroup: EventLoopGroup
    init(onEventLoopGroup group: EventLoopGroup, details: Remote.Details) {
        
        eventloopGroup = group
        self.details = details
        
        let params = NWParameters.udp
        params.allowFastOpen = true
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
    func requestCertificate() -> EventLoopFuture<AuthenticationInfo> {
        
        let promise = eventloopGroup.next().makePromise(of: AuthenticationInfo.self )
        
        ipConnection.stateUpdateHandler = { [weak self] state in
            
            guard let self = self else { print("GRPCConnection: ipConnection deallocated?"); return }
            
            if case .ready = state {
                
                if let addressInfo = Utils.extractAddressInfo(fromConnection: self.ipConnection) {
                    self.details.ipAddress = addressInfo.address
                    self.details.port = addressInfo.port
                    print("GRPCConnection: extracted address -> \(self.details.ipAddress)")
                    print("GRPCConnection: extracted port -> \(self.details.port)")
                } else {
                    print("GRPCConnection: couldn't extract information")
                }
                
                self.ipConnection.cancel()
                 
                self.sendCertificateRequest().whenComplete { result in
                    switch result {
                    case .success(let conn_info): 
                        promise.succeed(conn_info)
                    case .failure(let error):
                        promise.fail(error)
                    }
                    _ = self.warpClient?.channel.close()
                }
                
            } else {
                print(self.DEBUG_TAG+" state is \(state)")
            }
        }
        
        ipConnection.start(queue: .global())
        
        return promise.futureResult
    }
    
    
    //
    // MARK: send request
    func sendCertificateRequest() -> EventLoopFuture<AuthenticationInfo> {
        
        let channel = ClientConnection.insecure(group: eventloopGroup).connect(host: details.ipAddress,
                                                                                port: details.authPort)
        
        warpClient = WarpRegistrationClient(channel: channel)
        
        print(DEBUG_TAG+"requesting certificate from \(details.hostname) (\(details.ipAddress):\(details.authPort))")
        
        let requestFuture = warpClient!.requestCertificate(request).response

        return requestFuture.flatMap { result in

            if let certificate = Authenticator.shared.unlockCertificate(result.lockedCert) {
                let info = AuthenticationInfo(certificate: certificate,
                                          address: self.details.ipAddress,
                                          port:self.details.port)
                return channel.eventLoop.makeSucceededFuture(info)
            } else {
                return channel.eventLoop.makeFailedFuture( AuthenticationError.CertificateError  )
            }
        }
        
    }
}










