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
    
    
    var fileCount: Int {
        return operation.fileCount
    }
    
    var progress: Double {
        return operation.progress
    }
    
    var status: TransferStatus {
        return operation.status
    }
    
    init(for operation: TransferOperation) {
        self.operation = operation
        operation.addObserver(self)
    }
    
    
    func updateInfo(){
        onInfoUpdated()
    }
    
    deinit {
        operation.removeObserver(self)
    }
}
