//
//  MDNSBrowser.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-14.
//

import Foundation
import Network

protocol MDNSBrowserDelegate {
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result)
}

class MDNSBrowser {
    
    private let DEBUG_TAG = "MDNSBrowser: "
    
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "" // Don't specify "local" because Daddy Apple says not to
    
    var delegate: MDNSBrowserDelegate?
    
    var browser: NWBrowser?
    
    
    lazy var queueLabel = "MDNSBrowserQueue"
    lazy var browserQueue = DispatchQueue(label: queueLabel, qos: .utility)
    
    func start(){
        
        guard browser == nil  else {
            print(DEBUG_TAG+"Browser already running")
            return
        }
        
        print(DEBUG_TAG+"Starting MDNSBrowser...")
        
        let params = NWParameters()
        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
        
        
        if let inetOptions =  params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
//            print(DEBUG_TAG+"restrict connections to v4")
            inetOptions.version = .v4
        }
        
        
        browser = NWBrowser(for: .bonjourWithTXTRecord(type: SERVICE_TYPE, domain: SERVICE_DOMAIN), using: params)
        browser?.stateUpdateHandler = self.stateDidUpdate(newState:)
        browser?.browseResultsChangedHandler = self.resultsDidChange(results:changes:)
        
        browser?.start(queue: browserQueue)
        
    }
    
    
    func stop(){
        
        browser?.cancel()
        browser = nil
        
    }
    
    func restart(){
        print(self.DEBUG_TAG+"restarting in 2 seconds...")
        self.browserQueue.asyncAfter(deadline: .now() + 2) {
            self.stop()
            self.start()
        }
    }
    
    
    
    private func stateDidUpdate(newState: NWBrowser.State){
        
//        print(DEBUG_TAG+"statedidupdate")
        
        switch newState {
        case .failed(let error):
            print(DEBUG_TAG+"failed")
            // Restart the browser if it loses its connection
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                print(DEBUG_TAG+"Browser failed with \(error), restarting")
                restart()
            } else {
                print(DEBUG_TAG+"Browser failed with \(error), stopping")
                self.stop()
            }
        default: print(DEBUG_TAG+"\(newState)")
        }
        
    }
    
    private func resultsDidChange(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>){
        
        for change in changes {
            
            switch change {
            case .added(let result):
                
                // results in UI update
                DispatchQueue.main.async {
                    self.delegate?.mDNSBrowserDidAddResult(result)
                }
            case .changed(old: _, new: let new, flags: let flags):
                print(DEBUG_TAG+"\t\t\(new.endpoint), \(flags)")
            default: break //;print(DEBUG_TAG+"unforeseen result change")
            
            }
            
        }
        
    }
    
}
