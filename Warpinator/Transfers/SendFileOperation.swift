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
    // computer
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
    
    var  sendingChunksQueueDispatchItems: [DispatchWorkItem] = []
    
    var transferPromise: EventLoopPromise<GRPCStatus>? = nil
    
    
    // MARK: init
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
    func start(using context: StreamingResponseCallContext<FileChunk>) -> EventLoopFuture<GRPCStatus> {
        
        status = .TRANSFERRING
        lastTransferTimeStamp = Date().timeIntervalSince1970 * 1000
        
        let promise = context.eventLoop.makePromise(of: GRPCStatus.self)
        let chunkIterator = ChunkIterator(for: fileReaders)
        
        promise.futureResult.whenSuccess { status in
            switch status {
            case STATUS_CANCELLED: self.status = .CANCELLED
            case .ok: self.status = .FINISHED
            default: break
            }
        }
        
        
        
        self.transferPromise = promise
        
        
        context.closeFuture.whenComplete { result in
            print(self.DEBUG_TAG+"\tOperation closed with result: \(result)")

            switch result {
            case .success():
                self.status = (self.status != .TRANSFERRING) ? self.status : .FINISHED
            case .failure(let error):
                self.status = .FAILED(error)
            }

            // cleanup call
            self.fileReaders.forEach { $0.close() }
            self.transferPromise = nil
        }
        
        
        
        chunkIterator.enumerated().forEach { (i, chunk) in
            
            // create a work item
            let workItem = DispatchWorkItem() { [weak self] in
                
                do {
                    try context.sendResponse(chunk).map { Void in
                        
                        // calculate bytes per second
                        let now = Date().timeIntervalSince1970 * 1000
                        self?.bytesTransferred += chunk.chunk.count
                        self?.bytesPerSecond = (chunk.chunk.count / (now - (self?.lastTransferTimeStamp ?? 0.0)) / 1000)
                        self?.lastTransferTimeStamp = now

                        self?.updateObserversInfo()
                    }.wait()
                    
                } catch {
//                    promise.fail(error)
//                    self?.status = .FAILED(error)
                    self?.stop(error)
                }
                
                self?.updateObserversInfo()
            }
            
            sendingChunksQueueDispatchItems.append(workItem)
        }
        
        // last item in the queue will inform caller of success
        let finalWorkItem = DispatchWorkItem { [weak self] in
            promise.succeed(.ok)
            self?.updateObserversInfo()
        }
        
        sendingChunksQueueDispatchItems.append(finalWorkItem)
        
        sendingChunksQueueDispatchItems.forEach { self.sendingChunksQueue.async(execute: $0) }
        
        
//        self.transferPromise = promise
       
        
        return promise.futureResult
        
    }
    
    //
    // MARK: stopping
    func stop(_ error: Error){
        
        print(self.DEBUG_TAG+"\tStop Sending. Error: \(String(describing: error))")
        
        sendingChunksQueueDispatchItems.forEach { $0.cancel() }
        sendingChunksQueueDispatchItems.removeAll()
        
        fileReaders.forEach { $0.close() }
        
        if (error as? TransferError) == .TransferCancelled {
            transferPromise?.succeed(STATUS_CANCELLED)
        } else {
            transferPromise?.fail(error)
        }
        
        status = .FAILED(error)
    }
    
    //
    // MARK: onDecline
    func onDecline(_ error: Error? = nil){
//        print(DEBUG_TAG+"operation was declined")
//        status = .CANCELLED
////        closeOutOperation()
//        fileReaders.forEach { $0.close() }
//        updateObserversInfo()
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

