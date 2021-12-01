//
//  ReceiveTransferViewModel.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-29.
//

import Foundation




class ReceiveTransferViewModel {
    
    let operation: TransferOperation
    let remote: Remote
    
    var deviceName: String {
        return remote.details.displayName
    }
    
    
    init(operation: TransferOperation, from remote: Remote){
        self.operation = operation
        self.remote = remote
    }
    
}

