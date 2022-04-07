//
//  MDNSListener.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-15.
//

import Foundation
import Network

import NIOSSL
import CryptoKit
import Sodium


protocol MDNSListenerDelegate: AnyObject {
    func mDNSListenerIsReady()
}

final class MDNSListener {
    
    private let DEBUG_TAG = "MDNSListener: "
    
     let SERVICE_TYPE = "_warpinator._tcp"
     let SERVICE_DOMAIN = ""
    
    var displayName: String = SettingsManager.shared.displayName
    
    var connections: [NWEndpoint : NWConnection] = [:]
    
    var flushing = false
    
    var certificateServer = CertificateServer()
    
    var listener: NWListener?
    weak var delegate: MDNSListenerDelegate?
//    let queueLabel = "MDNSListenerQueue"
//    lazy var listenerQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    
    init() {
    }
    
    
    //
    // MARK: start
    func start(){
//        print(DEBUG_TAG+"starting...")
        flushPublish()
    }
    
    
    //
    // MARK: stop
    func stop(){
        listener?.cancel()
    }
    
    
    //
    // MARK: publishServiceAndListen
    func publishServiceAndListen(){
        
//        print(DEBUG_TAG+"\tpublishing for reals...")
        
        flushing = false
        
        let transferPortNum =  UInt16( SettingsManager.shared.transferPortNumber)
        let port = NWEndpoint.Port(rawValue: transferPortNum)!
        
        let params = NWParameters.udp
//        params.includePeerToPeer = true
        
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .wifi
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        
        listener = nil
        listener = try! NWListener(using: params, on: port )
        
        listener?.stateUpdateHandler = stateDidUpdate(state:)
        listener?.newConnectionHandler = newConnectionEstablished(newConnection:)
        
//        listener?.serviceRegistrationUpdateHandler = { change in
//
//            if case let .add(endpoint) = change {
//
//                print(self.DEBUG_TAG+"service endpoint added: \(endpoint)")
//
//                if case let .hostPort(host: host, port: port) = endpoint {
//                    print(self.DEBUG_TAG+"host: \(host)")
//                    print(self.DEBUG_TAG+"port: \(port)")
//                }
//            }
//
//            print(self.DEBUG_TAG+"service changed: \(change)")
//        }
        
        
        let hostname = SettingsManager.shared.hostname
        let authport = SettingsManager.shared.registrationPortNumber
        let uuid = SettingsManager.shared.uuid
        
        let properties: [String:String] = ["hostname" : "\(hostname)",
                                           "auth-port" : "\(authport)",
                                           "api-version": "2",
                                           "type" : "real"]
        
        listener?.service = NWListener.Service(name: uuid,
                                               type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN,
                                               txtRecord:  NWTXTRecord(properties) )
        
        listener?.start(queue: .main)
    }
    
    
    //
    // MARK: flushPublish
    func flushPublish(){
        
//        print(DEBUG_TAG+"\tFlushing...")
        flushing = true
        
        let port = NWEndpoint.Port(rawValue: UInt16( SettingsManager.shared.transferPortNumber ) )!
        
        let params = NWParameters.udp
//        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
        
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        listener = nil
        listener = try! NWListener(using: params, on: port )
        
        listener?.newConnectionHandler = { connection in  connection.cancel() }
        listener?.stateUpdateHandler = { [weak self] state in
            print("flushing listener (\(state))")
            
            // wait 2 seconds and stop
            // wait 2 more seconds re-publish for realsies
            if case .ready = state {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.stop()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.publishServiceAndListen()
                    }
                }
            }
        }
        
        let hostname = SettingsManager.shared.hostname
        let uuid = SettingsManager.shared.uuid
        
        let properties: [String:String] = ["hostname" : "\(hostname)",
                                           "type" : "flush"]
        
        listener?.service = NWListener.Service(name: uuid,
                                               type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN,
                                               txtRecord:  NWTXTRecord(properties) )
        listener?.start(queue: .main)
    }
    
    
    // MARK: stateDidUpdate
    private func stateDidUpdate(state: NWListener.State ) {
        
        switch state {
        case .cancelled: print(DEBUG_TAG+" cancelled")
            listener = nil
        case .ready: print(DEBUG_TAG+" ready")
            delegate?.mDNSListenerIsReady() // break 
        default: print(DEBUG_TAG+"State updated: \(state)")
        }
        
    }
    
    
    // MARK: newConnectionEstablished
    private func newConnectionEstablished(newConnection connection: NWConnection) {
        
        print(DEBUG_TAG+"new connection: \n\t\(connection)")
        
        // TODO: I feel like the meat of this function belongs in CertificateServer itself.
        // ie. Receive new connection -> pass it straight along to certificateServer
        
        connection.parameters.allowLocalEndpointReuse = true
        
        connections[connection.endpoint] = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            
            print((self?.DEBUG_TAG ?? "(MDNSListener is nil): ")+"\(connection.endpoint) updated state: \(state)")
            
            // serve certificate as soon as connection is ready
            if case .ready = state {
                self?.certificateServer.serveCertificate(to: connection) { [weak self] in
                    self?.connections.removeValue(forKey: connection.endpoint)
                    connection.cancel()
                }
            }
        }
        
        connection.start(queue: .main)
    }
}
