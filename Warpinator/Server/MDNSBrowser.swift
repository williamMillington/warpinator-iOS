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
    private let SERVICE_DOMAIN = ""
    
    var delegate: MDNSBrowserDelegate?
    
    
    lazy var browser: NWBrowser = createBrowser()
    
    let eventloopGroup: EventLoopGroup
    
    let queueLabel = "MDNSBrowserQueue"
    lazy var browserQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    init(withEventloopGroup group: EventLoopGroup) {
        eventloopGroup = group
    }
    
    
    private func createBrowser() -> NWBrowser {
        
        print(DEBUG_TAG+"\t Creating browser")
        
        let params = NWParameters()
        params.allowLocalEndpointReuse = true
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        return NWBrowser(for: .bonjourWithTXTRecord(type: SERVICE_TYPE,
                                                    domain: SERVICE_DOMAIN),
                            using: params)
    }
    
    
    
    func start() -> EventLoopFuture<Void> {
        
        let promise = eventloopGroup.next().makePromise(of: Void.self)
        
        switch browser.state {
        case .ready:
            promise.succeed( Void() )
            return promise.futureResult
        case .setup: break // we want to startup, but don't create a new browser
        default:
            browser = createBrowser()
        }
        
        configure(promise, toSucceedForState: .ready )
        stopBrowsing()
        
        browser.start(queue: browserQueue)
        
        return promise.futureResult.map { _ in
        }
    }
    
    
    
    func stop() -> EventLoopFuture<Void> {
        
//        print(DEBUG_TAG+"\t\tstopping... (current state:  \(browser.state) )")
        
        let promise = eventloopGroup.next().makePromise(of: Void.self)
        
        switch browser.state {
        case .cancelled, .failed(_), .setup:
            promise.succeed( Void() )
            
        default:
            configure(promise, toSucceedForState: .cancelled)
            stopBrowsing()
            browser.cancel()
        }
        
        return promise.futureResult.flatMapError { result in
            // catch the failed case –which, in this circumstance, is a success– and return it as such
            return self.eventloopGroup.next().makeSucceededVoidFuture()
        }
    }
    
    
    
    
    //
    // Allows a promise to be configured to fire for a number of different states
    //      - NOTE: .failure() will ALWAYS fail the promise
    // MARK: configurePromise
    private func configure(_ promise: EventLoopPromise<Void>,
                           toSucceedForState state: NWBrowser.State) {
        
        
        browser.stateUpdateHandler = { updatedState in
            
//            print(self.DEBUG_TAG+"\t\t\t browser updated to \(updatedState) while waiting for \(state)")
            
            // we have to be careful not to let a promise go unfullfilled
            switch updatedState {
            case .failed(let error):
                promise.fail(error)
                return
            case .cancelled:
                
                // Fail if caller was waiting for a different state, because –once cancelled–
                // those states (ex. .ready, .watiting )  can never be reached again and we just
                // create a new listener (which will leave the promise hanging)
                if state != .cancelled {
                    promise.fail(  ServiceError.CANCELLED  )
                    return
                }
                
                // proceed to default case
                fallthrough
                
            default:
                
                // succeed if states match
                if updatedState == state {
                    promise.succeed( Void() )
                    self.browser.stateUpdateHandler = self.stateDidUpdate(state: )
                }
                
            }
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
    
    
    //
    // MARK:  stateDidUpdate
    private func stateDidUpdate(state: NWBrowser.State){
        
        print(DEBUG_TAG+" state is \(state)")
        
//        switch state {
//        case .cancelled:
//            print(DEBUG_TAG+" cancelled")
////            browser = nil
//        case .failed(let error):
//
//            print(DEBUG_TAG+"failed with error \(error)")
//
//        default: print(DEBUG_TAG+"\(state)")
//        }
        
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
            case .removed(let result):
                delegate?.mDNSBrowserDidRemoveResult(result)
            default: break //print(DEBUG_TAG+"unforeseen result change: \n\t\t\(change)")

            }
        }
    }
    
    
}
