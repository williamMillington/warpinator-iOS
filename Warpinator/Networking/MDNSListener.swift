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
}




class MDNSListener {
    
    private let DEBUG_TAG = "MDNSListener: "
    
    private let SERVICE_TYPE = "_warpinator._tcp"
    private let SERVICE_DOMAIN = ""
    
    public lazy var displayName: String = settingsManager.displayName
//    public lazy var hostname = settingsManager!.hostname
    
    var connections: [NWEndpoint : NWConnection] = [:]
    
    private var flushing = false
    
    private var certificateServer = CertificateServer()
    var listener: NWListener?
    var delegate: MDNSListenerDelegate?
    var settingsManager: SettingsManager
    
    lazy var queueLabel = "MDNSListenerQueue"
    lazy var listenerQueue = DispatchQueue(label: queueLabel, qos: .utility)
    
    
    
    init(settingsManager manager: SettingsManager) {
        settingsManager = manager
    }
    
    
    //
    // MARK: start
    func start(){
        print(DEBUG_TAG+"starting...")
        flushPublish()
    }
    
    //
    // MARK: stop
    func stop(){
        listener?.cancel()
    }
    
    
    //
    // MARK: - Service Registration
    func publishServiceAndListen(){
        
        print(DEBUG_TAG+"\tpublishing for reals...")
        
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
//        params.requiredInterface = .RadioType.WiFi.
        
        
//        params.acceptLocalOnly = true
//        params.requiredLocalEndpoint = NWEndpoint.hostPort(host:  NWEndpoint.Host("\( Utils.getIP_V4_Address() )"), port: port)
        
        
        listener = nil
//        listener = try! NWListener(using: params )
        listener = try! NWListener(using: params, on: port )
        
        listener?.stateUpdateHandler = stateDidUpdate(state:)
        listener?.newConnectionHandler = newConnectionEstablished(newConnection:)
        
        let hostname = settingsManager.hostname
        let authport = settingsManager.registrationPortNumber
        let uuid = settingsManager.uuid
        
        let properties: [String:String] = ["hostname" : "\(hostname)",
                                           "auth-port" : "\(authport)",
                                           "api-version": "2",
                                           "type" : "real"]
        
        listener?.service = NWListener.Service(name: uuid,
                                               type: SERVICE_TYPE,
                                               domain: SERVICE_DOMAIN, txtRecord:  NWTXTRecord(properties) )
        
        listener?.start(queue: listenerQueue)
    }
    
    
    
    // MARK: - flush registration
    func flushPublish(){
        
        print(DEBUG_TAG+"\tFlushing...")
        flushing = true
        
        let port = NWEndpoint.Port(rawValue: UInt16( settingsManager.transferPortNumber ) )!
        
        let params = NWParameters.udp
        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
//        params.
        
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        listener = nil
        listener = try! NWListener(using: params, on: port )
        
        listener?.newConnectionHandler = { connection in  connection.cancel() }
        listener?.stateUpdateHandler = { state in
            print("flush listener (\(state))")
            switch state {
            case .ready:
                self.listenerQueue.asyncAfter(deadline: .now() + 2) {
                    self.stop()
                    self.listenerQueue.asyncAfter(deadline: .now() + 2) {
                        self.publishServiceAndListen()
                    }
                }
            default: break
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
        case.cancelled: print(DEBUG_TAG+" cancelled")
            listener = nil
        case .ready: print(DEBUG_TAG+" ready")
            delegate?.mDNSListenerIsReady() // break 
        default: print(DEBUG_TAG+"State updated: \(state)")
        }
        
    }
    
    
    // MARK: newConnectionEstablished
    private func newConnectionEstablished(newConnection connection: NWConnection) {
        
        print(DEBUG_TAG+"new connection: \n\t\(connection)")
        
        connection.parameters.allowLocalEndpointReuse = true
        
        
//        let transferPortNum =  UInt16( settingsManager.transferPortNumber)
//        let port = NWEndpoint.Port(rawValue: transferPortNum)!
//        connection.parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host:  NWEndpoint.Host("\( Utils.getIP_V4_Address() )"),
//                                                                          port: port)
        
        
        connections[connection.endpoint] = connection
        
        connection.stateUpdateHandler = { [self] newState in
            switch newState {
//            case .waiting(let error):
//                print(self.DEBUG_TAG+"\tnew connection is waiting/restaring")
//
//                connection.stateUpdateHandler = { state in
//                    if case .ready = state {
//                        self.certificateServer.serveCertificate(to: connection) {
//                            self.connections.removeValue(forKey: connection.endpoint)
//                            connection.cancel()
//                        }
//                    }
//                }
//
//                connection.restart()
            case .ready:
//                break
                self.certificateServer.serveCertificate(to: connection) {
                    self.connections.removeValue(forKey: connection.endpoint)
                    connection.cancel()
                }
            default: print(DEBUG_TAG+"\(connection.endpoint) updated state: \(newState)")
            }
        }
//        connection.restart()
        connection.start(queue: listenerQueue)
    }
}
