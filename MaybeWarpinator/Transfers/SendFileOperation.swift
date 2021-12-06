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
    
    var cancelled: Bool = false
    
    var fileCount: Int = 0
    
    var singleName: String = ""
    var singleMime: String = ""
    
    var topDirBaseNames: [String] = []
    
//    lazy var currentFile: FileReader = FileReader(for: files[0])
    
    var files: [FileName]
    
    var currentFileReaderIndex = 0
    var fileReaders: [FileReader] = []
    
    
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
        
        status = .WAITING_FOR_PERMISSION
        
    }
    
    
    
    //MARK: start
    func send(using context: StreamingResponseCallContext<FileChunk>) -> EventLoopPromise<GRPCStatus> {
        
        status = .TRANSFERRING
        
        let currentFile = fileReaders[currentFileReaderIndex]
        
        let promise = context.eventLoop.makePromise(of: GRPCStatus.self)
        
        DispatchQueue.main.async {
            
            for chunk in currentFile {
                
                let result = context.sendResponse(chunk)
    //        let result = context.sendresponses
                
                result.whenSuccess { result in
                    print(self.DEBUG_TAG+"chunk transmission success \(result)")
                }

                result.whenFailure { error in
                    print(self.DEBUG_TAG+"chunk transmission failed: \(error)")
                }
            }
            
            promise.succeed(.ok)
        }
        
        
        context.closeFuture.whenComplete { result in
            print(self.DEBUG_TAG+"TransferOperation completed with result: \(result)")
            self.status = .FINISHED
        }
        
        
        return promise
        
        
//        for chunk in currentFile {
//
//            let result = context.sendResponse(chunk)
//
//            result.whenSuccess { result in
//                print(self.DEBUG_TAG+"chunk transmission success \(result)")
//            }
//
//            result.whenFailure { error in
//                print(self.DEBUG_TAG+"chunk transmission failed: \(error)")
//            }
//        }
//
//        context.closeFuture.whenComplete { result in
//
//            print(self.DEBUG_TAG+"TransferOperation completed with result: \(result)")
//            self.status = .FINISHED
//        }
        
//        context.eventLoop.makeSucceededFuture(GRPCStatus.ok)
        
//        if let chunk = currentFile.readNextChunk() {
//
//            print(DEBUG_TAG+"sending chunk: ")
//
//            let result = context.sendResponse(chunk)
//
//            result.whenSuccess { result in
//                print(self.DEBUG_TAG+"chunk transmitted: response \(result)")
//                // send next
//                self.send(using: context)
//            }
//
//            result.whenFailure { error in
//                print(self.DEBUG_TAG+"chunk transmission failed: \(error)")
//            }
//
////            result.whenComplete
//
//        } else {
//            print(DEBUG_TAG+"alerting file transfer finished (status: .ok)")
//            status = .FINISHED
//            let result = context.eventLoop.makeSucceededFuture( GRPCStatus.ok )
//
//            result.whenComplete { result in
//                print(self.DEBUG_TAG+"result tranmitted: response \(result)")
//            }
//
//        }
        
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

