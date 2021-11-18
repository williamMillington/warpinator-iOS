//
//  RemoteManager.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-17.
//

import Foundation
import Network



class RemoteManager {
    
    private let DEBUG_TAG: String = "RemoteManager: "
    
    var remotes: [String: Remote] = [:]
    
    weak var remotesViewController: ViewController?
    
    
    func addRemote(_ remote: Remote){
        print(DEBUG_TAG+"adding remote")
        remotes[remote.details.uuid] = remote
        
//        remote.register()
        
        let viewmodel = RemoteViewModel(remote)
        
        remotesViewController?.connectionAdded(viewmodel)
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
    
    
    @discardableResult
    func containsRemote(for uuid: String) -> Remote? {
        
        if let remote = remotes.first(where: { (key, entry) in
            return entry.details.uuid == uuid })?.value {
            return remote
        }
        
        return nil
    }
    
    
}
