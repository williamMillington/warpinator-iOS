//
//  TransferOperation.swift
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
        
        
        status = .WAITING_FOR_PERMISSION
        direction = .SENDING
        startTime = UInt64( Date().timeIntervalSince1970 * 1000 )
        
        fileCount = 1
        bytesTransferred = 0
        
//        guard let file = currentFile else { return }
//        file.
        
        
        
        
    }
    
    
    func startSending(using context: StreamingResponseCallContext<FileChunk>) {
        
        let filename = "TestFileToSend"
        let ext = "rtf"
        
        let filepath = Bundle.main.path(forResource: filename,
                                        ofType: ext)!
        let fileURL = URL(fileURLWithPath: filepath)
        
        let fileData = try! Data(contentsOf: fileURL)
        let fileBytes = Array(fileData)
        
        var total = fileData.count
        var sent = 0
        
        var readHead = 0
        var dataBuffer: [UInt8] = Array(repeating: 0, count: chunk_size)
        
        func arraySlice(from array: [UInt8], startingAt index: Int, size: Int ) -> [UInt8] {
            var endIndex = index + size
            if ((endIndex) >= array.count){
                endIndex = array.count
            }
            return  Array( array[index...endIndex] )
        }
        
        
        while sent < total {
            
            let datachunk = arraySlice(from: fileBytes, startingAt: readHead, size: chunk_size)
            readHead = readHead + datachunk.count
            
            let fileChunk: FileChunk = .with {
                $0.relativePath = filename
                $0.fileType = TransferFile.FileType.FILE.rawValue
                $0.chunk = Data(bytes: datachunk, count: datachunk.count)
                $0.fileMode = 0644
            }
            
            let response = context.sendResponse(fileChunk)
            
            response.whenComplete { _ in
                
            }
            
            
        }
    }
    
    
    
    
    
    
    func stopSending(){
        
    }
    
    
    func calculateTotalSize(){
        
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
