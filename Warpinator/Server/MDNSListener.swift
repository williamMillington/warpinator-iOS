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
    
    var listener: NWListener
    weak var delegate: MDNSListenerDelegate?
//    let queueLabel = "MDNSListenerQueue"
//    lazy var listenerQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    
    init() {
        
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
        
        
//        listener = nil
        listener = try! NWListener(using: params, on: port )
        
        listener.stateUpdateHandler = stateDidUpdate(state:)
        
        pauseAcceptingConnections()
//        listener.newConnectionHandler = newConnectionEstablished(newConnection:)
        startListening()
    }
    
    
    //
    // MARK: startListening
    func startListening(){
        
        guard listener.state == .setup else {
            print(DEBUG_TAG+"\tlistener is not in setup state (\(listener.state))")
            return
        }
        listener.start(queue: .global() )
//        flushPublish()
    }
    
    
    //
    // MARK stop
    func stopListening(){
        listener.cancel()
    }
    
    
    func pauseAcceptingConnections() {
        listener.newConnectionHandler = { connection in connection.cancel() }
    }
    
    func beginAcceptingConnections() {
        listener.newConnectionHandler = newConnectionEstablished(newConnection:)
    }
    
    func refreshService(){
        
        flushPublish()
        
    }
    
    
    //
    // MARK: publishService
    func publishService(){
        
        print(DEBUG_TAG+"\tpublishing for reals...")
        
        guard listener.state == .ready else {
            print(DEBUG_TAG+"\tlistener is not ready (\(listener.state))")
            return
        }
        
        beginAcceptingConnections()
        
        flushing = false
        
        let hostname = SettingsManager.shared.hostname
        let authport = SettingsManager.shared.registrationPortNumber
        let uuid = SettingsManager.shared.uuid
        
        let properties: [String:String] = ["hostname" : "\(hostname)",
                                           "auth-port" : "\(authport)",
                                           "api-version": "2",
                                           "type" : "real"]
        
        
        listener.service = NWListener.Service(name: uuid,
                                               type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN,
                                               txtRecord:  NWTXTRecord(properties) )
        
        
        delegate?.mDNSListenerIsReady()
    }
    
    
    //
    // MARK: flushPublish
    func flushPublish(){

        
        guard listener.state == .ready  else {
            print(DEBUG_TAG+"\tlistener is not ready (\(listener.state))")
            return
        }
        
        
        pauseAcceptingConnections()
        
        print(DEBUG_TAG+"\tFlushing...")
        flushing = true

        
        let hostname = SettingsManager.shared.hostname
        let uuid = SettingsManager.shared.uuid

        let properties: [String:String] = ["hostname" : "\(hostname)",
                                           "type" : "flush"]
        
        listener.service = NWListener.Service(name: uuid,
                                              type: SERVICE_TYPE,
                                              domain: SERVICE_DOMAIN,
                                              txtRecord:  NWTXTRecord(properties) )
        
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.listener.service = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.publishService()
            }
        }
    }
    
    
    // MARK: stateDidUpdate
    private func stateDidUpdate(state: NWListener.State ) {
        
        print(DEBUG_TAG+" state updated -> \(state)")
        
        
//        switch state {
//        case .cancelled: print(DEBUG_TAG+" cancelled")
////            listener = nil
//        case .ready: print(DEBUG_TAG+" ready")
//            delegate?.mDNSListenerIsReady() // break
//        default: print(DEBUG_TAG+"State updated: \(state)")
//        }
        
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
