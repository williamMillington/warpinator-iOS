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
    
    var browser: NWBrowser?
    
    
    let queueLabel = "MDNSBrowserQueue"
    lazy var browserQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    
    
    //
    // MARK: start
    func start(){
        
        guard browser == nil else {
            if browser!.state != .ready {
                start()
            }
            print(DEBUG_TAG+"Browser already running");  return
        }
        
        print(DEBUG_TAG+"Starting MDNSBrowser...")
        
        let params = NWParameters()
        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
        
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            inetOptions.version = .v4
        }
        
        
        browser = NWBrowser(for: .bonjourWithTXTRecord(type: SERVICE_TYPE,
                                                       domain: SERVICE_DOMAIN),
                               using: params)
        browser?.stateUpdateHandler = stateDidUpdate(newState:)
        browser?.browseResultsChangedHandler = resultsDidChange(results:changes:)
        
        browser?.start(queue: browserQueue)
        
    }
    
    
    //
    // MARK:  stop
    func stop(){
        
        browser?.cancel()
//        browser = nil
        
    }
    
    
    //
    // MARK:  restart
    func restart(){
        print(self.DEBUG_TAG+"restarting in 2 seconds...")
        self.browserQueue.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.stop()
            self?.start()
        }
    }
    
    
    
    //
    // MARK:  stateDidUpdate
    private func stateDidUpdate(newState: NWBrowser.State){
        
        print(DEBUG_TAG+"statedidupdate")
        
        switch newState {
        case .cancelled: print(DEBUG_TAG+" cancelled")
            browser = nil
        case .failed(let error):
            print(DEBUG_TAG+"failed")
            // Restart the browser if it loses its connection
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                print(DEBUG_TAG+"Browser failed with \(error)")
//                restart()
                self.stop()
            } else {
                print(DEBUG_TAG+"Browser failed with \(error), stopping")
                self.stop()
            }
        default: print(DEBUG_TAG+"\(newState)")
        }
        
    }
    
    
    //
    // MARK:  resultsDidChange
    private func resultsDidChange(results: Set<NWBrowser.Result>,
                                  changes: Set<NWBrowser.Result.Change>){
        
        print(DEBUG_TAG+"RESULTS CHANGED")
        
        results.forEach { result in
            print(self.DEBUG_TAG+"\t\t\(result)")
        }
        
        for change in changes {
            
            switch change {
            case .added(let result):
//                print(DEBUG_TAG+"result added \(change)")
                
                delegate?.mDNSBrowserDidAddResult(result)
                
            case .changed(old: let old, new: let new, flags: let flags):
                print(DEBUG_TAG+"\t\(old.endpoint) changed to \(new.endpoint), \(flags)")
                switch flags {
                case .identical: print(DEBUG_TAG+"\t\tidentical")
                case .interfaceRemoved: print(DEBUG_TAG+"\t\tinterfaceRemoved")
                case .interfaceAdded: print(DEBUG_TAG+"\t\tinterfaceAdded")
                case .metadataChanged: print(DEBUG_TAG+"\t\tmetadataChanged")
                default: print(DEBUG_TAG+"\t\tunknown changes: \(flags)")
                }
            case .removed(let result):
//                print(DEBUG_TAG+"result removed \(result)")
                delegate?.mDNSBrowserDidRemoveResult(result)
            default: break //print(DEBUG_TAG+"unforeseen result change: \n\t\t\(change)")
                
            }
            
        }
        
    }
    
}
