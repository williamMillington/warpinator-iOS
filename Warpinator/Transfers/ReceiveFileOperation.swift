//
//  ReceiveFileOperation.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-08.
//

import Foundation

import GRPC
import NIO


// MARK: ReceiveFileOperation
final class ReceiveFileOperation: TransferOperation {
    
    lazy var DEBUG_TAG: String = "ReceiveFileOperation (\(owningRemoteUUID),\(direction)): "
    
    
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
    var owningRemoteUUID: String {
        return request.info.ident
    }
    
    var direction: TransferDirection
    var status: TransferStatus {
        didSet {
            updateObserversInfo()
        }
    }
    
    var UUID: UInt64 { return timestamp }  
    var timestamp: UInt64
    
    var totalSize: Int
    var bytesTransferred: Int {
        
//        let currWriterBytes = currentWriter?.bytesWritten ?? 0
//        return currWriterBytes +
        //
        return fileWriters.map { return $0.bytesWritten }.reduce(0, +)
    }
    var bytesPerSecond: Double = 0
    var progress: Double {
        return Double(bytesTransferred) / Int(totalSize)
    }
    
    var spaceIsAvailable: Bool = false
    
    var cancelled: Bool = false
    
    var fileCount: Int = 1
    
    var directories: [String] = []
    
    var overwriteWarning: Bool = false
    
    var currentRelativePath: String = ""
    
    var fileWriters: [WritesFile] = []
    var currentWriter: WritesFile?
    
    
    var observers: [ObservesTransferOperation] = []
    
    
    lazy var queueLabel = "RECEIVE_\(owningRemoteUUID)_\(UUID)"
    lazy var receivingChunksQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    var dataStream: ServerStreamingCall<OpInfo, FileChunk>? = nil
    
    var operationInfo: OpInfo
    
    
    //MARK: init
    init(_ transferRequest: TransferOpRequest, forRemote remote: Remote){
        
        request = transferRequest
        owningRemote = remote
        
        direction = .RECEIVING
        status = .INITIALIZING
        
        
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
        
        print(DEBUG_TAG+" preparing to receive...")
        
        // check if space exists
        let availableSpace = Utils.queryAvailableDiskSpace()
        print(DEBUG_TAG+" available space \(availableSpace) vs transfer size \(totalSize)")
        guard availableSpace > totalSize else {
            print(DEBUG_TAG+"\t Not enough space"); return
        }
        
        print(DEBUG_TAG+"\t Space is available");
        
        // In case of retry
        bytesPerSecond = 0
        
        // reset filewriters
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
                print(self.DEBUG_TAG+"canceling chunk processing")
                return
            }
            
            
            let workItem = DispatchWorkItem() { [weak self] in
                
                guard let self = self else { return }
                
                //process the chunk
                print(self.DEBUG_TAG+" reading chunk:")
                print(self.DEBUG_TAG+"\t size: \(chunk.chunk.count )")
                print(self.DEBUG_TAG+"\t relativePath: \(chunk.relativePath)")
                print(self.DEBUG_TAG+"\t file/folder: \( TransferItemType(rawValue: chunk.fileType)!) ")
                
                // make sure we always update our observers
                defer {  self.updateObserversInfo()  }
                
                //
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
                if chunk.fileType == TransferItemType.DIRECTORY.rawValue {
                    
                    let writer = FolderWriter(withRelativePath: chunk.relativePath, overwrite: false )
                    self.currentWriter =  writer //FolderWriter(withRelativePath: chunk.relativePath, overwrite: false )
                    vm = ListedFolderWriterViewModel(writer)
                    
                } else { // If file
                    
//                    self.currentWriter = FileWriter(withRelativePath: chunk.relativePath, overwrite: false)
                    let writer = FileWriter(withRelativePath: chunk.relativePath, overwrite: false)
                    self.currentWriter = writer
                    vm = ListedFileWriterViewModel(writer)
                    
                    do {
                        try self.currentWriter?.processChunk(chunk)
                    } catch {
                        print(self.DEBUG_TAG+"Unexpected error: \(error)")
                    }
                }
                
                
                print(self.DEBUG_TAG+"\t file added")
                // Create writer to handle chunk
//                self.updateObserversFileAdded(vm)
                
                
                self.fileWriters.append(self.currentWriter!)
                self.updateObserversInfo()
                self.updateObserversFileAdded(vm)
            }
            
            
            self.receivingChunksQueue.async(execute: workItem)
            
//            self.receivingChunksQueue.async {
                
//                //process the chunk
//                print(self.DEBUG_TAG+" reading chunk:")
//                print(self.DEBUG_TAG+"\t size: \(chunk.chunk.count )")
//                print(self.DEBUG_TAG+"\t relativePath: \(chunk.relativePath)")
//                print(self.DEBUG_TAG+"\t file/folder: \( TransferItemType(rawValue: chunk.fileType)!) ")
//
//                // make sure we always update our observers
//                defer {  self.updateObserversInfo()  }
//
//                //
//                // if we've got a writer going, try it
//                if let writer = self.currentWriter {
//
//                    do {
//                        // Try to process the chunk
//                        try writer.processChunk(chunk)
//
//                        return // successfully processed (no errors)
//
//                    } catch WritingError.FILENAME_MISMATCH { // Names don't match, new file!,
//                        print(self.DEBUG_TAG+"New file!")
//
//                        // close old writer before proceeding on to create a new one
//                        writer.close()
//
//                    }
//                    catch {  print(self.DEBUG_TAG+"Unexpected error: \(error)")   }
//
//                }
//
//
//                // If folder
//                let vm: ListedFileViewModel
//                if chunk.fileType == TransferItemType.DIRECTORY.rawValue {
//
//                    let writer = FolderWriter(withRelativePath: chunk.relativePath, overwrite: false )
//                    self.currentWriter =  writer //FolderWriter(withRelativePath: chunk.relativePath, overwrite: false )
//                    vm = ListedFolderWriterViewModel(writer)
//
//                } else { // If file
//
////                    self.currentWriter = FileWriter(withRelativePath: chunk.relativePath, overwrite: false)
//                    let writer = FileWriter(withRelativePath: chunk.relativePath, overwrite: false)
//                    self.currentWriter = writer
//                    vm = ListedFileWriterViewModel(writer)
//
//                    do {
//                        try self.currentWriter?.processChunk(chunk)
//                    } catch {
//                        print(self.DEBUG_TAG+"Unexpected error: \(error)")
//                    }
//                }
//
//
//                print(self.DEBUG_TAG+"\t file added")
//                // Create writer to handle chunk
////                self.updateObserversFileAdded(vm)
//
//
//                self.fileWriters.append(self.currentWriter!)
//                self.updateObserversInfo()
//                self.updateObserversFileAdded(vm)
                
//            }
        }
        
        dataStream = datastream
        
        return datastream.status
            .flatMap { status in
                print(self.DEBUG_TAG+"\t transfer finished with status \(status)")
                
//                if status != .TRANSFERRING {
//                    receiveWasCancelled()
//                    return
//                }
                
                let closeWorkItem = DispatchWorkItem() {
                    self.currentWriter?.close()
                    self.status = .FINISHED
                    print(self.DEBUG_TAG+"\t\tFinished")
                }
                
                self.receivingChunksQueue.async(execute: closeWorkItem)
                
                return self.dataStream!.eventLoop.makeSucceededVoidFuture()
            }
            .flatMapError { error in
                print(self.DEBUG_TAG+"\t transfer failed: \(error)")
                self.receiveWasCancelled()
                return self.dataStream!.eventLoop.makeSucceededVoidFuture()
            }
    }
    
    
    //
    // MARK: finish
//    func finishReceive(){
//        print(DEBUG_TAG+" finishing")
//
//        if status != .TRANSFERRING {
//            receiveWasCancelled()
//            return
//        }
//
//        let closeWorkItem = DispatchWorkItem() {
//            self.currentWriter?.close()
//            self.status = .FINISHED
//            print(self.DEBUG_TAG+"\t\tFinished")
//        }
        
        
        //        currentWriter?.close()
        
        
        
//        status = .FINISHED
//        print(DEBUG_TAG+"\t\tFinished")
//    }

    
    
    //
    // MARK: stop
    // this side calls stop
    func orderStop(_ error: Error? = nil){
        print(self.DEBUG_TAG+"ordering stop, error: \(String(describing: error))")
        owningRemote?.stopTransfer(withUUID: UUID, error: error)
        stopRequested(error)
    }
    
    
    //
    // other side calls stop
    func stopRequested(_ error: Error? = nil){
        
        print(DEBUG_TAG+"stopped with error: \(String(describing: error))")
        
        if let error = error {
            status = .FAILED(error)
        } else {
            status = .CANCELLED
        }
        
    }
    
    
    func receiveWasCancelled(){
        
        print(DEBUG_TAG+" request cancelled")
        status = .CANCELLED
        
        // cancel current writing operation
        currentWriter?.fail()
    }
    
    
    
    
    
    //TODO: change this to be a single cancel, which can respond to an error of DECLINED
    
    
    
    
    //
    // MARK: decline
    func decline(_ error: Error? = nil){
        
        print(DEBUG_TAG+" declining request...")
        
        owningRemote?.informOperationWasDeclined(forUUID: UUID, error: error)
        status = .CANCELLED
        
        currentWriter?.fail()
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


