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
    }
    
    static let DEBUG_TAG : String = "NetworkMonitor (statics): "
    
    let DEBUG_TAG : String = "NetworkMonitor: "
    
    let delegate: NetworkDelegate
    
    let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    let queue: DispatchQueue = DispatchQueue(label: "NetworkMonitor")
    
    
    init(delegate: NetworkDelegate){
        
        self.delegate = delegate
        
        monitor.pathUpdateHandler = updateHandler(path:)
        monitor.start(queue: queue)
        
        // actually triggers the network to check. Do not delete.
        let _ = wifiIsAvailable
    }
    
    
    
    //
    //
    var wifiIsAvailable: Bool {
        print(DEBUG_TAG+"checking wifi availablility (\(monitor.currentPath.status))")
        switch monitor.currentPath.status {
        case .satisfied: return true
        default: return false
            
        }
    }
    
    
    
    // TODO: this function -and other functions like it in the MDNSListener and Browser classes, should be modified to not update the pathUpdateHandler, but instead modify a set, which is mapped by a consistent pathUpdateHandler, declared in a different location. This avoids dropping preexisting promises without completing them every time a new call is made
    func waitForWifiAvailable(withPromise promise: EventLoopPromise<Void>) -> EventLoopFuture<Void> {
        
        // if status is .satisfied, then we are connected
        guard monitor.currentPath.status != .satisfied else {
            promise.succeed( Void() )
            return promise.futureResult
        }
        
        // otherwise, wait for connectivity
        
        // every time the path is updated, check for connectivity
        monitor.pathUpdateHandler = { path in

            print(NetworkMonitor.DEBUG_TAG+" (waitForWifiAvailable) updated path: \(path) (\(path.status))")
            
            switch path.status {
                
            case .satisfied: // .satisfied means we're connected
                
                promise.succeed( Void() ) // fulfill promise
                
                // set monitor back to updating the delegate
                self.monitor.pathUpdateHandler = self.updateHandler(path:)
                
            case .unsatisfied: // if we're not connected
                print(NetworkMonitor.DEBUG_TAG+" (waitForWifiAvailable) No wifi")
                promise.fail( Server.ServerError.NO_INTERNET     ) // fail promise (placeholder error)
                
            default:
                print(self.DEBUG_TAG+"u (waitForWifiAvailable) nknown status in path: \(path.status)")
            }
            
        }
        
        
        return promise.futureResult
    }
    
    
    
    func updateHandler(path: NWPath) {
        
        print(self.DEBUG_TAG+"path \(path) status is \(path.status)")
        
        switch path.status {
        case .satisfied: delegate.didGainLocalNetworkConnectivity()
        case .unsatisfied: delegate.didLoseLocalNetworkConnectivity()
        default: break
        }
        
    }
    
    
    
    
    var browser: NWBrowser!
    var listener: NWListener!
    
    func waitForMDNSPermission(withPromise promise: EventLoopPromise<Bool> ) -> EventLoopFuture<Bool> {
        
        let parameters = NWParameters.udp
        listener = try! NWListener(using: parameters)
        
        listener.serviceRegistrationUpdateHandler = { change in
            
            // if we've published successfully then we know we've got permission
            if case .add(_) = change {
                promise.succeed( true )
                self.listener.cancel()
                self.browser.cancel()
            }
        }
        listener.stateUpdateHandler = { _ in
        }
        listener.newConnectionHandler = { _ in
        }
        
        
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
        // because fuck you for trying to use the API
        browser.stateUpdateHandler = { state in
            print(self.DEBUG_TAG+"MDNSCHECKER BROWSER STATE \(state)")
            
            if case .waiting(_) = state {
                
//                promise.succeed(false)
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
