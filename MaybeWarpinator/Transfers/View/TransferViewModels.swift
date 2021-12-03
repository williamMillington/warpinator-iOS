//
//  TransferViewModels.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-24.
//

import Foundation


class TransferOperationViewModel {
    
    private var operation: TransferOperation
    
    var onInfoUpdated: ()->Void = {}
    
    var UUID: UInt64 {
        return operation.UUID
    }
    
    var fileCount: Int {
        return operation.fileCount
    }
    
    var progress: Double {
        return operation.progress
    }
    
    var status: TransferStatus {
        return operation.status
    }
    
    var direction: TransferDirection {
        return operation.direction
    }
    
    init(for operation: TransferOperation) {
        self.operation = operation
        operation.addObserver(self)
    }
    
    
    func updateInfo(){
        DispatchQueue.main.async { // execute UI on main thread 
            self.onInfoUpdated()
        }
    }
    
    deinit {
        operation.removeObserver(self)
    }
}
