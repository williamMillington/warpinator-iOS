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
    
    
    var parameters: NWParameters {
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .wifi
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        return params
    }
    
    var port: NWEndpoint.Port {
        let transferPortNum =  UInt16( SettingsManager.shared.transferPortNumber)
        return NWEndpoint.Port(rawValue: transferPortNum)!
    }
    
    
    lazy var listener: NWListener = createListener()
    
    
    weak var delegate: MDNSListenerDelegate?
    
    let queueLabel = "MDNSListenerQueue"
    lazy var listenerQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    
    init() {

        listener.stateUpdateHandler = stateDidUpdate(state:)
        stopListening()
        listener.start(queue: listenerQueue )
    }
    
    
    private func createListener() -> NWListener {
        
        print(DEBUG_TAG+"\t Creating listener")
        
        listener = try! NWListener(using: parameters, on: port )
        
        return listener
    }
    
    
    //
    // MARK: startListening
    func startListening(){
        listener.newConnectionHandler = newConnectionEstablished(newConnection:)
    }
    
    
    //
    // MARK stop
    func stopListening(){
        
        listener.newConnectionHandler = { $0.cancel() }
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
        
        stopListening()
        
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
        
        
        startListening()
        
        delegate?.mDNSListenerIsReady()
    }
    
    
    //
    // MARK: flushPublish
    func flushPublish(){

        
        guard listener.state == .ready  else {
            print(DEBUG_TAG+"\tlistener is not ready (\(listener.state))")
            return
        }
        
        
        stopListening()
        
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
    
    func removeService() {
        listener.service = nil
    }
    
    
    
    //
    // MARK: stateDidUpdate
    private func stateDidUpdate(state: NWListener.State ) {
        
        print(DEBUG_TAG+" state updated -> \(state)")
        
        switch state {
        case .cancelled:  print(DEBUG_TAG+" cancelled")
        
        case .failed(let error):  print(DEBUG_TAG+"listener failed; error: \(error)")
            
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                restartListener()
                return
                
            } else {    print(DEBUG_TAG+"\t\tstopping")     }
            
            listener.cancel()
            
        default: break //print(DEBUG_TAG+"State updated: \(state)")
        }
    }
    
    
    private func restartStateHandler(state: NWListener.State ) {
        
        print(DEBUG_TAG+" restart state changed (\(state))")
        
        switch state {
            
        case .cancelled:
            
            listener = createListener()
            listener.stateUpdateHandler = restartStateHandler(state:)
            stopListening()
            listener.start(queue: listenerQueue)
        
        case .ready:
            listener.stateUpdateHandler = stateDidUpdate(state:)
            flushPublish()
            
        case .failed(let error) :
            
            print(DEBUG_TAG+"listener failed; error: \(error)")
            
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                
                listenerQueue.asyncAfter(deadline: .now() + 1) {
                    self.restartListener()
                }
                return
                
            } else {
                print(DEBUG_TAG+"\t\tstopping")
            }
            
            listener.cancel()
            
        default: print(DEBUG_TAG+" state: \(state)")
            
        }
    }
    
    
    
    //
    // MARK: restart
    func restartListener(){
        
        print(DEBUG_TAG+"\t\t restarting")
        
        listener.stateUpdateHandler = restartStateHandler(state: )
        
        listener.cancel()
    }
    
    
    
    // MARK: newConnectionEstablished
    private func newConnectionEstablished(newConnection connection: NWConnection) {
        
//        print(DEBUG_TAG+"new connection: \n\t\(connection)")
        
        // TODO: I feel like the meat of this function belongs in CertificateServer itself.
        // ie. Receive new connection -> pass it straight along to certificateServer
        
        connection.parameters.allowLocalEndpointReuse = true
        
        connections[connection.endpoint] = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            
//            print((self?.DEBUG_TAG ?? "(MDNSListener is nil): ")+"\(connection.endpoint) updated state: \(state)")
            
            switch state {
            case .ready:
                
                // serve certificate as soon as connection is ready
                self?.certificateServer.serveCertificate(to: connection) {
                    connection.cancel() // cancel when finished
                }
            case .cancelled, .failed(_):
                
                // remove connection when cancelled or failed
                self?.connections.removeValue(forKey: connection.endpoint)
            default: break
                
            }
            
        }
        
        connection.start(queue: .main)
    }
}
