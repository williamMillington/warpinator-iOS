//
//  RemoteManager.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-17.
//

import Foundation
import Network



class RemoteManager {
    
    
    var remotes: [String: RegisteredRemote] = [:]
    
    
    func addRemote(_ remote: RegisteredRemote){
        
        remotes[remote.details.uuid] = remote
        
    }
    
    func removeRemote(withUUID uuid: String){
        
        guard remotes[uuid] != nil else {
            return
        }
        
        remotes.removeValue(forKey: uuid)
        
    }
    
    
    @discardableResult
    func containsRemote(for uuid: String) -> RegisteredRemote? {
        
        if let remote = remotes.first(where: { (key, entry) in
            return entry.details.uuid == uuid })?.value {
            return remote
        }
        
        return nil
    }
    
    
}
