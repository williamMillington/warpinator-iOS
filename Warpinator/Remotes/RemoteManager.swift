//
//  RemoteManager.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-17.
//

import Foundation
import Network

import GRPC
import NIO


final class RemoteManager {
    
    private let DEBUG_TAG: String = "RemoteManager: "
    
    var remotes: [String: Remote] = [:] // [hostname:remote]
    
    weak var remotesViewController: MainViewController?
    
    let remoteEventloopGroup: EventLoopGroup
    
    init(withEventloopGroup group: EventLoopGroup){
        remoteEventloopGroup = group
    }
    
    
    //
    // MARK: add Remote
    func addRemote(_ remote: Remote){
        print(DEBUG_TAG+"adding remote with UUID: \(remote.details.uuid)")
        
        remote.eventloopGroup = remoteEventloopGroup 
        remotes[remote.details.uuid] = remote
        
        DispatchQueue.main.async {
            self.remotesViewController?.remoteAdded(remote)
        }
        
        remote.startConnection()
    }
    
    
    // tells the remote with this uuid to start a connection,
    // if it exists
    func startConnection(forRemoteWithUUID uuid: String) {
        
        guard let remote = remotes[uuid] else {
            print(DEBUG_TAG+"\t remote not found")
            return
        }
        
        remote.startConnection()
    }
    
    
    
    // MARK: remove Remote
    func removeRemote(withUUID uuid: String){
        print(DEBUG_TAG+"removing remote with UUID: \(uuid) ...")
        
        guard let remote = remotes[uuid] else {
            print(DEBUG_TAG+"\t remote not found")
            return
        }
        
        
        print(DEBUG_TAG+" trying out just like not removing them?")
        
//        let future = remote.disconnect()
//
//        future.whenComplete { [weak self] result in
//
//            self?.remotes.removeValue(forKey: remote.details.uuid)
//
//            DispatchQueue.main.async {
//                self?.remotesViewController?.remoteRemoved(with: uuid)
//            }
//
//            print((self?.DEBUG_TAG ?? "RemoteManager is nil")+"\tremote removed")
//        }
    }
    
    
    //
    // MARK: find remote
    @discardableResult
    func containsRemote(for uuid: String) -> Remote? {
        
        if let remote = remotes.first(where: { (key, entry) in
            return entry.details.uuid == uuid })?.value {
            return remote
        }
        
        return nil
    }
    
    
    // MARK: shutdown all remotes
    func shutdownAllRemotes() -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+"shutting down all remotes")
        
//        guard let eventloop = remoteEventloopGroup.next() else {
//            print(DEBUG_TAG+"No eventloop")
//            return nil
//        }
        
        let futures = remotes.values.compactMap { remote in
            return remote.disconnect()
        }
        
        //
        // whoops a hack
        let future = EventLoopFuture.whenAllComplete(futures, on: remoteEventloopGroup.next() ).map { _ -> Void in
            print("RemoteManager: Remotes have finished shutting down")
        }
        
        future.whenComplete { response in
            
            print(self.DEBUG_TAG+"remotes completed disconnecting: ")
            
            do {
                try response.get()
                print(self.DEBUG_TAG+"remotes finished: ")
            } catch {
                print(self.DEBUG_TAG+"error: \(error)")
            }
        }
        
        return future
    }
}



extension RemoteManager: MDNSBrowserDelegate {
    
    
    
    // MARK: mDNS result added
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result) {
        
        print(DEBUG_TAG+"ADDED result \(result.endpoint)")
        
        // ignore result:
        // - if result has metadata,
        // - AND if the metadata has a record "type",
        // - AND if "type" is 'flush'
        guard case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata,
           let type = record.dictionary["type"],
           type != "flush" else {
            print(DEBUG_TAG+"\t\t service is flushing; ignore"); return
        }
        
        
        var serviceName = "unknown_service"
        switch result.endpoint {
        case .service(name: let name, type: _, domain: _, interface: _):
            
            serviceName = name
            
            // Check if we found our own MDNS record
            if name == SettingsManager.shared.uuid {
                print(DEBUG_TAG+"\t\t Found myself"); return
            } else {
                print(DEBUG_TAG+"\t\t New service discovered: \(name)")
            }
            
        default: print(DEBUG_TAG+"unknown service endpoint type: \(result.endpoint)"); return
        }
        
        
        // some default values
        var hostname = serviceName
        var api = "1"
        var authPort = 42000
        
        // parse TXT record for metadata
        if case let NWBrowser.Result.Metadata.bonjour(txtRecord) = result.metadata {
            
            for (key, value) in txtRecord.dictionary {
                switch key {
                case "hostname": hostname = value
                case "api-version": api = value
                case "auth-port": authPort = Int(value) ?? 42000
                case "type": break
                default: print("unknown TXT record type: \"\(key)\":\"\(value)\"")
                }
            }
        }
        
        
        
        // check if we already know this remote
        if let remote = containsRemote(for: serviceName) {
            
            print(DEBUG_TAG+"\t\t Service already added")
            
            // Are we connected?
            if [ .Disconnected, .Idle, .Error ].contains( remote.details.status ) {
                print(DEBUG_TAG+"\t\t\t not connected: reconnecting...")
                remote.startConnection()
            }
            return
        }
        
        
        var details = RemoteDetails(endpoint: result.endpoint)
        details.hostname = hostname
        details.uuid = serviceName
        details.api = api
        details.port = 42000
        details.authPort = authPort //"42000"
        details.status = .Disconnected
        
        
        let newRemote = Remote(details: details)
        
        addRemote(newRemote)
        
    }
    
    
    // MARK: mDNS result removed
    func mDNSBrowserDidRemoveResult(_ result: NWBrowser.Result) {
        
        print(DEBUG_TAG+"REMOVED result \(result.endpoint)")
        
        // check metadata for "type",
        // and if type is 'flush', then ignore
        if case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata,
           let type = record.dictionary["type"],
           type == "flush" {
            print(DEBUG_TAG+"\t\t service is flushing; ignore"); return
        }
        
        
        if case let .service(name: name, type: _, domain: _, interface: _) = result.endpoint {
            
            // check if we have a remote registered to the service name
            if let remote = containsRemote(for: name) {
        
                // remove it
                removeRemote(withUUID: remote.details.uuid)
            }
        }
        
    }
    
}
