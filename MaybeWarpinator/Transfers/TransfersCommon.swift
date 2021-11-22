//
//  TransfersCommon.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-12.
//
import Foundation


enum TransferError: Error {
    case TransferNotFound
    case TransferInterrupted
}

enum FileType: Int32 {
    case FILE = 1
    case DIRECTORY = 2
}


public enum TransferDirection: String {
    case SENDING, RECEIVING
}


enum TransferStatus {
    case INITIALIZING
    case WAITING_FOR_PERMISSION, PERMISSION_DECLINED
    case TRANSFERRING, PAUSED, STOPPED, FINISHED, FINISHED_WITH_ERRORS
    case FAILED
}



protocol TransferOperation {
    
    var owningRemote: Remote? { get set }
    var direction: TransferDirection { get }
    var fileCount: Int { get }
    var status: TransferStatus { get }
    var progress: Double { get }
}



class TransferOperationViewModel {
    
    private var operation: TransferOperation
    
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
    }
    
    
}
