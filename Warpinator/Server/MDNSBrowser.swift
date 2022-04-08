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
    
    var browser: NWBrowser
    var currentResults: [NWBrowser.Result] {
        print(DEBUG_TAG+"current results are: ")
        browser.browseResults.forEach { result in
            print(DEBUG_TAG+"\t\t \(result) ")
        }
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
        
//        refreshResults()
    }
    
    
//    func refreshResults(){
//
//        print(DEBUG_TAG+"refreshing results ")
//
//        let _ = currentResults
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
//            self.refreshResults()
//        }
//
//    }
    
    //
    // MARK start
//    func start(){
        
//        guard browser == nil else {
//            if browser!.state != .ready {
//                start()
//            }
//            print(DEBUG_TAG+"Browser already running");  return
//        }
//        
//        print(DEBUG_TAG+"Starting MDNSBrowser...")
//        
//        let params = NWParameters()
////        params.includePeerToPeer = true
//        params.allowLocalEndpointReuse = true
//        
//        
//        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
//            inetOptions.version = .v4
//        }
//
//
//        browser = NWBrowser(for: .bonjourWithTXTRecord(type: SERVICE_TYPE,
//                                                       domain: SERVICE_DOMAIN),
//                               using: params)
//
//        browser?.stateUpdateHandler = stateDidUpdate(newState:)
//
//        browser?.start(queue: browserQueue)
        
//    }
    
    
    func startBrowsing(){
        
        print(DEBUG_TAG+"beginning browsing")
        
        browser.browseResultsChangedHandler = resultsDidChange(results:changes:)
        currentResults.forEach { result in
            self.delegate?.mDNSBrowserDidAddResult(result)
        }
    }
    
    func stopBrowsing(){
        
        print(DEBUG_TAG+"stopping browsing")
        
        browser.browseResultsChangedHandler = { _, _ in  }
    }
    
    
    //
    // MARK:  stop
    func stop(){
        browser.cancel()
    }
    
    //
    // MARK:  stateDidUpdate
    private func stateDidUpdate(newState: NWBrowser.State){
        
        print(DEBUG_TAG+"statedidupdate")
        
        switch newState {
        case .cancelled:
            print(DEBUG_TAG+" cancelled")
//            browser = nil
        case .failed(_):
            browser.cancel()
            print(DEBUG_TAG+"failed")
        default: print(DEBUG_TAG+"\(newState)")
        }
        
    }
    
    
    //
    // MARK:  resultsDidChange
    private func resultsDidChange(results: Set<NWBrowser.Result>,
                                  changes: Set<NWBrowser.Result.Change>){
        
        print(DEBUG_TAG+"results ")
        
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
