//
//  MDNSBrowser.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-14.
//

import Foundation
import Network

protocol MDNSBrowserDelegate {
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result)
    func mDNSBrowserDidRemoveResult(_ result: NWBrowser.Result)
}


final class MDNSBrowser {
    
    private let DEBUG_TAG = "MDNSBrowser: "
    
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "" // Don't specify "local" because Daddy Apple says not to
    
    var delegate: MDNSBrowserDelegate?
    
    
    var parameters: NWParameters {
        
        let params = NWParameters()
        params.allowLocalEndpointReuse = true
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        return params
    }
    
    var browser: NWBrowser
    var currentResults: [NWBrowser.Result] {
//        print(DEBUG_TAG+"current results are: ")
//        browser.browseResults.forEach { result in
//            print(DEBUG_TAG+"\t\t \(result.endpoint) ")
//        }
        return Array( browser.browseResults )
    }
    
    let queueLabel = "MDNSBrowserQueue"
    lazy var browserQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    init() {
        
//        print(DEBUG_TAG+"Creating MDNSBrowser...")
        
        let params = NWParameters()
        params.allowLocalEndpointReuse = true
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        browser = NWBrowser(for: .bonjourWithTXTRecord(type: SERVICE_TYPE,
                                                       domain: SERVICE_DOMAIN),
                               using: params)
        
        browser.stateUpdateHandler = stateDidUpdate(newState:)
        startBrowsing()
        
        browser.start(queue: browserQueue)
        
    }
    
    
    private func createBrowser() -> NWBrowser {
        
        return NWBrowser(for: .bonjourWithTXTRecord(type: SERVICE_TYPE,
                                                    domain: SERVICE_DOMAIN),
                            using: parameters)
    }
    
    
    //
    // MARK: startBrowsing
    func startBrowsing(){
        
        print(DEBUG_TAG+"beginning browsing")
        
        browser.browseResultsChangedHandler = resultsDidChange(results:changes:)
        currentResults.forEach { result in
            self.delegate?.mDNSBrowserDidAddResult(result)
        }
    }
    
    
    //
    // MARK: stopBrowsing
    func stopBrowsing(){
        
        print(DEBUG_TAG+"stopping browsing")
        
        browser.browseResultsChangedHandler = { _, _ in  }
    }
    
    
    private func restartHandler(newState state: NWBrowser.State){
        
        print(DEBUG_TAG+"restart state: \(state)")
        
        switch state {
        case .ready: startBrowsing()
        case .cancelled:
            browser = createBrowser()
            browser.stateUpdateHandler = restartHandler(newState:)
            stopBrowsing()
            browser.start(queue: browserQueue)
            
        case .failed(let error):
            
            print(DEBUG_TAG+"failed with error \(error)")
            
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                
                browserQueue.asyncAfter(deadline: .now() + 1) {
                    self.browser.stateUpdateHandler = self.restartHandler(newState:)
                    self.browser.cancel()
                }
                return
                
            } else {
                print(DEBUG_TAG+"\t\tstopping")
            }
            browser.cancel()
            
        default: break
        }
        
    }
    
    //
    // MARK:  stateDidUpdate
    private func stateDidUpdate(newState state: NWBrowser.State){
        
        print(DEBUG_TAG+"state: \(state)")
        
        switch state {
//        case .cancelled:
//            print(DEBUG_TAG+" cancelled")
//            browser = nil
        case .failed(let error):
            
            print(DEBUG_TAG+"failed with error \(error)")
            
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                
                browserQueue.asyncAfter(deadline: .now() + 1) {
                    self.browser.stateUpdateHandler = self.restartHandler(newState:)
                    self.browser.cancel()
                }
                return
                
            } else {
                print(DEBUG_TAG+"\t\tstopping")
            }
            
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
