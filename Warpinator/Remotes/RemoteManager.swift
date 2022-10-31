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
        
        remote.eventLoopGroup = remoteEventloopGroup
        remotes[remote.details.uuid] = remote
        
        DispatchQueue.main.async {
            self.remotesViewController?.remoteAdded(remote)
        }
        
        remote.startupConnection()
    }
    
    
    // tells the remote with this uuid to start a connection,
    // if it exists
    func startConnection(forRemoteWithUUID uuid: String) {
        
        guard let remote = remotes[uuid] else {
            print(DEBUG_TAG+"\t remote not found")
            return
        }
        
        remote.startupConnection()
    }
    
    
    
    // MARK: remove Remote
    func removeRemote(withUUID uuid: String){
        print(DEBUG_TAG+"removing remote with UUID: \(uuid) ...")
        
        guard let remote = remotes[uuid] else {
            print(DEBUG_TAG+"\t remote not found")
            return
        }
        
        // possibly grey out disconnected remotes?
        
        _ = remote.disconnect()
    }
    
    
    //
    // MARK: find remote
    @discardableResult
    func containsRemote(for uuid: String) -> Remote? {
        
        // return first instance of any remotes whose uuid matches
        return remotes.values.compactMap { $0.details.uuid == uuid ? $0 : nil }.first
        
    }
    
    
    // MARK: shutdown all remotes
    func shutdownAllRemotes() -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+"shutting down all remotes")
        
        // for each remote, get a future for when it completes its disconnection process
        let futures = remotes.values.compactMap { remote in
            return remote.disconnect()
        }
        
        
        // when all remotes have finished disconnecting
        let future = EventLoopFuture.whenAllComplete(futures, on: remoteEventloopGroup.next() ).map { _ -> Void in
            print("RemoteManager: Remotes have finished shutting down")
        }
        
        future.whenComplete { response in
            
            print(self.DEBUG_TAG+"remotes completed disconnecting: ")
            
            do {
                try response.get()
                print(self.DEBUG_TAG+"\tremotes finished disconnecting successfully.")
            } catch {
                print(self.DEBUG_TAG+"\terror occured while disconnecting remotes: \(error)")
            }
        }
        
        return future
    }
}









// MARK: BrowserDelegate
extension RemoteManager: BrowserDelegate {
    
    
    
    // MARK: mDNS result added
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result) {
        
        let endpoint = result.endpoint
        
        print(DEBUG_TAG+"ADDED result \(endpoint)")
        
        // ignore result:
        // - if result has metadata,
        // - AND if the metadata has a record "type",
        // - AND if "type" is 'flush'
        guard case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata,
           let type = record.dictionary["type"],
           type != "flush" else {
            print(DEBUG_TAG+"\t\t service is flushing; ignore"); return
        }
        
        guard case let .service(name: serviceName, type: _, domain: _, interface: _) = endpoint else {
            print(DEBUG_TAG+"unknown service endpoint type: \(result.endpoint)"); return
        }
        
        
        // Check if we found our own MDNS record
        guard serviceName != SettingsManager.shared.uuid else {
            print(DEBUG_TAG+"\t\t Found myself"); return
        }
        
        
        // check if we already know this remote
        if let remote = containsRemote(for: serviceName) {
            
            print(DEBUG_TAG+"\t\t\t Remote is connected")
            
            if remote.details.status != .Connected  {
                print(DEBUG_TAG+"\t\t\t not connected: reconnecting...")
                remote.startupConnection()
            }
            return
        }
        
        print(DEBUG_TAG+"\t\t New service discovered: \(serviceName)")
        
        let details = RemoteDetails(endpoint: result.endpoint,
                                    hostname: record.dictionary["hostname"] ?? serviceName,
                                    authPort: Int( record.dictionary["auth-port"] ?? "4200" ) ?? 42000,
                                    uuid: serviceName,
                                    api:  record.dictionary["api"] ?? "1")
        
        let newRemote = Remote(details: details, eventLoopGroup: remoteEventloopGroup)
        
        addRemote(newRemote)
        
    }
    
    
    // MARK: mDNS result removed
    func mDNSBrowserDidRemoveResult(_ result: NWBrowser.Result) {
        
        print(DEBUG_TAG+"REMOVED result \(result.endpoint)")
        
        // ignore anything with type "flush"
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
