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
    func mDNSListenerDidEstablishIncomingConnection(_ connection: NWConnection)
}




class MDNSListener {
    
    private let DEBUG_TAG = "MDNSListener: "
    
    var listener: NWListener?
    var delegate: MDNSListenerDelegate?
    
    private let SERVICE_TYPE = "_warpinator._tcp"
    private let SERVICE_DOMAIN = ""
    
//    public var transfer_port: Int = 42000
//    public var registration_port: Int = 42001
    
    public var uuid: String = "WarpinatorIOS"
    public var displayName: String = "iOS Device"
    
    public lazy var hostname = uuid
    
    private var certificateServer = CertificateServer()
    
    var connections: [NWEndpoint:NWConnection] = [:]
    
    private var flushing = false
    
    
    func start(){
//        do {
            // flush first
//            flushpublish()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                self.listener?.cancel()
                self.publishServiceAndListen()
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
        listener = nil
        listener = try! NWListener(using: .udp, on: port )
        
        listener?.stateUpdateHandler = stateDidUpdate(newState:)
        listener?.newConnectionHandler = newConnectionEstablished(newConnection:)
        
        let properties: [String:String] = ["hostname" : "\(uuid)",
                                           "auth-port" : "\(Server.registration_port)",
                                           "api-version": "2",
                                           "type" : "real"]
        
        listener?.service = NWListener.Service(name: uuid, type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN, txtRecord:  NWTXTRecord(properties) )
        
        listener?.start(queue: .main)
    }
    
    
    
    // MARK: - flush registration
    func flushpublish(){
        
        flushing = true
        
        let port = NWEndpoint.Port(rawValue: UInt16( Server.transfer_port ) )!
        listener = try! NWListener(using: .udp, on: port )
        
        listener?.stateUpdateHandler = stateDidUpdate(newState:)
        listener?.newConnectionHandler = newConnectionEstablished(newConnection:)
        
        
        let properties: [String:String] = ["hostname" : "\(uuid)",
                                           "type" : "flush"]
        
        listener?.service = NWListener.Service(name: uuid, type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN, txtRecord:  NWTXTRecord(properties) )
        listener?.start(queue: .main)
        
    }
    
    
    
    
    
    
    private func stateDidUpdate(newState: NWListener.State ) {
        
        switch newState {
        case .failed(_): break
        case .ready: //print(DEBUG_TAG+"listener is ready!")
            delegate?.mDNSListenerIsReady() // break //print(DEBUG_TAG+"listener ready")
        default: print(DEBUG_TAG+"statedidupdate: unforeseen case: \(newState)")
        }
        
    }
    
    
    private func newConnectionEstablished(newConnection connection: NWConnection) {
        
//        print(DEBUG_TAG+"new connection: \n\(connection)")
        
        connections[connection.endpoint] = connection
        
        connection.stateUpdateHandler = { [self] newState in
//            print("state updated")
            switch newState {
            case.ready: print(DEBUG_TAG+"established connection is ready")
                certificateServer.serveCertificate(to: connection)
            default: print(DEBUG_TAG+"new connection \(connection.endpoint), state: \(newState)")
            }
        }
        
    }
}
