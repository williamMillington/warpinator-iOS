//
//  NetworkMonitor.swift
//  Warpinator
//
//  Created by William Millington on 2022-04-15.
//

import Foundation
import Network
import NIOCore


class NetworkMonitor {
    
    static let DEBUG_TAG : String = "NetworkMonitor (statics): "
    
    let DEBUG_TAG : String = "NetworkMonitor: "
    
    let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    
    let queue: DispatchQueue = DispatchQueue(label: "NetworkMonitor")
    
//    static var shared: NetworkMonitor = NetworkMonitor()
    
    init(){
        
        monitor.pathUpdateHandler = { path in
            print(self.DEBUG_TAG+"wifi status is \(path.status)")
        }
        
        monitor.start(queue: queue)
        
    }
    
    
    
    //
    //
//    func checkWifiAvailability(withPromise promise: EventLoopPromise<Void>) -> EventLoopFuture<Void> {
    var wifiIsAvailable: Bool {
        print(DEBUG_TAG+"checking wifi availablility")
        switch monitor.currentPath.status {
        case .satisfied: return true
        default: return false
            
        }
        
//        var wifiCheckCount = 0
//
//        monitor.pathUpdateHandler = { path in
//
//            print(NetworkMonitor.DEBUG_TAG+"updated path: \(path) (\(path.status))")
//
//            guard path.status != .unsatisfied else {
//                print(NetworkMonitor.DEBUG_TAG+"No wifi")
//                promise.fail( Server.ServerError.NO_INTERNET     ) // placeholder error
//                return
//            }
//
//            guard wifiCheckCount < 50 else {
//                print(NetworkMonitor.DEBUG_TAG+"too many updates")
//                promise.fail( AuthenticationError.TimeOut     ) // placeholder error TODO: create appropriate error
//                return
//            }
//
//            wifiCheckCount += 1
//
//            if path.status == .satisfied {
//                promise.succeed( {}() )
//            }
//        }
//
//        monitor.start(queue: queue)
//
//        return promise.futureResult
    }
    
    
    
    func waitForWifiAvailable(withPromise promise: EventLoopPromise<Void>) -> EventLoopFuture<Void> {
        
        guard monitor.currentPath.status != .satisfied else {
            
            promise.succeed( Void() )
            
            return promise.futureResult
        }
        
        monitor.pathUpdateHandler = { path in

            print(NetworkMonitor.DEBUG_TAG+"updated path: \(path) (\(path.status))")

            guard path.status != .unsatisfied else {
                print(NetworkMonitor.DEBUG_TAG+"No wifi")
                promise.fail( Server.ServerError.NO_INTERNET     ) // placeholder error
                return
            }

            
            if path.status == .satisfied {
                promise.succeed( Void() )
                self.monitor.pathUpdateHandler = { _ in
                    print(self.DEBUG_TAG+"wifi status is \(path.status)")
                }
            }
        }
        
        
        return promise.futureResult
    }
    
    
    
    
    
    
    
}
