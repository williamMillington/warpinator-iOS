//
//  MDNSBrowser.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-14.
//

import Foundation
import Network

protocol MDNSBrowserDelegate {
//    func refreshResults(results: Set<NWBrowser.Result>)
//    func displayBrowseError(_ error: NWError)
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result)
//    func addRemote(forConnection: NS)
}


class MDNSBrowser {
    
    private let DEBUG_TAG = "MDNSBrowser: "
    
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "" // Don't specify "local" because Daddy Apple says not to
    
    var delegate: MDNSBrowserDelegate?
    
    var browser: NWBrowser?
    
    
    func startBrowsing(){
        
        print(DEBUG_TAG+"started browsing")
        
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
        
        browser?.start(queue: .main)
    }
    
    
    private func stateDidUpdate(newState: NWBrowser.State){
        
//        print(DEBUG_TAG+"statedidupdate")
        
        switch newState {
        case .failed(let error):
            print(DEBUG_TAG+"failed")
            // Restart the browser if it loses its connection
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                print(DEBUG_TAG+"Browser failed with \(error), restarting")
                browser?.cancel()
                startBrowsing()
            } else {
                print(DEBUG_TAG+"Browser failed with \(error), stopping")
//                self.delegate?.displayBrowseError(error)
                browser?.cancel()
            }
        case .waiting(_):
//            print(DEBUG_TAG+"Browser is waiting: \(error)")
            break
        case .cancelled:
            print(DEBUG_TAG+"Browsing has cancelled.")
//            delegate?.refreshResults(results: Set())
        
        case .ready:
//            print(DEBUG_TAG+"Browser ready, results:")
            if let results = browser?.browseResults {
                
                for result in results {
                    print(DEBUG_TAG+"\t \(result)")
                }
                
//                delegate?.refreshResults(results: results)
            }
        default: print(DEBUG_TAG+" unforeseen state update.")
        }
        
    }
    
    private func resultsDidChange(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>){
        
//        print(DEBUG_TAG+"resultsdidchange")
        
        
//        for result in results {
//            print(DEBUG_TAG+"\tresult: \(result)")
//        }
        
        for change in changes {
            
            switch change {
            case .added(let result):
                
//                print(DEBUG_TAG+"added: \(result)")
                
                delegate?.mDNSBrowserDidAddResult(result)
                
            case .removed( _):
                break //;print(DEBUG_TAG+"result removed: \(result)")
            case .changed(old: let  old, new: let new, flags: let flags):
                print(DEBUG_TAG+"changed (old: \(old)), (new: \(new)), (flags: \(flags))")
                print(DEBUG_TAG+"\t\told: \(old)")
                print(DEBUG_TAG+"\t\tnew: \(new)")
                print(DEBUG_TAG+"\t\tflags: \(flags)")
                break
            default: break //;print(DEBUG_TAG+"unforeseen result change")
            
            }
            
        }
        
    }
    
    
}
