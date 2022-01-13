//
//  TransfersCommon.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-12.
//
import Foundation



// MARK: FileType
enum TransferItemType: Int32 {
    case FILE = 1
    case DIRECTORY = 2
}


//protocol TransferSelection {
//    var type: TransferItemType { get }
//    var name: String     { get }
//    var bytesCount: Int  { get }
//
//    var path: String     { get }
//    var bookmark: Data   { get }
//}


struct TransferSelection: Hashable {
    
    var type: TransferItemType
    var name: String
    var bytesCount: Int
    
    var path: String
    var bookmark: Data
    
    var reader: ReadsFile? {
        
        if type == .FILE {
            let sel = FileSelection(name: name, bytesCount: bytesCount, path: path, bookmark: bookmark)
            return FileReader(for: sel)
        }
        
        let sel = FolderSelection(name: name, path: path, bookmark: bookmark)
        return FolderReader(for: sel)
        
    }
}

extension TransferSelection: Equatable {
    static func ==(lhs: TransferSelection, rhs: TransferSelection) -> Bool {
        return lhs.path == rhs.path
    }
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
             (FINISHED, FINISHED): return true
        case (let FAILED(error1), let FAILED(error2) ):
            return error1.localizedDescription == error2.localizedDescription
        case (INITIALIZING,_),
             (WAITING_FOR_PERMISSION,_),
             (CANCELLED, _),
             (TRANSFERRING,_),
             (FINISHED,_),
             (FAILED(_),_): return false
        }
    }
    
    case INITIALIZING
    case WAITING_FOR_PERMISSION
    case CANCELLED
    case TRANSFERRING, FINISHED
    case FAILED(Error)
}





// MARK: TransferOperation
protocol TransferOperation {
    
    var owningRemote: Remote? { get set }
    
    var UUID: UInt64 { get }
    
    var direction: TransferDirection { get }
    var fileCount: Int { get }
    var status: TransferStatus { get }
    
    var totalSize: Int { get }
    var bytesTransferred: Int { get }
    var bytesPerSecond: Double { get }
    
    var progress: Double { get }
    
    var operationInfo: OpInfo { get }
    
    var observers: [ObservesTransferOperation] { get }
    
    func orderStop(_ error: Error?)
    func stopRequested(_ error: Error?)
    
    
    func addObserver(_ model: ObservesTransferOperation)
    func removeObserver(_ model: ObservesTransferOperation)
//    func updateObserversInfo()
}
 



// MARK: Mock TransferOperation
class MockReceiveTransfer: TransferOperation {
    
    var owningRemote: Remote?
    
    var UUID: UInt64
    
    var direction: TransferDirection
    
    var fileCount: Int
    
    var status: TransferStatus
    
    var totalSize: Int {return 343433}
    var bytesTransferred: Int {return 5433}
    var bytesPerSecond: Double {
        return 400
    }
    
    var progress: Double
    
    var observers: [ObservesTransferOperation] = []
    
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
        status = .CANCELLED
    }
    
    func stopRequested(_ error: Error? = nil){
        status = .CANCELLED
    }
    
    
    func addObserver(_ model: ObservesTransferOperation) {
        
    }
    
    func removeObserver(_ model: ObservesTransferOperation) {
        
    }
    
    func updateObserversInfo() {
        
    }
    
    
}
