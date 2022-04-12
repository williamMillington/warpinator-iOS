//
//  MDNSBrowser.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-14.
//

import Foundation
import Network
import NIOCore

protocol MDNSBrowserDelegate {
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result)
    func mDNSBrowserDidRemoveResult(_ result: NWBrowser.Result)
}


final class MDNSBrowser {
    
    
    enum ServiceError: Error {
        case ALREADY_RUNNING
        case UNKNOWN_SERVICE
        case CANCELLED
    }
    
    private let DEBUG_TAG = "MDNSBrowser: "
    
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "" // Don't specify "local" because Daddy Apple says not to
    
    var delegate: MDNSBrowserDelegate?
    
    
    lazy var browser: NWBrowser = createBrowser()
    var parameters: NWParameters {
        
        let params = NWParameters()
        params.allowLocalEndpointReuse = true
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        return params
    }

    
    let eventloopGroup: EventLoopGroup
    
    let queueLabel = "MDNSBrowserQueue"
    lazy var browserQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    init(withEventloopGroup group: EventLoopGroup) {
        
        eventloopGroup = group
    }
    
    
    private func createBrowser() -> NWBrowser {
        
        return NWBrowser(for: .bonjourWithTXTRecord(type: SERVICE_TYPE,
                                                    domain: SERVICE_DOMAIN),
                            using: parameters)
    }
    
    
    
    func start() -> EventLoopFuture<Void> {
        
        
        print(DEBUG_TAG+" starting... (current state:  \(browser.state) )")
        
        let promise = eventloopGroup.next().makePromise(of: Void.self)
        
        
        switch browser.state {
        case .ready:
            promise.fail( ServiceError.ALREADY_RUNNING )
            return promise.futureResult
        case .setup: break // we want to startup, but don't create a new browser
        default:
            browser = createBrowser()
        }
        
        configurePromiseOnReady(promise)
        stopBrowsing()
        
        browser.start(queue: browserQueue)
        
        return  promise.futureResult
    }
    
    
    
    func stop() -> EventLoopFuture<Void> {
        
        let promise = eventloopGroup.next().makePromise(of: Void.self)
        
        switch browser.state {
        case .cancelled, .failed(_):  promise.succeed( {}() )
        default:
            configurePromiseOnStopped(promise)
            stopBrowsing()
            browser.cancel()
        }
        
        return promise.futureResult
    }
    
    
    
    
    
    //
    //
    private func configurePromiseOnReady(_ promise: EventLoopPromise<Void>) {
        
        browser.stateUpdateHandler = { state in
            print(self.DEBUG_TAG+"\t\tstate is \(state)")
            switch state {
            case .setup: return
            case .ready:
                promise.succeed( {}() )
            case .failed(let error): fallthrough
            case .waiting(let error): promise.fail(error)
            case .cancelled: promise.fail( MDNSBrowser.ServiceError.CANCELLED )
            @unknown default:
                promise.fail( MDNSBrowser.ServiceError.UNKNOWN_SERVICE )
            }
            
            self.browser.stateUpdateHandler = self.stateDidUpdate(state: )
        }
    }
    
    
    
    
    //
    //
    private func configurePromiseOnStopped(_ promise: EventLoopPromise<Void>) {
        
        browser.stateUpdateHandler = { state in
            print(self.DEBUG_TAG+"\t\tstate is \(state)")
            switch state {
//            case .setup, .ready, .waiting(_):
            case .failed(_): fallthrough
            case .cancelled: promise.succeed( {}() )
            default:
                self.stopBrowsing()
                self.browser.cancel()
                return
            }
            
            self.browser.stateUpdateHandler = self.stateDidUpdate(state: )
        }
    }
    
    
    
    
    
    //
    // MARK: startBrowsing
    func startBrowsing(){
        
        print(DEBUG_TAG+" start browsing")
        
        browser.browseResultsChangedHandler = resultsDidChange(results: changes:)
        
    }
    
    
    //
    // MARK: stopBrowsing
    func stopBrowsing(){
        
        print(DEBUG_TAG+" stop browsing")
        
        browser.browseResultsChangedHandler = { _, _ in  }
    }
    
    
    
    
    
//    private func restartHandler(newState state: NWBrowser.State){
//
//        print(DEBUG_TAG+"restart state: \(state)")
//
//        switch state {
//        case .ready: startBrowsing()
//        case .cancelled:
//            browser = createBrowser()
//            browser.stateUpdateHandler = restartHandler(newState:)
//            stopBrowsing()
//            browser.start(queue: browserQueue)
//
//        case .failed(let error):
//
//            print(DEBUG_TAG+"failed with error \(error)")
//
//            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
//
//                browserQueue.asyncAfter(deadline: .now() + 1) {
//                    self.browser.stateUpdateHandler = self.restartHandler(newState:)
//                    self.browser.cancel()
//                }
//                return
//
//            } else {
//                print(DEBUG_TAG+"\t\tstopping")
//            }
//            browser.cancel()
//
//        default: break
//        }
//    }
    
    //
    // MARK:  stateDidUpdate
    private func stateDidUpdate(state: NWBrowser.State){
        
        print(DEBUG_TAG+"state: \(state)")
        
        switch state {
        case .cancelled:
            print(DEBUG_TAG+" cancelled")
//            browser = nil
        case .failed(let error):
            
            print(DEBUG_TAG+"failed with error \(error)")
//
//            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
//
//                browserQueue.asyncAfter(deadline: .now() + 1) {
//                    self.browser.stateUpdateHandler = self.restartHandler(newState:)
//                    self.browser.cancel()
//                }
//                return
//
//            } else {
//                print(DEBUG_TAG+"\t\tstopping")
//            }
            
        default: print(DEBUG_TAG+"\(state)")
        }
        
    }
    
    
    //
    // MARK:  resultsDidChange
    private func resultsDidChange(results: Set<NWBrowser.Result>,
                                  changes: Set<NWBrowser.Result.Change>){
        
//        print(DEBUG_TAG+"results ")
        
        for change in changes {
            
            switch change {
            case .added(let result):  delegate?.mDNSBrowserDidAddResult(result)
            case .changed(old: _, new: let new, flags: let flags):
                if case .metadataChanged = flags {
                    delegate?.mDNSBrowserDidAddResult(new)
                }
            case .removed(let result):    delegate?.mDNSBrowserDidRemoveResult(result)
            default: break //print(DEBUG_TAG+"unforeseen result change: \n\t\t\(change)")

            }
            
        }
        
    }
    
}
