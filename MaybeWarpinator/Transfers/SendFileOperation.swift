//
//  SendFileOperation.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-15.
//

import Foundation

import GRPC
import NIO


// MARK: SendFileOperation
class SendFileOperation: TransferOperation {
    
    lazy var DEBUG_TAG: String = "SendFileOperation (\(remoteUUID)):"
    
    public static var chunk_size: Int = 1024 * 512  // 512 kB
    
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
    
    var UUID: UInt64 { return startTime }
    var startTime: UInt64
    
    var totalSize: Int {
        var bytes = 0
        
        for reader in fileReaders{
            bytes += reader.fileBytes.count
        }
        
        return bytes
    }
    
    var bytesTransferred: Int = 0
    var bytesPerSecond: Double = 0
    var progress: Double {
        return Double(bytesTransferred) / totalSize
    }
    
    
    var fileCount: Int = 0
    
    var singleName: String = ""
    var singleMime: String = ""
    
    var topDirBaseNames: [String] = []
    
    
    var files: [FileName]
    var fileReaders: [FileReader] = []
    
    
    var operationInfo: OpInfo {
        return .with {
            $0.ident = Server.SERVER_UUID
            $0.timestamp = startTime
            $0.readableName = Utils.getDeviceName()
        }
    }
    
    
    var transferRequest: TransferOpRequest {
        return .with {
            $0.info = operationInfo
            $0.senderName = Server.SERVER_UUID
            $0.size = UInt64(totalSize)
            $0.count = UInt64(fileCount)
            $0.nameIfSingle = singleName
            $0.mimeIfSingle = singleMime
            $0.topDirBasenames = topDirBaseNames
        }
    }
    
    
    
    var observers: [TransferOperationViewModel] = [] 
    
    lazy var queueLabel = "SEND_\(remoteUUID)_\(UUID)"
    lazy var sendingChunksQueue = DispatchQueue(label: queueLabel, qos: .utility)
    
    
    init(for filenames: [FileName] ) {
        
        direction = .SENDING
        status = .INITIALIZING
        startTime = UInt64( Date().timeIntervalSince1970 * 1000 )
        
        files = filenames
        
        fileCount = files.count
        
        singleName = "\(filenames.count) files"
        singleMime = "application/octet-stream"
        
        for filename in files {
            topDirBaseNames.append("\(filename.name).\(filename.ext)")
            fileReaders.append( FileReader(for: filename) )
        }
        
    }
    
    
    convenience init(for filename: FileName){
        self.init(for: [filename])
        
        singleName = fileReaders[0].relativeFilePath
        singleMime = fileReaders[0].fileExtension
    }
    
    
    // MARK: prepare
    func prepareToSend() {
        
        status = .INITIALIZING
        
        bytesTransferred = 0
        bytesPerSecond = 0
        
        for reader in fileReaders {
            reader.reset()
        }
        
        status = .WAITING_FOR_PERMISSION
        
    }
    
    
    
    //MARK: start
    func start(using context: StreamingResponseCallContext<FileChunk>) -> EventLoopPromise<GRPCStatus> {
        
        status = .TRANSFERRING
        
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

                do { // wait for result before sending next chunk
                    try result.wait()
                } catch {
                    print(self.DEBUG_TAG+"chunk prevented from waiting. Reason: \(error)")
                    self.orderStop( error )
                }
                
                result.whenSuccess { result in
                    print(self.DEBUG_TAG+"chunk \(i) (\(chunk.relativePath))  transmission success \(result)")
                }

                result.whenFailure { error in
                    print(self.DEBUG_TAG+"chunk \(i) (\(chunk.relativePath))  transmission failed: ")
                    print(self.DEBUG_TAG+"\t error: \(error)")
                }
            }
            
            promise.succeed(.ok)
        }
        
        // when entire transfer is completed
        context.closeFuture.whenComplete { result in
            print(self.DEBUG_TAG+"TransferOperation completed with result: \(result)")
            
            do {
                try result.get()
                self.status = .FINISHED
            } catch {
                self.status = .CANCELLED
            }
        }
        
        return promise
    }
    
    
    //MARK: stop
    func orderStop(_ error: Error? = nil){
        
        print(self.DEBUG_TAG+"ordering stop, error: \(String(describing: error))")
        owningRemote?.callClientStopTransfer(self, error: error)
        stopRequested(error)
        
    }
    
    
    func stopRequested(_ error: Error? = nil){
        print(DEBUG_TAG+"stopped with error: \(String(describing: error))")
        
        if let error = error {
            status = .FAILED(error)
        } else {
            status = .CANCELLED
        }
        
    }
    
    
    func onDecline(_ error: Error? = nil){
        print(DEBUG_TAG+"operation was declined")
        status = .CANCELLED
    }
    
}




//MARK: observers
extension SendFileOperation {
    
    func addObserver(_ model: TransferOperationViewModel){
        observers.append(model)
    }
    
    func removeObserver(_ model: TransferOperationViewModel){
        
        for (i, observer) in observers.enumerated() {
            if observer === model {
                observers.remove(at: i)
            }
        }
    }
    
    func updateObserversInfo(){
        observers.forEach { observer in
            observer.updateInfo()
        }
    }
}

