//
//  TransferOperation.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-08.
//

import Foundation


class TransferOperation {
    
    lazy var DEBUG_TAG: String = "TransferOperation (\(remoteUUID),\(direction)):"
    
    public enum Direction: String {
        case SENDING, RECEIVING
    }
    
    public enum Status {
        case INITIALIZING
        case WAITING_FOR_PERMISSION, PERMISSION_DECLINED
        case TRANSFERRING, PAUSED, STOPPED, FINISHED, FINISHED_WITH_ERRORS
        case FAILED
    }
    
    public enum FileType {
        case FILE, DIRECTORY
    }
    
    private static var chunk_size: Int = 1024 * 512  // 512 kB
    
    
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
    
    var currentFile: TransferFile?
    
    
    init(){
        direction = .RECEIVING
        status = .INITIALIZING
        remoteUUID = ""
        startTime = 0
        totalSize = 0
    }
    
}




//MARK: - Send
extension TransferOperation {
    
    func prepareToSend() {
        
    }
    
    
    func startSending() {
        
    }
    
    
    func stopSending(){
        
    }
    
}







//MARK: - Receive
extension TransferOperation {
    
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
            
            let file = TransferFile(filename: currentRelativePath)
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
