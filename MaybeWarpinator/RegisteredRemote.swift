//
//  Remote.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-03.
//

import UIKit


import NIO
import NIOSSL
import Network

import GRPC
import SwiftProtobuf


import CryptoKit
import Sodium






public struct UnregisteredRemote {
    public enum ConnectionStatus {
        case Completed, Canceled
        case InProgress
        case Suspended
        case Error
    }
    
    lazy var DEBUG_TAG: String = "REMOTE (hostname: \"\(hostname)\"): "
    
    var endpoint: NWEndpoint
    var connection: NWConnection?
    
    var serviceName: String = "No_ServiceName"
    var hostname: String = "No_Hostname"
    var uuid: String = "NO_UUID"
    var api: String = "1"
    
    var status: ConnectionStatus = .InProgress
    
    var serviceAvailable: Bool = false
    
}











public class RegisteredRemote {
    
    public enum Status {
        case Connected, Disconnected
        case Error
        case AwaitingDuplex
    }
    
    lazy var DEBUG_TAG: String = "REMOTE (hostname: \"\(hostname)\"): "
    
    public var connection: NWConnection?
    public var endpoint: NWEndpoint
    
//    public var IPAddress: NWEndpoint.Host?
//    public var port: NWEndpoint.Port?
    public var serviceName: String = "No_ServiceName"
    public var username: String = "No_Username"
    public var hostname: String = "No_Hostname"
    public var displayName: String = "No_Display_Name"
    public var uuid: String = "NO_UUID"
    public var picture: UIImage?
    public var status: Status = .Disconnected
    public var serviceAvailable: Bool = false
    
    var transfers: [Transfer] = []
    
    var channel: ClientConnection?
    var warpClient: WarpClientProtocol?
    
    let group = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    
     init(endpoint ep: NWEndpoint){
        endpoint = ep
    }
    
    
    convenience init(fromResult result: NWBrowser.Result){
        self.init(endpoint: result.endpoint)
        
        switch endpoint {
        case .service(name: let name, type: _, domain: _, interface: _):
            hostname = name
            break
        default: print("not a service nor host/port pair")
        }
        
    }
    
    
    func connect(){
        
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.allowFastOpen = true
        
        connection = NWConnection(to: endpoint, using: params)
        connection?.stateUpdateHandler = { newState in
            switch newState {
            case .ready: print(self.DEBUG_TAG+"connection ready");

                self.api_v1_fetchCertificate()
            default: print(self.DEBUG_TAG+"state updated: \(newState)")
            }
        }
        connection?.start(queue: .main)
        
    }
    
    
    // MARK: - fetch certificate API1
    private func api_v1_fetchCertificate(onComplete: @escaping ()->Void = {} ){
        print(DEBUG_TAG+"api_v1_fetching certificate")

        guard let connection = connection else {
            print(DEBUG_TAG+"connection failed"); return
        }

        
        if case let NWEndpoint.hostPort(host: host, port: port) = endpoint {
            print(DEBUG_TAG+"fetching certificate from host: \(host), port: \(port)")
        } else {
            print(DEBUG_TAG+"connection is not a host/port: \(endpoint)")
        }
        
        
        let requestString = "REQUEST"
        let requestStringBytes = requestString.bytes
        connection.send(content: requestStringBytes,
                        completion: NWConnection.SendCompletion.contentProcessed { error in

                            // RECEIVING CERTIFICATE
                            connection.receiveMessage  { (data, context, isComplete, error) in

                                if isComplete {

                                    if let concrete_data = data,
                                       let decodedCertificateData = Data(base64Encoded: concrete_data, options: .ignoreUnknownCharacters  ) {

                                        guard let certificate = Authenticator.shared.unlockCertificate(decodedCertificateData) else {
                                            print(self.DEBUG_TAG+"failed to unlock certificate"); return
                                        }
                                        
                                        self.openChannel(withCertificate: certificate)
                                        
                                    } else {  print("Failed to decode certificate")  }
                                    
                                } else {   print("No data received") }
                            }

                        })
        
        
//        certificateServer.serveCertificate(to: connection)
    }
    
    // MARK: - fetch certificate API2
    private func api_v2_fetchCertificate(onComplete: @escaping ()->Void = {} ){
        
        print(DEBUG_TAG+"api_v2_fetching certificate")
        
//        guard connection != nil else {
//            print(DEBUG_TAG+"connection failed"); return
//        }
        
//        certificateServer.serveCertificate(to: connection)
        
        print("attempting api2 request")
        
        let port = 42001
        guard hostname != "No_Hostname" else {
            print("no hostname")
            return
        }

        let channel = ClientConnection.insecure(group: group).connect(host: hostname, port: port)

        let client = WarpRegistrationClient(channel: channel)

        let request: RegRequest = .with {
            $0.hostname = Server.SERVER_UUID
            $0.ip = Utils.getIPV4Address()
        }
        let options = CallOptions(timeLimit: .timeout( .seconds(5)) )

        let registrationRequest = client.requestCertificate(request, callOptions: options)

        registrationRequest.response.whenSuccess { result in
            print(self.DEBUG_TAG+"completed ")
//            print("cert is \(result.lockedCert)")
            if let certificate = Authenticator.shared.unlockCertificate(result.lockedCert){
                self.openChannel(withCertificate: certificate)
            }
        }
        
        
        
    }
    
    
    
    
    
    // MARK: - Open Channel
    private func openChannel(withCertificate certificate: NIOSSLCertificate, onComplete: @escaping ()->Void = {} ){
        
        print(DEBUG_TAG+"opening channel to \(String(describing: connection?.endpoint))")
        
        
        let port = 42000
        
        let channelBuilder = ClientConnection.usingTLSBackedByNIOSSL(on: group)
            .withTLS(trustRoots:  .certificates([certificate])   )
//            .withKeepalive( ClientConnectionKeepalive(interval: .seconds(30) ) )
            .withConnectivityStateDelegate(self)
        
        guard hostname != "" else {
            print("no hostname")
            return
        }
        
        channel = channelBuilder.connect(host: hostname, port: port)
        
        if let channel = channel {
            warpClient = WarpClient(channel: channel)
        } else {
            print("channel setup failed")
        }
        
//        print(DEBUG_TAG+"client connection: \(warpClient.debugDescription)")
        
        waitForDuplex()
//        onComplete()
        
    }
    
    
    private func waitForDuplex(onComplete: @escaping ()->Void = {} ){
        
        print(DEBUG_TAG+"waiting for duplex...")
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        let lookupname: LookupName = .with({
            $0.id =  Server.SERVER_UUID
            $0.readableName = "Warpinator iOS"
        })
        
        let duplex = client.checkDuplexConnection(lookupname)
        
        duplex.response.whenComplete { result in
            print("waitForDuplex: result is \(result)")
        }
        
        print("duplex is \(duplex.response)")
        
    }
}




extension RegisteredRemote: ConnectivityStateDelegate {
    public func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
        print(DEBUG_TAG+"channel state has moved from \(oldState) to \(newState)")
        switch newState {
        case .ready: print(DEBUG_TAG+"channel ready")
            waitForDuplex()
        default: break
        }
        
    }
}
