//
//  MDNSListener.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-15.
//

import Foundation

import NIO

import Network

import NIOSSL
import CryptoKit
import Sodium


protocol MDNSListenerDelegate: AnyObject {
    func mDNSListenerIsReady()
}

final class MDNSListener {
    
    enum ServiceError: Error {
        case CANCELLED
        case ALREADY_RUNNING
        case UNKNOWN_SERVICE
    }
    
    private let DEBUG_TAG = "MDNSListener: "
    
     let SERVICE_TYPE = "_warpinator._tcp"
     let SERVICE_DOMAIN = ""
    
    
    weak var delegate: MDNSListenerDelegate?
    
    var connections: [NWEndpoint : NWConnection] = [:]
    
    var flushing = false
    
    var certificateServer = CertificateServer()
    
    var port: NWEndpoint.Port {
        let transferPortNum =  UInt16( SettingsManager.shared.transferPortNumber)
        return NWEndpoint.Port(rawValue: transferPortNum)!
    }
    
    
    lazy var listener: NWListener = createListener()
    var currentState: NWListener.State = .setup
    
    var eventloopGroup: EventLoopGroup
    
    let queueLabel = "MDNSListenerQueue"
    lazy var listenerQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    
    init(withEventloopGroup group: EventLoopGroup) {
        eventloopGroup = group
    }
    
    
    
    private func createListener() -> NWListener {
        
//        print(DEBUG_TAG+"\t Creating listener")
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .wifi
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        return try! NWListener(using: params, on: port )
    }
    
    
    
    //
    // MARK: start
    func start() -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+" starting up listener")
        
        let promise = eventloopGroup.next().makePromise(of: Void.self)
        
        
        /* apparently iOS 13 has a bug (whaaaaaaaaaaaat? no, so crazy...)
         where listener.state isn't actually accessible, and somebody forgot to put a property wrapper on it,
         so we only find out at runtime, not compile time.
        */
        switch currentState {
        case .ready: // if we already have an NWListener, and it's 'ready', we're done
            
            // make sure we 'succeed' AFTER we return the result
            defer {  promise.succeed( Void() )   }
            
            return promise.futureResult
        case .setup: break // avoid creating a new listener if the one we have is still good
        default:
            listener = createListener()
        }
        
        configure(promise, toSucceedForState: .ready)
        stopListening() // listener requires a connection handler, this just sets it (to one that rejects everything)
        
        
        listener.start(queue: listenerQueue )
        
//        print(DEBUG_TAG+"returning start promise")
        return promise.futureResult
    }
    
    
    
    //
    // MARK: stop
    func stop() -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+" stopping... (current state:  \(listener.state) )")
        
        let promise = eventloopGroup.next().makePromise(of: Void.self)
        
        switch currentState {
        case .cancelled, .failed(_), .setup: // 'succeed' the promise if listener is already stopped/not-started
            promise.succeed( Void() )
        default:
            configure(promise, toSucceedForState: .cancelled)
            stopListening()
            listener.cancel()
        }
        
        return promise.futureResult.flatMapError { error in
            // catch the failed case –which, in this circumstance, is a success– and return it as such
            return self.eventloopGroup.next().makeSucceededVoidFuture()
        }
    }
    
    
    //
    // Allows a promise to be configured to fire for a number of different states
    //      - NOTE: .failure() will ALWAYS fail the promise
    // MARK: configurePromise
    private func configure(_ promise: EventLoopPromise<Void>,
                           toSucceedForState state: NWListener.State) {
        
        
        listener.stateUpdateHandler = { updatedState in
            
//            print(self.DEBUG_TAG+"\t\t\t listener update to \(updatedState) while waiting for \(state)")
            self.currentState = updatedState
            // we have to be careful not to let a promise go unfullfilled
            switch updatedState {
            case .failed(let error):
                promise.fail(error)
                return
            case .cancelled:
                
                // fail if caller was waiting for a different state, because –once cancelled–
                // those states (ex. .ready, .watiting )  can never be reached again and we just
                // create a new listener (which will leave the promise hanging)
                if state != .cancelled {
                    promise.fail(  ServiceError.CANCELLED  )
                    return
                }
                
                // proceed to default case
                fallthrough
                
            default:
                
                // if caller wanted to be alerted when this state was reached
                if state == updatedState {
                    promise.succeed( Void() )
                    self.listener.stateUpdateHandler = self.stateDidUpdate(state: )
                }
            }
            
        }
    }
    
    
    
    //
    // MARK: start listening
    func startListening(){
//        print(DEBUG_TAG+"start listening")
        listener.newConnectionHandler = newConnectionEstablished(newConnection:)
    }
    
    
    //
    // MARK: stop listening
    func stopListening(){
//        print(DEBUG_TAG+"stop listening")
        listener.newConnectionHandler = { $0.cancel() }
    }
    
    
    //
    // MARK: publishService
    func publishService(){
        
        print(DEBUG_TAG+"\tpublishing service...")
        
        guard currentState == .ready else {
//            print(DEBUG_TAG+"\t\tlistener is not ready (\(currentState))")
            return
        }
        
        stopListening()
        listener.stateUpdateHandler = stateDidUpdate(state:)
        
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
        
        print(DEBUG_TAG+"\tFlushing...")
        
        guard currentState == .ready  else {
//            print(DEBUG_TAG+"\t\tlistener is not ready (\(listener.state))")
            return
        }
        
        stopListening()
        listener.stateUpdateHandler = stateDidUpdate(state:)
        
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
        
//        print(DEBUG_TAG+" state updated -> \(state)")
        currentState = state
//        switch state {
//        case .cancelled:
//            print(DEBUG_TAG+"\t\t cancelled")
//        case .failed(let error):
//            print(DEBUG_TAG+"\t\t listener failed; error: \(error)")
//
//        default: break //print(DEBUG_TAG+"State updated: \(state)")
//        }
    }
    
    
    
    // MARK: newConnectionEstablished
    private func newConnectionEstablished(newConnection connection: NWConnection) {
        
        
        // TODO: I feel like the meat of this function belongs in CertificateServer itself.
        // ie. Receive new connection -> pass it straight along to certificateServer
        
        connection.parameters.allowLocalEndpointReuse = true
        
        connections[connection.endpoint] = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            
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
