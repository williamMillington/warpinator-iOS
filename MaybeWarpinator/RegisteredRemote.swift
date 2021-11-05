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





// Remote Details
public struct RemoteDetails {
    public enum ConnectionStatus {
        case Connected, Disconnected
        case Canceled
        case InProgress
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
    
    var status: ConnectionStatus = .InProgress
    
    var serviceAvailable: Bool = false
    
}





// MARK: - Registered Remote
public class RegisteredRemote {
    
    lazy var DEBUG_TAG: String = "REMOTE (hostname: \"\(hostname)\"): "
    
    var details: RemoteDetails
    
    public var serviceName: String = "No_ServiceName"
    public var username: String = "No_Username"
    public var hostname: String = "No_Hostname"
    public var displayName: String = "No_Display_Name"
    public var uuid: String = "NO_UUID"
    public var picture: UIImage?
    public var serviceAvailable: Bool = false
    
    var transfers: [Transfer] = []
    
    var channel: ClientConnection?
    var warpClient: WarpClientProtocol?
    
    let group = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    
    init(details: RemoteDetails){
//        self.init(endpoint: details.endpoint)
        self.details = details
    }
    
    convenience init(details: RemoteDetails, client: WarpClient){
        self.init(details: details)
        warpClient = client 
    }
    
//    convenience init(fromResult result: NWBrowser.Result){
//        self.init(endpoint: result.endpoint)
//
//        switch endpoint {
//        case .service(name: let name, type: _, domain: _, interface: _):
//            hostname = name
//            break
//        default: print("not a service nor host/port pair")
//        }
//
//    }
    
    
    func connect(){
        
        
//        let params = NWParameters.udp
//        params.allowLocalEndpointReuse = true
//        params.allowFastOpen = true
//
//        connection = NWConnection(to: endpoint, using: params)
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
    
    
    // MARK: - Open Channel
    private func openChannel(withCertificate certificate: NIOSSLCertificate, onComplete: @escaping ()->Void = {} ){
        
//        print(DEBUG_TAG+"opening channel to \(String(describing: connection?.endpoint))")
        
        
        let hostname = details.hostname
        
        
        let port = details.port // 42000
        
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
