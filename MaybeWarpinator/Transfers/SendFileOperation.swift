//
//  SendFileOperation.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-15.
//

import Foundation

import GRPC



// MARK: SendFileOperation
class SendFileOperation: TransferOperation {
    
    lazy var DEBUG_TAG: String = "SendFileOperation (\(remoteUUID),\(direction)):"
    
    public static var chunk_size: Int = 1024 * 512  // 512 kB
    
    var direction: TransferDirection
    var status: TransferStatus
    
    weak var owningRemote: Remote?
    var remoteUUID: String
    
    var UUID: UInt64 { return startTime }
    var startTime: UInt64
    
    var totalSize: Int = 0
    var bytesTransferred: Int = 0
    var bytesPerSecond: Double = 0
    var progress: Double {
        return Double(bytesTransferred) / totalSize
    }
    
    var cancelled: Bool = false
    
    var fileCount: Int = 0
    
    var singleName: String = ""
    var singleMime: String = ""
    
    var topDirBaseNames: [String] = []
    
    lazy var currentFile: FileSender = FileSender(for: files[0])
    var files: [FileName]
    
    
    
    var operationInfo: OpInfo {
        return .with {
            $0.ident = Server.SERVER_UUID
            $0.timestamp = startTime
            $0.readableName = Utils.getDeviceName()
        }
    }
    
    
    var observers: [TransferOperationViewModel] = [] 
    
    
    init(for filenames: [FileName] ) {
        
        direction = .SENDING
        status = .INITIALIZING
        remoteUUID = Server.SERVER_UUID
        startTime = UInt64( Date().timeIntervalSince1970 * 1000 )
        
        files = filenames
        
        fileCount = files.count
        
        singleName = "\(filenames.count) files"
        singleMime = "application/octet-stream"
        
        for filename in filenames {
            topDirBaseNames.append("\(filename.name).\(filename.ext)")
        }
        
    }
    
    
    convenience init(for filename: FileName){
        self.init(for: [filename])
        
        totalSize = currentFile.fileBytes.count
        singleName = currentFile.relativeFilePath
        singleMime = currentFile.fileExtension
        
    }
    
    
    // MARK: prepare
    func prepareToSend() {
        
        status = .WAITING_FOR_PERMISSION
        
    }
    
    
    //MARK: start
    func send(using context: StreamingResponseCallContext<FileChunk>) {
        
        status = .TRANSFERRING
        
        currentFile.loadFileData()
        
        if let chunk = currentFile.readNextChunk() {
            
            print(DEBUG_TAG+"sending chunk: ")
            
            let result = context.sendResponse(chunk)
            
            result.whenSuccess { result in
                print(self.DEBUG_TAG+"chunk transmitted: response \(result)")
                // send next
                self.send(using: context)
            }
            
            result.whenFailure { error in
                print(self.DEBUG_TAG+"chunk transmission failed: \(error)")
            }
            
//            result.whenComplete
            
        } else {
            print(DEBUG_TAG+"alerting file transfer finished (status: .ok)")
            status = .FINISHED
            let result = context.eventLoop.makeSucceededFuture( GRPCStatus.ok )
            
            result.whenComplete { result in
                print(self.DEBUG_TAG+"result tranmitted: response \(result)")
            }
            
        }
        
    }
    
    
    
    
    //MARK: stop
    func stopSending(){
        
    }
    
    
    func calculateTotalSize(){
        
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

