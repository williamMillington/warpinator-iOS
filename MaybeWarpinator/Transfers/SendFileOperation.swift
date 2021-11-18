//
//  SendFileOperation.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-15.
//

import Foundation

import GRPC


protocol TransferOperation {
    
    var owningRemote: Remote? { get set }
    
}


// MARK: SendFileOperation
class SendFileOperation: TransferOperation {
    
    lazy var DEBUG_TAG: String = "SendFileOperation (\(remoteUUID),\(direction)):"
    
    public enum Direction: String {
        case SENDING, RECEIVING
    }
    
    public enum Status {
        case INITIALIZING
        case WAITING_FOR_PERMISSION, PERMISSION_DECLINED
        case TRANSFERRING, PAUSED, STOPPED, FINISHED, FINISHED_WITH_ERRORS
        case FAILED
    }
    
    public static var chunk_size: Int = 1024 * 512  // 512 kB
    
    
    var direction: Direction
    var status: Status
    
    weak var owningRemote: Remote?
    var remoteUUID: String
    
    var startTime: UInt64
    
    var totalSize: Int = 0
    var bytesTransferred: Int = 0
    var bytesPerSecond: Double = 0
    var cancelled: Bool = false
    
    var fileCount: Int = 1
    
    var singleName: String = ""
    var singleMime: String = ""
    
    var topDirBaseNames: [String] = []
    
    var currentFile: FileSender
    
    
    var operationInfo: OpInfo {
        return .with {
            $0.ident = Server.SERVER_UUID
            $0.timestamp = startTime
            $0.readableName = Utils.getDeviceName()
        }
    }
    
    
    
    
    
    init(for filename: String, ext: String){
        
        direction = .SENDING
        status = .INITIALIZING
        remoteUUID = Server.SERVER_UUID
        startTime = UInt64( Date().timeIntervalSince1970 * 1000 )
        
        currentFile = FileSender(filename: filename, extension: ext)
        
        topDirBaseNames.append("iOS")
        fileCount = 1
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
        
        if let chunk = currentFile.readNextChunk() {
            
            print(DEBUG_TAG+"sending chunk: ")
            
            let result = context.sendResponse(chunk)
            
            result.whenComplete { result in
                print(self.DEBUG_TAG+"chunk tranmitted: response \(result)")
                // send next
                self.send(using: context)
            }
            
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






// MARK: FileSender
class FileSender {
    
    lazy var DEBUG_TAG: String = "FileSender \"\(filename).\(fileExtension):\" "
    
    let filename: String
    let fileExtension: String
    
    let fileURL: URL
    let filepath: String
    var relativeFilePath: String {
        return filename + "." + fileExtension
    }
    
    var fileBytes: [UInt8]
    
    var sent = 0
    var readHead = 0
    var hasNext = false
    
    
    init(filename name: String, extension ext: String){
        
        filename = name
        fileExtension = ext
        
        filepath = Bundle.main.path(forResource: filename,
                                    ofType: fileExtension)!
        fileURL = URL(fileURLWithPath: filepath)
        
        let fileData = try! Data(contentsOf: fileURL)
        fileBytes = Array(fileData)
        
        
        print(DEBUG_TAG+"File loaded")
        print(DEBUG_TAG+"\tbytes: \(fileBytes.count)")
        
    }
    
    
    func readNextChunk() -> FileChunk? {
        
        print(DEBUG_TAG+"Reading next chunk")
        print(DEBUG_TAG+"\tsent: \(sent)")
        print(DEBUG_TAG+"\tread-head: \(readHead)")
        print(DEBUG_TAG+"\ttotal: \(fileBytes.count)")
        
        guard sent < fileBytes.count else {
            print(DEBUG_TAG+"No more data to be read"); return nil
        }
        
        let datachunk = arraySubsection(from: fileBytes, startingAt: readHead, size: SendFileOperation.chunk_size)
        
        let fileChunk: FileChunk = .with {
            $0.relativePath = relativeFilePath
            $0.fileType = FileType.FILE.rawValue
            $0.chunk = Data(bytes: datachunk, count: datachunk.count)
        }
        
        sent += datachunk.count
        readHead += datachunk.count
        
        
        return fileChunk
    }
    
    
    
    private func arraySubsection(from array: [UInt8], startingAt index: Int, size: Int ) -> [UInt8] {
        
        var endIndex = index + size
        
        if ((endIndex) >= array.count){
            endIndex = array.count - 1
        }
        
        print(DEBUG_TAG+"reading from bytes[\(index)...\(endIndex)]")
        
        return  Array( array[index...endIndex] )
    }
    
    
    
}
