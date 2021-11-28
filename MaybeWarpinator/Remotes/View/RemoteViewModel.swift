//
//  RemoteViewModel.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-24.
//

import Foundation




//MARK: RemoteViewModel
class RemoteViewModel {
    
    private var remote: Remote
    var onInfoUpdated: ()->Void = {}
    
    public var displayName: String {
        return remote.details.displayName
    }
    
    public var userName: String {
        return remote.details.username + "@" + remote.details.hostname
    }
    
    public var iNetAddress: String {
        return remote.details.ipAddress + ":\(remote.details.port)"
    }
    
    public var uuid: String {
        return remote.details.uuid
    }
    
    public var status: String {
        return remote.details.status.rawValue
    }
    
    
    init(_ remote: Remote) {
        self.remote = remote
        remote.addObserver(self)
    }
    
    
    func updateInfo(){
            onInfoUpdated()
    }
    
    
    deinit {
        remote.removeObserver(self)
    }
}


