//
//  ReceiveFileOperation.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-08.
//

import Foundation

import GRPC
import NIO



let STATUS_CANCELLED = GRPCStatus.init(code: GRPCStatus.Code.cancelled, message:"Transfer Cancelled")



// MARK: ReceiveFileOperation
final class ReceiveFileOperation: TransferOperation {
    
    lazy var DEBUG_TAG: String = "ReceiveFileOperation (\(owningRemote?.details.uuid ?? "Owning remote not set")): "
    
    
    struct MockOperation {
        static func make(for remote: Remote) -> ReceiveFileOperation {
            
            let opinfo = OpInfo.with {
                $0.ident = remote.details.uuid
                $0.readableName = remote.details.displayName
                $0.timestamp = UInt64( Date().timeIntervalSince1970 * 1000 )
                $0.useCompression = false
            }
            
            let mockTrOpRequest = TransferOpRequest.with {
                $0.info = opinfo
                $0.size = UInt64(1598)
                $0.count =  UInt64( Double( Int.random(in: 0...4)))
                $0.topDirBasenames = ["topdirbasename"]
            }
            
            return ReceiveFileOperation(mockTrOpRequest, forRemote: remote)
        } 
    }
    
    
    private let chunk_size: Int = 1024 * 512  // 512 KB
    
    var request: TransferOpRequest
    
    weak var owningRemote: Remote?
    
    var direction: TransferDirection = .RECEIVING
    var status: TransferStatus = .INITIALIZING {
        didSet {
            updateObserversInfo()
        }
    }
    
    var UUID: UInt64 { return timestamp }  
    var timestamp: UInt64
    
    var totalSize: Int
    var bytesTransferred: Int {
        return fileWriters.map { return $0.bytesWritten }.reduce(0, +)
    }
    var bytesPerSecond: Double = 0
    
    var fileCount: Int = 1
    
    var directories: [String] = []
    
    var overwriteWarning: Bool = false
    
    var currentRelativePath: String = ""
    
    var fileWriters: [WritesFile] = []
    var currentWriter: WritesFile?
    
    
    var observers: [ObservesTransferOperation] = []
    
    
    lazy var queueLabel = "RECEIVE_\(owningRemote?.details.uuid ?? "\(Int.random(in: 0...9999))")_\(UUID)"
    lazy var receivingChunksQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    var  receivingChunksQueueDispatchItems: [DispatchWorkItem] = []
    var dataStream: ServerStreamingCall<OpInfo, FileChunk>? = nil
    
    var operationInfo: OpInfo
    
    
    //MARK: init
    init(_ transferRequest: TransferOpRequest, forRemote remote: Remote){
        
        request = transferRequest
        owningRemote = remote
        
        timestamp = transferRequest.info.timestamp
        totalSize = Int(transferRequest.size)
        fileCount = Int(transferRequest.count)
        
        directories = transferRequest.topDirBasenames
        
        operationInfo = .with {
            $0.ident = SettingsManager.shared.uuid
            $0.timestamp = transferRequest.info.timestamp
            $0.readableName = SettingsManager.shared.displayName
        }
    }
}



//MARK: - Receive
extension ReceiveFileOperation {
    
    
    //MARK: prepare
    func prepareReceive(){
        
        print(DEBUG_TAG+"preparing to receive...")
        
        // check if space exists
        let availableSpace = Utils.queryAvailableDiskSpace()
        print(DEBUG_TAG+"\t\tavailable space \(availableSpace) vs transfer size \(totalSize)")
        guard availableSpace > totalSize else {
            print(DEBUG_TAG+"\t Not enough space"); return
        }
        
//        print(DEBUG_TAG+"\t Space is available");
        
        // reset
        bytesPerSecond = 0
        fileWriters = []
        currentRelativePath = ""
        currentWriter = nil
        
        dataStream = nil
        
        status = .WAITING_FOR_PERMISSION
        
        updateObserversInfo()
        
    }
    
    
    //MARK: start
    func startReceive(usingClient client: WarpClient) -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+" starting receive operation")
        
        status = .TRANSFERRING
        
        let datastream = client.startTransfer(self.operationInfo) { chunk in
            
            guard self.status == .TRANSFERRING else {
                print(self.DEBUG_TAG+"cancelling chunk processing")
                self.stop( TransferError.TransferCancelled )
                return
            }
            
            
            let workItem = DispatchWorkItem() { [weak self] in
                
                guard let self = self else { return }
                
                // make sure we always update our observers
                defer {  self.updateObserversInfo()  }
                
                
                // if we've got a writer going, try it
                if let writer = self.currentWriter {
                    
                    do {
                        // Try to process the chunk
                        try writer.processChunk(chunk)
                        
                        return // successfully processed (no errors)
                        
                    } catch WritingError.FILENAME_MISMATCH { // Names don't match, new file!,
                        print(self.DEBUG_TAG+"New file!")
                        
                        // close old writer before proceeding on to create a new one
                        writer.close()
                        
                    }
                    catch {  print(self.DEBUG_TAG+"Unexpected error: \(error)")   }
                }
                
                
                // If folder
                let vm: ListedFileViewModel
                let writer: WritesFile
                if chunk.fileType == TransferItemType.DIRECTORY.rawValue {
                    
                    let folderWriter = FolderWriter(withRelativePath: chunk.relativePath, overwrite: false )
                    writer = folderWriter
                    vm = ListedFolderWriterViewModel(folderWriter)
                    
                } else { // If file
                    
                    let fileWriter = FileWriter(withRelativePath: chunk.relativePath, overwrite: false)
                    writer = fileWriter
                    vm = ListedFileWriterViewModel(fileWriter)
                    
                    do {
                        try writer.processChunk(chunk)
                    } catch {
                        print(self.DEBUG_TAG+"Unexpected error: \(error)")
                    }
                }
                
                
                print(self.DEBUG_TAG+"\t file added")
                // Create writer to handle chunk
                self.currentWriter = writer
                self.fileWriters.append(writer)
                self.updateObserversFileAdded(vm)
            }
            
            
            self.receivingChunksQueueDispatchItems.append(workItem)
            
            self.receivingChunksQueue.async(execute: workItem)
            
        }
        
        dataStream = datastream
        
        
        return datastream.status
            .flatMapThrowing { status in
                
                defer { self.updateObserversInfo() }
                
                print(self.DEBUG_TAG+"\t transfer finished with status \(status)")
                
                guard status.code != .unavailable else {
                    throw TransferError.ConnectionInterruption
                }
                
                
                switch status {
                case STATUS_CANCELLED:
                    throw TransferError.TransferCancelled
                case .processingError:
                    throw TransferError.UnknownError
                default:
                    self.status = .FINISHED
                    self.currentWriter?.close()
                }
                
            }
            .flatMapError { error in
                
                defer { self.updateObserversInfo() }
                
                print(self.DEBUG_TAG+"\t transfer failed: \(error)")
                
                switch error {
                case TransferError.TransferCancelled: self.status = .CANCELLED
                default:
                    self.status = .FAILED(error)
                }
                
                self.receivingChunksQueue.async {
                    self.stop(error)
                }
                
                return datastream.eventLoop.makeFailedFuture(error)
            }
    }
    
    
    
    //
    // MARK: stop
    // stop the transfer
    func stop(_ error: Error){
        
        defer {   self.updateObserversInfo()   }
        
        
        print(self.DEBUG_TAG+"stop receiving, error: \(String(describing: error))")
        
        
        // only proceed with stop if we're not already stopped
        guard [ .TRANSFERRING, .WAITING_FOR_PERMISSION, .INITIALIZING ].contains( status ) else {
            return
        }
        
        let cancelled = (error as? TransferError) == .TransferCancelled ? true : false
        
        
        receivingChunksQueueDispatchItems.forEach { $0.cancel() }
        receivingChunksQueueDispatchItems.removeAll()
        
        currentWriter?.fail()
        
        
        status = cancelled ? .CANCELLED : .FAILED(error)
        
        
        // this stop may have been initiated by us,
        // so remind sender to stop sending
        owningRemote?.sendStop(withStopInfo:  .with {
            $0.info = operationInfo
            $0.error = !cancelled // "Cancelled" is only considered an error internally
        })
        
    }
}



//
//MARK: Observers
extension ReceiveFileOperation {
    
    func addObserver(_ model: ObservesTransferOperation){
        
        print(DEBUG_TAG+"\t added observer")
        observers.append(model)
    }
    
    func removeObserver(_ model: ObservesTransferOperation){
        
        for (i, observer) in observers.enumerated() {
            if observer === model {
                observers.remove(at: i)
            }
        }
    }     
    
    func updateObserversInfo(){
        observers.forEach { observer in
            observer.infoDidUpdate()
        }
    }
    
    func updateObserversFileAdded(_ vm: ListedFileViewModel){
        observers.forEach { observer in
            observer.fileAdded(vm)
        }
    }
}


