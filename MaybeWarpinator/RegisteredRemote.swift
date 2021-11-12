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


//MARK: Remote Details
public struct RemoteDetails {
    public enum ConnectionStatus {
        case Connected, Disconnected
        case Canceled
        case OpeningConnection, FetchingCredentials, VerifyingDuplex
        case Error
    }
    
    lazy var DEBUG_TAG: String = "RemoteDetails (hostname: \"\(hostname)\"): "
    
    var endpoint: NWEndpoint
    
    var displayName: String = "No_DisplayName"
    var username: String = "No_Username"
    
    
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
    
    var transferOperations: [TransferOperation] = []
    
    var channel: ClientConnection?
    var warpClient: WarpClientProtocol?
    
    let group = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    var authenticationCertificate: NIOSSLCertificate?
    
    var duplexAttempts: Int = 0
    
    
    var logger = Logger(label: "warpinator.Remote", factory: StreamLogHandler.standardOutput)
    
    
    var lookupName: LookupName {
        return LookupName.with {
            $0.id =  Server.SERVER_UUID
            $0.readableName = "Warpinator iOS"
        }
    }
    
    
    init(details: RemoteDetails, certificate: NIOSSLCertificate){
        self.details = details
        authenticationCertificate = certificate
    }
    
    
    //MARK: connect
    func connect(){
        
        details.status = .OpeningConnection
        
        if warpClient == nil {
            
            logger.logLevel = .debug
            
            
//            let keepalive = ClientConnectionKeepalive(timeout: .seconds(30))
            let keepalive = ClientConnectionKeepalive(interval: .milliseconds(10_000), timeout: .milliseconds(5000),
                                                      permitWithoutCalls: true,
                                                      maximumPingsWithoutData: 0,
                                                      minimumSentPingIntervalWithoutData: .milliseconds(5000))
            let channelBuilder = ClientConnection.usingTLSBackedByNIOSSL(on: group)
                .withTLS(trustRoots: .certificates([authenticationCertificate!]) )
                .withConnectivityStateDelegate(self)
                .withBackgroundActivityLogger(logger)
                .withKeepalive(keepalive)
                
                
            
            let hostname = details.hostname
            let port = details.port
            
//            print(DEBUG_TAG+"endpoint: \(details.endpoint)")
//            if case let NWEndpoint.hostPort(host: host, port: port) = details.endpoint {
//                print(DEBUG_TAG+"endpoint is type host/port \(host):\(port) ")
//            }
//
//            if case let NWEndpoint.service(name: name, type: type, domain: domain, interface: interface) = details.endpoint {
//                print(DEBUG_TAG+"endpoint is type service \(name):\(type):\(domain):\(interface) ")
//                hostname = name
//            }
            
//            hostname = "sfjhkldafnadfhncafhacsiuewiuwiuyweuiyweriuyweriuyweriuy"
            
//            print(DEBUG_TAG+"Connecting to \(hostname):\(port)")
            
//            channel = channelBuilder.connect(host: "192.168.2.14", port: port)
            channel = channelBuilder.connect(host: hostname, port: port)
            
            if let channel = channel {
                print(self.DEBUG_TAG+"channel created")
                warpClient = WarpClient(channel: channel)
                
                details.status = .VerifyingDuplex
//                ping()
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
        
        duplexAttempts += 1
        
        print(DEBUG_TAG+"verifying duplex, attempt: \(duplexAttempts)")
        
        details.status = .VerifyingDuplex
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        var duplex: UnaryCall<LookupName, HaveDuplex> // = client.waitingForDuplex(lookupname)
        if details.api == "1" {
            print(DEBUG_TAG+"checkDuplexConnection")
            duplex = client.checkDuplexConnection(lookupName)
        } else {
            print(DEBUG_TAG+"waitingForDuplex")
            duplex = client.waitingForDuplex(lookupName)
        }
        
        
        duplex.response.whenSuccess { haveDuplex in
            
            if haveDuplex.response {
                    print(self.DEBUG_TAG+"duplex verified")
                    self.onDuplexVerified()
                } else {
                    print(self.DEBUG_TAG+"could not verify duplex")
                    
                    // 5 tries
                    guard self.duplexAttempts < 10 else {
                        print(self.DEBUG_TAG+"Duplex has failed.")
                        self.details.status = .Error
                        return }
                    print(self.DEBUG_TAG+"\ttrying again...")
                    
                    // try again in 1 second
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.verifyDuplex()
                    }
                }
        }
        
        duplex.response.whenFailure { error in
            print(self.DEBUG_TAG+"Duplex failed: \(error)")
            
            // 5 tries
            guard self.duplexAttempts < 10 else {
                print(self.DEBUG_TAG+"Duplex has failed.")
                self.details.status = .Error
                return }
            print(self.DEBUG_TAG+"\ttrying again...")
            
            // try again in 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.verifyDuplex()
            }
        }
    }
    
    
    
    // MARK: veryifyDuplex
    private func onDuplexVerified(){
        
        print(self.DEBUG_TAG+"duplex verified after \(duplexAttempts) attempts")
        
        details.status = .Connected
        
//        ping()
    }
    
    
    
    
}







//MARK: Warpinator RPC calls
extension Remote {
    
    
    // MARK: -Ping
    public func ping(){
        
//        let lookupname: LookupName = .with({
//            $0.id =  Server.SERVER_UUID
//            $0.readableName = "Warpinator iOS"
//        })
        
//        let calloptions = CallOptions(logger: logger)
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        // if we're currently transferring something, no need to ping.
        if transferOperations.count == 0 {
            
            print(self.DEBUG_TAG+"pinging")
            
            let pingResponse = client.ping(self.lookupName) //, callOptions: calloptions)
            
            pingResponse.response.whenFailure { _ in
                print(self.DEBUG_TAG+"ping failed")
                self.details.status = .Disconnected
            }
        }
        
        // ping again in 20 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.details.status == .Connected {
                self.ping()
            }
        }
    }
    
    //MARK: -updateRemoteInfo
    func updateRemoteInfo(){
        
        print(DEBUG_TAG+"Retrieving information from \(details.hostname)")
        
        guard let client = warpClient else { return }
        
        let info = client.getRemoteMachineInfo(lookupName)
        
        info.response.whenSuccess { info in
            self.details.displayName = info.displayName
            self.details.username = info.userName
        }
        info.response.whenFailure { error in
            print(self.DEBUG_TAG+"failed to retrieve machine info")
        }
        
    }
    
    
    
    
    func addTransferOperation(_ operation: TransferOperation){
        
        transferOperations.append(operation)
        operation.status = .WAITING_FOR_PERMISSION
    }
    
    
    
    func beginReceiving(for operation: TransferOperation){
        
        
        print(DEBUG_TAG+"initiating transfer operation")
        
        let operationInfo = OpInfo.with {
            $0.ident = Server.SERVER_UUID
            $0.timestamp = operation.startTime
            $0.readableName = Server.SERVER_UUID
            $0.useCompression = false
        }
        
        guard let client = warpClient else { return }
        
        
        let dataStream = client.startTransfer(operationInfo) { (chunk) in
            
            operation.readChunk(chunk)
            
        }
        
        
        dataStream.status.whenSuccess{ status in
            operation.finishReceive()
            print(self.DEBUG_TAG+"transfer finished")
        }
        
        dataStream.status.whenFailure{ error in
            print(self.DEBUG_TAG+"transfer failed: \(error)")
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
