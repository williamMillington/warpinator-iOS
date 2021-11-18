//
//  ReceiveFileOperation.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-08.
//

import Foundation

import GRPC




enum TransferError: Error {
    case TransferNotFound
    case TransferInterrupted
}

enum FileType: Int32 {
    case FILE = 1
    case DIRECTORY = 2
}


class ReceiveFileOperation: TransferOperation {
    
    lazy var DEBUG_TAG: String = "ReceiveFileOperation (\(remoteUUID),\(direction)):"
    
    public enum Direction: String {
        case SENDING, RECEIVING
    }
    
    public enum Status {
        case INITIALIZING
        case WAITING_FOR_PERMISSION, PERMISSION_DECLINED
        case TRANSFERRING, PAUSED, STOPPED, FINISHED, FINISHED_WITH_ERRORS
        case FAILED
    }
    
    
    private var chunk_size: Int = 1024 * 512  // 512 kB
    
    
    var direction: Direction
    var status: Status
    
    weak var owningRemote: Remote?
    var remoteUUID: String
    
    var startTime: UInt64
    
    var totalSize: Double
    var bytesTransferred: Int = 0
    var bytesPerSecond: Double = 0
    var cancelled: Bool = false
    
    var fileCount: Int = 1
    
    var singleName: String = ""
    var singleMime: String = ""
    
    var topDirBaseNames: [String] = []
    
    var overwriteWarning: Bool = false
    
    var currentRelativePath: String = ""
    
    var currentFile: FileReceiver?
    
    
    init(){
        direction = .RECEIVING
        status = .INITIALIZING
        remoteUUID = ""
        startTime = 0
        totalSize = 0
    }
    
}



//MARK: - Receive
extension ReceiveFileOperation {
    
    func prepareReceive(){
        
        print(DEBUG_TAG+" preparing to receive...")
        
        // check if filename is taken
        
        // prepare file
        // - access filesystem
        // - check space exists
        
        
    }
    
    
    func startReceive(){
        print(DEBUG_TAG+" starting to receive: ")
        
        status = .TRANSFERRING
        owningRemote?.beginReceiving(for: self)
    }
    
    
    func readChunk(_ chunk: FileChunk){
        
        print(DEBUG_TAG+" reading chunk")
        
        // starting a new file
        if chunk.relativePath != currentRelativePath {
            
            print(DEBUG_TAG+" creating new file")
            // close out old file
            currentFile?.finish()
            
            currentRelativePath = chunk.relativePath
            
            let file = FileReceiver(filename: currentRelativePath)
            currentFile = file
            
        }
        
        currentFile?.write(chunk.chunk)
        bytesTransferred += chunk.chunk.count
        
    }
    
    
    
    func stopReceiving(){
        
    }
    
    
    func finishReceive(){
        print(DEBUG_TAG+" finished receiving transfer")
        currentFile?.finish()
        status = .FINISHED
        
    }
    
    
    func failReceive(){
        
    }
    
    
    func declineTransfer(){
        
    }
    
    
}





class FileReceiver {
    
    
    
    lazy var DEBUG_TAG: String = "FileReceiver \(filename): "
    
    let filename: String
    
    let fileURL: URL
    let filepath: String
    var fileHandle: FileHandle  {
        do {
            return try FileHandle(forUpdating: fileURL)
        } catch {  print(DEBUG_TAG+"couldn't aquire FileHandle: \(error)")  }
        
        return FileHandle(forUpdatingAtPath: filepath)!
    }
    
    init(filename name: String){
        
        self.filename = name
        
        let fileManager = FileManager.default
        
        let fileParentURL = fileManager.documentsDirectory
        fileURL = fileParentURL.appendingPathComponent(filename)
        
        filepath = fileURL.path
        
        // file already exists
        if fileManager.fileExists(atPath: filepath) {
            print(DEBUG_TAG+"deleting preexisting file")
            try! fileManager.removeItem(at: fileURL)
        }
        
        fileManager.createFile(atPath: filepath, contents: nil)
    }
    
    func write(_ data: Data){
        print(DEBUG_TAG+"\twriting to file...")
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
    }
    
    func finish(){
        fileHandle.closeFile()
    }
}
