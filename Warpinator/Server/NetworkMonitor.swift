//
//  NetworkMonitor.swift
//  Warpinator
//
//  Created by William Millington on 2022-04-15.
//

import Foundation
import Network
import NIOCore


protocol NetworkDelegate {
    func didGainLocalNetworkConnectivity()
    func didLoseLocalNetworkConnectivity()
}




enum MdnsState {
    case ready
    case setup
    case waiting( NWError )
    case cancelled
    case failure( NWError )
}


class NetworkMonitor {

    enum ServiceError: Swift.Error {
        case LOCAL_NETWORK_PERMISSION_DENIED
        case NO_CONNECTIVITY
    }
    
    static let DEBUG_TAG : String = "NetworkMonitor (statics): "
    let DEBUG_TAG : String = "NetworkMonitor: "
    
    let delegate: NetworkDelegate
    
    let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    let queue: DispatchQueue = DispatchQueue(label: "NetworkMonitor")
    
    let eventloopGroup: EventLoopGroup
    
    init(withEventloopGroup group: EventLoopGroup, delegate: NetworkDelegate){
        
        eventloopGroup = group
        
        self.delegate = delegate
        
        monitor.pathUpdateHandler = updateHandler(path:)
        monitor.start(queue: queue)
        
        // triggers nwpathmonitor to start.
        // If we wait until the first REAL check, it will return false
        // while nwpathmonitor starts up
//        let _ = wifiIsAvailable
    }
    
    
    
    //
    //
    var wifiIsAvailable: Bool {
        print(DEBUG_TAG+"checking availability of (\(monitor.currentPath))")
        print(DEBUG_TAG+"checking wifi availablility (\(monitor.currentPath.status))")
        switch monitor.currentPath.status {
        case .satisfied: return true
        default: return false
            
        }
    }
    
    
    
    // Similar to the start methods in Server and RegistrationServer,
    // this eventloop promise will restart itself upon a failure to confirm wifi connectivity
    // until a set number of attempts have been made
    var attempts: Int = 0
    let ATTEMPT_LIMIT: Int = 10 // 10 attempts, 1 second apart
    
    func waitForWifiAvailable()  -> EventLoopFuture<Void> {
        
        let promise = eventloopGroup.next().makePromise(of: Void.self)
        
        // fulfill promise.futureResult AFTER we've returned it
        defer {
            if wifiIsAvailable {
                promise.succeed( Void() )
            } else {
                promise.fail( NetworkMonitor.ServiceError.NO_CONNECTIVITY )
            }
        }
        
        return promise.futureResult
        
            // try again on error
            .flatMapError { error in
                
                print(self.DEBUG_TAG+" error checking wifi: \(error)")
                
                // Check if we've passed our attempt limit
                guard self.attempts < self.ATTEMPT_LIMIT else {
                    return self.eventloopGroup.next().makeFailedFuture( ServiceError.NO_CONNECTIVITY )
                }
                
                // try again in 2 seconds
                self.attempts += 1
                return self.eventloopGroup.next().flatScheduleTask(in: .seconds(1)) {
                    self.waitForWifiAvailable()
                }.futureResult
                
            }
    }
    
    
    
    func updateHandler(path: NWPath) {
        
        print(self.DEBUG_TAG+"path \(path) status is \(path.status)")
        
        switch path.status {
        case .satisfied: delegate.didGainLocalNetworkConnectivity()
        case .unsatisfied: delegate.didLoseLocalNetworkConnectivity()
//            print(DEBUG_TAG+"monitor.updateHandler \(monitor) -> ")
        default: break
        }
        
    }
    
    
    
    // MARK: waitForMDNSPermission
    // Apple has decided I don't deserve to know if I have permission to connect to mDNS,
    // and that is makes more sense for me to waste time and system resources attempting
    // to connect regardless of where or not I can.  So, here we are.
    
    var browser: NWBrowser! //declare here so we don't lose them
    var listener: NWListener!
    
    func waitForMDNSPermission() -> EventLoopFuture<Void> {
        
        let promise = eventloopGroup.next().makePromise(of: Void.self)
        
        let parameters = NWParameters.udp
        listener = try! NWListener(using: parameters)
        
        listener.serviceRegistrationUpdateHandler = { change in
            
            // if we've published successfully then we know we've got permission
            if case .add(let endpoint) = change {
                
                // make sure it's ourselves we've discovered
                if case  .service(name: let endpointName, type:_, domain:_, interface:_) = endpoint,
                   endpointName == SettingsManager.shared.uuid {
                    promise.succeed( Void() )
                    self.listener.cancel()
                    self.browser.cancel()
                }
            }
        }
        listener.stateUpdateHandler = { _ in } // these have to be assigned, but don't do anything in this scenario
        listener.newConnectionHandler = { _ in }
        
        
        let SERVICE_TYPE = "_warpinator._tcp."
        let SERVICE_DOMAIN = ""
        
        listener.service = NWListener.Service(name: SettingsManager.shared.uuid,
                                              type: SERVICE_TYPE,
                                              domain: SERVICE_DOMAIN,
                                              txtRecord:  NWTXTRecord(["type" : "flush"])  )
        
        
        browser = NWBrowser(for: .bonjour(type: SERVICE_TYPE,
                                              domain: SERVICE_DOMAIN),
                                   using: NWParameters())
        
        // if our browser is stuck waiting then we know we don't have permission
        // NOTE: browser state will update with .ready BEFORE it updates to .waiting(error)
        // Therefore we can't simply wait for 'ready', and instead are waiting on the
        // above NWListener to update when our info has successully published.
        browser.stateUpdateHandler = { state in
//            print(self.DEBUG_TAG+"MDNSCHECKER BROWSER STATE \(state)")
            
            if case .waiting(_) = state {
                promise.fail( ServiceError.LOCAL_NETWORK_PERMISSION_DENIED )
                self.browser.cancel()
                self.listener.cancel()
            }
            if case let .failed(error) = state {
                
                promise.fail(error)
                self.browser.cancel()
                self.listener.cancel()
            }
        }
        browser.browseResultsChangedHandler = { (_,_) in
//            print(self.DEBUG_TAG+"MDNSCHECKER BROWSER RESULTS CHANGED")
        }
        
        browser.start(queue: queue)
        listener.start(queue: queue)
        
        return promise.futureResult
    }
    
}
