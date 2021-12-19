//
//  MDNSListener.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-15.
//

import Foundation
import Network

import NIOSSL
import CryptoKit
import Sodium


protocol MDNSListenerDelegate {
    func mDNSListenerIsReady()
//    func mDNSListenerDidEstablishIncomingConnection(_ connection: NWConnection)
}




class MDNSListener {
    
    private let DEBUG_TAG = "MDNSListener: "
    
    var listener: NWListener?
    var delegate: MDNSListenerDelegate?
    
    private let SERVICE_TYPE = "_warpinator._tcp"
    private let SERVICE_DOMAIN = ""
    
    public var displayName: String = "iOS Device"
    
    public lazy var hostname = Server.SERVER_UUID
    
    private var certificateServer = CertificateServer()
    
    var connections: [NWEndpoint:NWConnection] = [:]
    
    private var flushing = false
    
    
    func start(){
//        do {
            // flush first
//            flushpublish()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                self.listener?.cancel()
//                self.
                publishServiceAndListen()
//            }
            
//
//        } catch {
//            print(DEBUG_TAG+"Error starting listener")
//        }
    }
    
    
    
    // MARK: - Service Registration
    func publishServiceAndListen(){
        
        flushing = false
        
        let port = NWEndpoint.Port(rawValue: UInt16( Server.transfer_port) )!
        
        let params = NWParameters.udp
        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
//            print(DEBUG_TAG+"restrict connections to v4")
            inetOptions.version = .v4
        }
                
        listener = nil
        listener = try! NWListener(using: params, on: port )
        
        listener?.stateUpdateHandler = stateDidUpdate(newState:)
        listener?.newConnectionHandler = newConnectionEstablished(newConnection:)
        
        let properties: [String:String] = ["hostname" : "\(Server.SERVER_UUID)",
//                                           "auth-port" : "\(Server.registration_port)",
//                                           "api-version": "2",
//                                           "auth-port" : "\(Server.registration_port)",
                                           "api-version": "1",
                                           "type" : "real"]
        
        listener?.service = NWListener.Service(name: Server.SERVER_UUID, type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN, txtRecord:  NWTXTRecord(properties) )
        
        listener?.start(queue: .main)
    }
    
    
    
    // MARK: - flush registration
    func flushpublish(){
        
        flushing = true
        
        let port = NWEndpoint.Port(rawValue: UInt16( Server.transfer_port ) )!
        
        let params = NWParameters.udp
        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
//            print(DEBUG_TAG+"set connection as v4")
            inetOptions.version = .v4
        }
                
        listener = nil
        listener = try! NWListener(using: params, on: port )
        
//        listener?.stateUpdateHandler = stateDidUpdate(newState:)
        listener?.newConnectionHandler = newConnectionEstablished(newConnection:)
        
        let properties: [String:String] = ["hostname" : "\(Server.SERVER_UUID)",
                                           "type" : "flush"]
        
        listener?.service = NWListener.Service(name: Server.SERVER_UUID, type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN, txtRecord:  NWTXTRecord(properties) )
        listener?.start(queue: .main)
        
    }
    
    
    // MARK: stateDidUpdate
    private func stateDidUpdate(newState: NWListener.State ) {
        
        switch newState {
        case .failed(let error):
            print(DEBUG_TAG+"failed due to error\(error)")
        case .waiting(let error):
            print(DEBUG_TAG+"waiting due to error\(error)")
        case .ready: print(DEBUG_TAG+"listener is ready")
            delegate?.mDNSListenerIsReady() // break //print(DEBUG_TAG+"listener ready")
        default: print(DEBUG_TAG+"statedidupdate: unforeseen case: \(newState)")
        }
        
    }
    
    
    // MARK: newConnectionEstablished
    private func newConnectionEstablished(newConnection connection: NWConnection) {
        
//        print(DEBUG_TAG+"new connection: \n\(connection)")
        
//        delegate?.mDNSListenerDidEstablishIncomingConnection(connection)
        
        connection.parameters.allowLocalEndpointReuse = true
        
        connections[connection.endpoint] = connection
        
        connection.stateUpdateHandler = { [self] newState in
            switch newState {
            case .ready: print(DEBUG_TAG+"established connection to \(connection.endpoint) is ready")
                self.certificateServer.serveCertificate(to: connection) {
                    self.connections.removeValue(forKey: connection.endpoint)
                    connection.cancel()
                }
            default: print(DEBUG_TAG+"\(connection.endpoint) updated state state: \(newState)")
            }
        }
        connection.start(queue: .main)
        
    }
}
