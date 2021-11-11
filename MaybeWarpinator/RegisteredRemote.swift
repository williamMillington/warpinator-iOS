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


import Logging


// Remote Details
public struct RemoteDetails {
    public enum ConnectionStatus {
        case Connected, Disconnected
        case Canceled
        case OpeningConnection, FetchingCredentials, VerifyingDuplex
        case Error
    }
    
    lazy var DEBUG_TAG: String = "RemoteDetails (hostname: \"\(hostname)\"): "
    
    var endpoint: NWEndpoint
    
    var serviceName: String = "No_ServiceName"
    var hostname: String = "No_Hostname"
    var port: Int = 0 //"No_Port"
    var authPort: Int = 0 //"No_Auth_Port"
    
    var uuid: String = "NO_UUID"
    var api: String = "1"
    
    var status: ConnectionStatus = .Disconnected
    
    var serviceAvailable: Bool = false
    
}





// MARK: - Registered Remote
public class Remote {
    
    lazy var DEBUG_TAG: String = "REMOTE (hostname: \"\(details.hostname)\"): "
    
    var details: RemoteDetails
    
    public var displayName: String = "No_Display_Name"
    public var picture: UIImage?
    
    var transfers: [Transfer] = []
    
    var channel: ClientConnection?
    var warpClient: WarpClientProtocol?
    
    let group = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    
    var authenticationCertificate: NIOSSLCertificate?
    
    var duplexAttempts: Int = 0
    
    
    var logger = Logger(label: "warpinator.Remote", factory: StreamLogHandler.standardOutput)
    
    
    init(details: RemoteDetails, certificate: NIOSSLCertificate){
        self.details = details
        authenticationCertificate = certificate
    }
    
    
    //MARK: connect
    func connect(){
        
        
        details.status = .OpeningConnection
        
        if warpClient == nil {
            
            logger.logLevel = .critical
            
            
//            let keepalive = ClientConnectionKeepalive(interval: .milliseconds(10000), timeout: .milliseconds(10000) )
            let channelBuilder = ClientConnection.usingTLSBackedByNIOSSL(on: group)
                .withTLS(trustRoots: .certificates([authenticationCertificate!]) )
                .withConnectivityStateDelegate(self)
                .withBackgroundActivityLogger(logger)
                
//                .withKeepalive(keepalive)
                
                
//                .withTLS(certificateVerification: .noHostnameVerification)
                
            
            var hostname = details.hostname
            let port = details.port
            
            print(DEBUG_TAG+"endpoint: \(details.endpoint)")
            if case let NWEndpoint.hostPort(host: host, port: port) = details.endpoint {
                print(DEBUG_TAG+"endpoint is type host/port \(host):\(port) ")
            }
            
            if case let NWEndpoint.service(name: name, type: type, domain: domain, interface: interface) = details.endpoint {
                print(DEBUG_TAG+"endpoint is type service \(name):\(type):\(domain):\(interface) ")
                hostname = name
            }
            
            hostname = "sfjhkldafnadfhncafhacsiuewiuwiuyweuiyweriuyweriuyweriuy"
            
            print(DEBUG_TAG+"Connecting to \(hostname):\(port)")
            
            channel = channelBuilder.connect(host: "192.168.2.14", port: port)
            
            if let channel = channel {
                print(self.DEBUG_TAG+"channel created")
                warpClient = WarpClient(channel: channel)
                
                details.status = .VerifyingDuplex
                ping()
                verifyDuplex() //.Connected
            } else {
                details.status = .Error
            }
        }
    }
    
    
    // MARK Open Channel
    private func openChannel(withCertificate certificate: NIOSSLCertificate, onComplete: @escaping ()->Void = {} ){
        
    }
    
    
    
    // MARK: veryifyDuplex
    private func verifyDuplex(onComplete: @escaping ()->Void = {} ){
        
        print(DEBUG_TAG+"verifying duplex...")
        
        details.status = .VerifyingDuplex
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        
        let lookupname: LookupName = .with({
            $0.id =  Server.SERVER_UUID
            $0.readableName = "Warpinator iOS"
        })
        
        
        var duplex: UnaryCall<LookupName, HaveDuplex> // = client.waitingForDuplex(lookupname)
        if details.api == "1" {
            print(DEBUG_TAG+"checkDuplexConnection")
            duplex = client.checkDuplexConnection(lookupname)
        } else {
            print(DEBUG_TAG+"waitingForDuplex")
            duplex = client.waitingForDuplex(lookupname)
        }
        
        
//        print(DEBUG_TAG+"time limit is \(duplex.options.timeLimit)")
        let _ = duplex.response.always { result in
            print(self.DEBUG_TAG+"Well hey fucking something happened")
        }
        
        duplex.status.always{ status in
            print(self.DEBUG_TAG+"SOMething shappned muthafuckers")
        }
        
        
        duplex.response.whenComplete { result in
            
            print(self.DEBUG_TAG+"Duplex response received")
            
            if let response = try? result.get().response {
                
                if response {
                    print(self.DEBUG_TAG+"duplex verified")
                    self.onDuplexVerified()
                } else {
                    print(self.DEBUG_TAG+"could not verify duplex")
                    
                    // 3 tries
                    guard self.duplexAttempts < 10 else {  return }
                    print(self.DEBUG_TAG+"\ttrying again...")
                    
                    // try again in 1 second
                    self.duplexAttempts += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.verifyDuplex()
                    }
                    
                }
            } else {
                print(self.DEBUG_TAG+"Error receiving duplex response")
            }
        }
        
        
        duplex.response.whenFailure { error in
            
            print(self.DEBUG_TAG+"Duplex failed: \(error)")
            
        }
    }
    
    
    
    // MARK: veryifyDuplex
    private func onDuplexVerified(){
        
        print(self.DEBUG_TAG+"duplex verified after \(duplexAttempts) attempts")
        
        details.status = .Connected
        
        ping()
        
    }
    
    
    // MARK: Ping
    public func ping(){
        
        let lookupname: LookupName = .with({
            $0.id =  Server.SERVER_UUID
            $0.readableName = "Warpinator iOS"
        })
        
        let calloptions = CallOptions(logger: logger)
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        // if we're currently transferring something, no need to ping.
        // But still schedule another ping
        if transfers.count == 0 {
            
            print(self.DEBUG_TAG+"pinging")
            
            let pingResponse = client.ping(lookupname, callOptions: calloptions)
            
            pingResponse.response.whenFailure { _ in
                print(self.DEBUG_TAG+"ping failed")
                self.details.status = .Disconnected
            }
            
            
        }
        
        // ping again in 20 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.details.status == .Connected {
                self.ping()
            }
        }
    }
    
    
    
}




extension Remote: ConnectivityStateDelegate {
    public func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
        print(DEBUG_TAG+"channel state has moved from \(oldState) to \(newState)")
        switch newState {
//        case .connecting: ping()
        case .ready: print(DEBUG_TAG+"channel ready")
        default: break
        }
        
    }
}
