//
//  TransfersCommon.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-12.
//
import Foundation



// MARK: FileType
enum FileType: Int32 {
    case FILE = 1
    case DIRECTORY = 2
}


// MARK: FileName
typealias FileName = (name: String, ext: String)




// MARK: TransferError
enum TransferError: Error {
    case ConnectionInterrupted
    case PermissionDeclined
    case TransferCancelled
    case TransferNotFound
    case UnknownError
}


// MARK: TransferDirection
public enum TransferDirection: String {
    case SENDING, RECEIVING
}


// MARK: TransferStatus
enum TransferStatus: Equatable {
    
    static func == (lhs: TransferStatus, rhs: TransferStatus) -> Bool {
        
        switch (lhs, rhs){
        
        case (INITIALIZING, INITIALIZING),
             (WAITING_FOR_PERMISSION,WAITING_FOR_PERMISSION),
             (CANCELLED, CANCELLED),
             (TRANSFERRING, TRANSFERRING),
             (STOPPED, STOPPED),
             (FINISHED, FINISHED): return true
        case (let FAILED(error1), let FAILED(error2) ):
            return error1.localizedDescription == error2.localizedDescription
        case (INITIALIZING,_),
             (WAITING_FOR_PERMISSION,_),
             (CANCELLED, _),
             (TRANSFERRING,_),
             (STOPPED,_),
             (FINISHED,_),
             (FAILED(_),_): return false
        }
    }
    
    case INITIALIZING
    case WAITING_FOR_PERMISSION
    case CANCELLED
    case TRANSFERRING, STOPPED, FINISHED
    case FAILED(Error)
}


// MARK: TransferOperation
protocol TransferOperation {
    
    var owningRemote: Remote? { get set }
    
    var UUID: UInt64 { get }
    
    var direction: TransferDirection { get }
    var fileCount: Int { get }
    var status: TransferStatus { get }
    var progress: Double { get }
    
    var operationInfo: OpInfo { get }
    
    var observers: [TransferOperationViewModel] { get }
    
    func orderStop(_ error: Error?)
    func stopRequested(_ error: Error?)
    
    
    func addObserver(_ model: TransferOperationViewModel)
    func removeObserver(_ model: TransferOperationViewModel)
    func updateObserversInfo()
}
 



// MARK: Mock TransferOperation
class MockReceiveTransfer: TransferOperation { 
    
    var owningRemote: Remote?
    
    var UUID: UInt64
    
    var direction: TransferDirection
    
    var fileCount: Int
    
    var status: TransferStatus
    
    var progress: Double
    
    var observers: [TransferOperationViewModel] = []
    
    var operationInfo: OpInfo {
        return .with {
            $0.ident = Server.SERVER_UUID
            $0.timestamp = UUID
            $0.readableName = Utils.getDeviceName()
        }
    }
    
    init(){
        owningRemote = Remote(details: RemoteDetails.MOCK_DETAILS )
        
        // random number
        UUID = 0 + UInt64.random(in: 0...9) + UInt64.random(in: 0...9) + UInt64.random(in: 0...9) + UInt64.random(in: 0...9)
        
        direction = .RECEIVING
        fileCount = 1
        status = .WAITING_FOR_PERMISSION
        progress = 0
        
    }
    
    
    func orderStop(_ error: Error? = nil){
        status = .STOPPED
    }
    
    func stopRequested(_ error: Error? = nil){
        status = .STOPPED
    }
    
    
    func addObserver(_ model: TransferOperationViewModel) {
        
    }
    
    func removeObserver(_ model: TransferOperationViewModel) {
        
    }
    
    func updateObserversInfo() {
        
    }
    
    
}
