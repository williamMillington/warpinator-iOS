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
    
    private let SERVICE_TYPE = "_warpinator._tcp"
    private let SERVICE_DOMAIN = ""
    
    public lazy var displayName: String = settingsManager.displayName
    
    var connections: [NWEndpoint : NWConnection] = [:]
    
    private var flushing = false
    
    private var certificateServer = CertificateServer()
    var listener: NWListener?
    weak var delegate: MDNSListenerDelegate?
    var settingsManager: SettingsManager
    
    let queueLabel = "MDNSListenerQueue"
    lazy var listenerQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    
    init(settingsManager manager: SettingsManager) {
        settingsManager = manager
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
        
        let transferPortNum =  UInt16( settingsManager.transferPortNumber)
        let port = NWEndpoint.Port(rawValue: transferPortNum)!
        
        let params = NWParameters.udp
        params.includePeerToPeer = true
        
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .wifi
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        
        listener = nil
        listener = try! NWListener(using: params, on: port )
        
        listener?.stateUpdateHandler = stateDidUpdate(state:)
        listener?.newConnectionHandler = newConnectionEstablished(newConnection:)
        listener?.serviceRegistrationUpdateHandler = { change in
            print(self.DEBUG_TAG+"service changed: \(change)")
        }
        
        
        let hostname = settingsManager.hostname
        let authport = settingsManager.registrationPortNumber
        let uuid = settingsManager.uuid
        
        let properties: [String:String] = ["hostname" : "\(hostname)",
                                           "auth-port" : "\(authport)",
                                           "api-version": "2",
                                           "type" : "real"]
        
        listener?.service = NWListener.Service(name: uuid,
                                               type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN,
                                               txtRecord:  NWTXTRecord(properties) )
        
        listener?.start(queue: listenerQueue)
    }
    
    
    //
    // MARK: flushPublish
    func flushPublish(){
        
//        print(DEBUG_TAG+"\tFlushing...")
        flushing = true
        
        let port = NWEndpoint.Port(rawValue: UInt16( settingsManager.transferPortNumber ) )!
        
        let params = NWParameters.udp
        params.includePeerToPeer = true
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
                self?.listenerQueue.asyncAfter(deadline: .now() + 2) {
                    self?.stop()
                    self?.listenerQueue.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.publishServiceAndListen()
                    }
                }
            }
        }
        
        let hostname = settingsManager.hostname
        let uuid = settingsManager.uuid
        
        let properties: [String:String] = ["hostname" : "\(hostname)",
                                           "type" : "flush"]
        
        listener?.service = NWListener.Service(name: uuid,
                                               type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN,
                                               txtRecord:  NWTXTRecord(properties) )
        listener?.start(queue: listenerQueue)
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
        
        connection.start(queue: listenerQueue)
    }
}
