//
//  SendFileOperation.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-15.
//

import Foundation

import GRPC
import NIO


//
// MARK: SendFileOperation
final class SendFileOperation: TransferOperation {
    
    lazy var DEBUG_TAG: String = "SendFileOperation (\(remoteUUID)):"
    
    public static let chunk_size: Int = 1024 * 512  // 512 kB
    
    var direction: TransferDirection
    var status: TransferStatus {
        didSet {
            updateObserversInfo()
        }
    }
    
    weak var owningRemote: Remote?
    var remoteUUID: String {
        guard let owningRemote = owningRemote else {
            return "Owning remote not set"
        }
        return owningRemote.details.uuid
    }
    
    var UUID: UInt64 { return timestamp }
    var timestamp: UInt64
    
    var totalSize: Int {
        var bytes = 0
        
        for file in files {
            bytes += file.bytesCount
        }
        
        return bytes
    }
    
    var bytesTransferred: Int = 0
    var progress: Double {
        return Double(bytesTransferred) / totalSize
    }
    
    var lastTransferTimeStamp: Double = 0
    var bytesPerSecond: Double = 0
    
    
    var fileCount: Int = 0
    
    var singleName: String = ""
    var singleMime: String = ""
    
    var topDirBaseNames: [String] = []
    
    
    var files: [TransferSelection]
    var fileReaders: [ReadsFile] = []
    
    
    var operationInfo: OpInfo {
        return .with {
            $0.ident = SettingsManager.shared.uuid
            $0.timestamp = timestamp
            $0.readableName = SettingsManager.shared.displayName 
        }
    }
    
    // MARK: TransferOpRequest
    var transferRequest: TransferOpRequest {
        return .with {
            $0.info = operationInfo
            $0.senderName = SettingsManager.shared.displayName
            $0.size = UInt64(totalSize)
            $0.count = UInt64(fileCount)
            $0.nameIfSingle = singleName
            $0.mimeIfSingle = singleMime
            $0.topDirBasenames = topDirBaseNames
        }
    }
    
    
    var observers: [ObservesTransferOperation] = [] 
    
    lazy var queueLabel = "SEND_\(remoteUUID)_\(UUID)"
    lazy var sendingChunksQueue = DispatchQueue(label: queueLabel, qos: .utility)
    
    
    
    init(for filenames: [TransferSelection] ) {
        
        direction = .SENDING
        status = .INITIALIZING
        timestamp = UInt64( Date().timeIntervalSince1970 * 1000 )
        
        files = filenames
        
        fileCount = files.count
        
        singleName = "\(files.count) file" + (files.count == 1 ? "" : "s")
        singleMime = "application/octet-stream"
        
        for selection in files {
            
            topDirBaseNames.append("\(selection.name)")
            
            if let reader = selection.reader {
                fileReaders.append( reader   )
            } else {
                print(DEBUG_TAG+"(init) problem accessing selection \(selection.name)")
            }
        }
        
    }
    
    
    convenience init(for selection: TransferSelection){
        self.init(for: [selection])
        
        singleName = selection.name
        singleMime = "mime"
    }
    
    
    //
    // MARK: prepare
    func prepareToSend() {
        
        status = .INITIALIZING
        
        bytesTransferred = 0
        
        fileReaders.removeAll()
        
        for selection in files {
            if let reader = selection.reader {
                fileReaders.append( reader   )
            } else {
                print(DEBUG_TAG+"(prep) problem accessing selection \(selection.name)")
            }
        }
        
        status = .WAITING_FOR_PERMISSION
    }
    
    
    
    //
    //MARK: start
    func start(using context: StreamingResponseCallContext<FileChunk>) -> EventLoopPromise<GRPCStatus> {
        
        status = .TRANSFERRING
        lastTransferTimeStamp = Date().timeIntervalSince1970 * 1000
        
        let promise = context.eventLoop.makePromise(of: GRPCStatus.self)
        let chunkIterator = ChunkIterator(for: fileReaders)
        
        
        sendingChunksQueue.async {
            
            for (i, chunk) in chunkIterator.enumerated() {
                
                if self.status != .TRANSFERRING {
                    promise.fail( TransferError.TransferCancelled )
                    return
                }
                
                print(self.DEBUG_TAG+"sending chunk \(i) (\(chunk.relativePath))")
                let result = context.sendResponse(chunk)

                do {
                    // wait for result before sending next chunk
                    // if we don't do this, then the chunks can end up out of order on
                    // troublesome networks, which causes failure
                    try result.wait()
                } catch {
                    print(self.DEBUG_TAG+"chunk \(i) prevented from waiting. Reason: \(error)")
                    if self.status == .TRANSFERRING {  self.orderStop( error ) }
                }
                
                
                //
                result.whenSuccess { result in
                    
                    // calculate bytes per second
                    let now = Date().timeIntervalSince1970 * 1000
                    self.bytesTransferred += chunk.chunk.count
                    self.bytesPerSecond = (chunk.chunk.count / (now - self.lastTransferTimeStamp) / 1000)
                    self.lastTransferTimeStamp = now
                    
                    self.updateObserversInfo()
                }

                result.whenFailure { error in
                    print(self.DEBUG_TAG+"chunk \(i) (\(chunk.relativePath))  transmission failed: ")
                    print(self.DEBUG_TAG+"\t error: \(error)")
                    
                    if self.status == .TRANSFERRING {  self.stopRequested(error) }
                    
                }
            }
            
            promise.succeed(.ok)
        }
        
        
        // when entire transfer is completed
        context.closeFuture.whenComplete { result in
            print(self.DEBUG_TAG+"TransferOperation completed with result: \(result)")
            
            do {
                // prevent a successful call-finish from overwriting an earlier .FAILED status
                if self.status != .TRANSFERRING { return }
                try result.get()
                self.status = .FINISHED
                
            } catch {
//                self.status = .CANCELLED
                self.stopRequested(error)
            }
        }
        
        return promise
    }
    
    
    //
    // MARK: stopping
    func orderStop(_ error: Error? = nil){
        
        print(self.DEBUG_TAG+"ordering stop, error: \(String(describing: error))")
        owningRemote?.requestStop(forOperationWithUUID: UUID, error: error)
        stopRequested(error)
        
    }
    
    //
    //
    func stopRequested(_ error: Error? = nil){
        print(DEBUG_TAG+"stopped with error: \(String(describing: error))")
        
        if let error = error {
            status = .FAILED(error)
        } else {
            status = .CANCELLED
        }
        closeOutOperation()
    }
    
    
    //
    // MARK: onDecline
    func onDecline(_ error: Error? = nil){
        print(DEBUG_TAG+"operation was declined")
        status = .CANCELLED
        closeOutOperation()
    }
    
    
    //
    // MARK: closeOutOperation
    func closeOutOperation(){
        
        fileReaders.forEach { reader in
            reader.close()
        }
        
    }
    
}



//
//MARK: - observers
extension SendFileOperation {
    
    func addObserver(_ model: ObservesTransferOperation){
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
}

