//
//  RemoteManager.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-17.
//

import Foundation
import Network

import GRPC
import NIO


class RemoteManager {
    
    private let DEBUG_TAG: String = "RemoteManager: "
    
    var remotes: [String: Remote] = [:] // [hostname:remote]
    
    weak var remotesViewController: ViewController?
    
    var remoteEventloopGroup: EventLoopGroup?
    
    /* if WarpRegistration receives a request BEFORE we detect a remote
     with that hostname, then store that IP address here so we can update that
     remote once it is detected   [hostname:ipaddress] */
    var ipPlaceHolders : [String:String] = [:]
    
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
    
    
    func removeRemote(withUUID uuid: String){
            print(DEBUG_TAG+"removing remote...")
        guard remotes[uuid] != nil else {
            print(DEBUG_TAG+"\t remote not found")
            return
        }
        
        remotes.removeValue(forKey: uuid)
        print(DEBUG_TAG+"\t remote removed")
        
    }
    
    
    func storeIPAddress(_ address: String, forHostname hostname: String){
        
        print(DEBUG_TAG+"storing address (\(address)) for \(hostname)")
        
        
        // TODO: this fails if two remotes share a hostname. Not good. No bueno.
        remotes.forEach { (key,remote) in
            if remote.details.hostname == hostname {
                print(self.DEBUG_TAG+"\tfound remote")
                remote.details.ipAddress = address
                remote.startConnection()
                return
            }
        }
        
        ipPlaceHolders[hostname] = address
        
//        if let remote = remotes[hostname] {
//            print(DEBUG_TAG+"Remote found, starting connection")
//            remote.details.ipAddress = address
//            remote.startConnection()
//        } else {
//
//        }
        
    }
    
    @discardableResult
    func containsRemote(for uuid: String) -> Remote? {
        
        if let remote = remotes.first(where: { (key, entry) in
            return entry.details.uuid == uuid })?.value {
            return remote
        }
        
        return nil
    }
    
    
}
