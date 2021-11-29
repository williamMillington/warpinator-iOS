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
    var onTransferAdded: (TransferOperationViewModel)->Void = { viewmodel in }
    
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
    
    
    public var transfers: [TransferOperationViewModel] {

        var viewmodels:[TransferOperationViewModel] = []
        let operations: [TransferOperation] = remote.sendingOperations + remote.receivingOperations

        for operation in operations  {
            viewmodels.append( TransferOperationViewModel(for: operation) )
        }

        return viewmodels
    }
    
    
    init(_ remote: Remote) {
        self.remote = remote
        remote.addObserver(self)
    }
    
    
    func updateInfo(){
        DispatchQueue.main.async { // execute UI on main thread
            self.onInfoUpdated()
        }
    }
    
    func transferOperationAdded(_ operation: TransferOperation){
        DispatchQueue.main.async { // execute UI on main thread
            self.onTransferAdded(TransferOperationViewModel(for: operation))
        }
    }
    
    deinit {
        remote.removeObserver(self)
    }
}


