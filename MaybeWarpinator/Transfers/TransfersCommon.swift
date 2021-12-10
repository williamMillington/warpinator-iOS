//
//  TransfersCommon.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-12.
//
import Foundation


enum TransferError: Error {
    case ConnectionInterrupted
    case PermissionDeclined
    case TransferCancelled
    case TransferNotFound
}


enum FileType: Int32 {
    case FILE = 1
    case DIRECTORY = 2
}


typealias FileName = (name: String, ext: String)


public enum TransferDirection: String {
    case SENDING, RECEIVING
}


enum TransferStatus: Equatable {
    
    static func == (lhs: TransferStatus, rhs: TransferStatus) -> Bool {
        
        switch (lhs, rhs){
        
        case (.INITIALIZING, .INITIALIZING),
             (.WAITING_FOR_PERMISSION, .WAITING_FOR_PERMISSION),
             (.TRANSFERRING, .TRANSFERRING),
             (.STOPPED, .STOPPED),
             (.FINISHED, .FINISHED): return true
        case (let .FAILED(error1), let .FAILED(error2) ):
            return error1.localizedDescription == error2.localizedDescription
        case (.INITIALIZING,_),
             (.WAITING_FOR_PERMISSION,_),
             (.TRANSFERRING,_),
             (.STOPPED,_),
             (.FINISHED,_),
             (.FAILED(_),_): return false
        }
    }
    
    
    case INITIALIZING
    case WAITING_FOR_PERMISSION
    case TRANSFERRING, STOPPED, FINISHED
    case FAILED(Error)
}



protocol TransferOperation {
    
    var owningRemote: Remote? { get set }
    
    var UUID: UInt64 { get }
    
    var direction: TransferDirection { get }
    var fileCount: Int { get }
    var status: TransferStatus { get }
    var progress: Double { get }
    
    var observers: [TransferOperationViewModel] { get }
    
    func addObserver(_ model: TransferOperationViewModel)
    func removeObserver(_ model: TransferOperationViewModel)
    func updateObserversInfo()
}
 



class MockReceiveTransfer: TransferOperation { 
    
    var owningRemote: Remote?
    
    var UUID: UInt64
    
    var direction: TransferDirection
    
    var fileCount: Int
    
    var status: TransferStatus
    
    var progress: Double
    
    var observers: [TransferOperationViewModel]
    
    
    init(){
        owningRemote = Remote(details: RemoteDetails.MOCK_DETAILS )
        
        // random number
        UUID = 0 + UInt64.random(in: 0...9) + UInt64.random(in: 0...9) + UInt64.random(in: 0...9) + UInt64.random(in: 0...9)
        
        direction = .RECEIVING
        fileCount = 1
        status = .WAITING_FOR_PERMISSION
        progress = 0
        
        observers = []
    }
    
    
    func addObserver(_ model: TransferOperationViewModel) {
        
    }
    
    func removeObserver(_ model: TransferOperationViewModel) {
        
    }
    
    func updateObserversInfo() {
        
    }
    
    
}
