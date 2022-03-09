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
    
    weak var remotesViewController: ViewController?
    
    var remoteEventloopGroup: EventLoopGroup?
    
    // TODO: remove this feature.
    // - Warp registration returns wrong address (I think is a bug in OG Warpinator?)
    // - IP is now secured during authentication
    /* if WarpRegistration receives a request BEFORE we detect a remote
     with that hostname, then store that IP address here so we can update that
     remote once it is detected   [hostname:ipaddress] */
    var ipPlaceHolders : [String:String] = [:]
    
    
    //
    // MARK: add Remote
    func addRemote(_ remote: Remote){
        print(DEBUG_TAG+"adding remote with UUID: \(remote.details.uuid)")
        
        remote.eventloopGroup = remoteEventloopGroup 
        remotes[remote.details.uuid] = remote
        
        // if we've stored the ip address of a remote with that hostname
        // This is probably not great, for the same reason listed down in
        // storeIPAddress()
        if let address = ipPlaceHolders[remote.details.hostname] {
            remote.details.ipAddress = address
        }
        
        remotesViewController?.remoteAdded(remote)
        
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
            print(DEBUG_TAG+"removing remote...")
        guard remotes[uuid] != nil else {
            print(DEBUG_TAG+"\t remote not found")
            return
        }
        
        remotes.removeValue(forKey: uuid)
        print(DEBUG_TAG+"\t remote removed")
        
    }
    
    
    //
    // MARK: storeIPAddress
    func storeIPAddress(_ address: String, forHostname hostname: String){
        
        print(DEBUG_TAG+"storing address (\(address)) for \(hostname)")
        
        // TODO: this fails if two remotes share a hostname. Not good. No bueno.
        // Can't use uuid because it's not provided in the Registration request
        remotes.forEach { (key,remote) in
            if remote.details.hostname == hostname {
                print(self.DEBUG_TAG+"\tfound remote for hostname\(hostname)")
                remote.details.ipAddress = address
                remote.startConnection()
                return
            }
        }
        
        ipPlaceHolders[hostname] = address
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
    func shutdownAllRemotes() {
        
        remotes.values.forEach { remote in
            remote.disconnect()
        }
        
    }
    
}
