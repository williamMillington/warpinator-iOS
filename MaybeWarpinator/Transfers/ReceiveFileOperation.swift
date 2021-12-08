//
//  ReceiveFileOperation.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-08.
//

import Foundation

import GRPC


// MARK: ReceiveFileOperation
class ReceiveFileOperation: TransferOperation {
    
    lazy var DEBUG_TAG: String = "ReceiveFileOperation (\(owningRemoteUUID),\(direction)):"
    
    
    struct MockOperation {
        static func make(for remote: Remote) -> ReceiveFileOperation {
            
            let opinfo = OpInfo.with {
                $0.ident = remote.details.uuid
                $0.readableName = remote.displayName
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
    
    
    private var chunk_size: Int = 1024 * 512  // 512 kB
    
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
    
    var UUID: UInt64 { return startTime }  
    var startTime: UInt64
    
    var totalSize: UInt64
    var bytesTransferred: Int = 0
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
    
    var completedFiles: [FileWriter] = []
    var currentFile: FileWriter?
    
    
    var observers: [TransferOperationViewModel] = []
    
    
    init(_ request: TransferOpRequest, forRemote remote: Remote){
        
        self.request = request
        owningRemote = remote
        
        direction = .RECEIVING
        status = .INITIALIZING
        
        
        startTime = request.info.timestamp
        totalSize =  request.size
        fileCount = Int(request.count)
        
        directories = request.topDirBasenames
        
    }
}



//MARK: - Receive
extension ReceiveFileOperation {
    
    
    //MARK: prepare
    func prepareReceive(){
        
        print(DEBUG_TAG+" preparing to receive...")
        
        // check if space exists
        let availableSpace = Utils.queryAvailableDiskSpace()
        print(DEBUG_TAG+" available space \(availableSpace) vs transfer size\(totalSize)")
        guard availableSpace > totalSize else {
            print(DEBUG_TAG+"\t Not enough space"); return
        }
        
        print(DEBUG_TAG+"\t Space is available");
        
        updateObserversInfo()
        
    }
    
    
    
    
    //MARK: start
    func startReceive(){
        print(DEBUG_TAG+" starting to receive: ")
        
        status = .TRANSFERRING
        owningRemote?.beginReceiving(for: self)
        
    }
    
    
    // MARK: processChunk
    func processChunk(_ chunk: FileChunk){
        
        print(DEBUG_TAG+" reading chunk:")
        print(DEBUG_TAG+"\trelativePath: \(chunk.relativePath)")
        print(DEBUG_TAG+"\tfileType: \( FileType(rawValue: chunk.fileType)!) ")
        print(DEBUG_TAG+"\tfileMode: \(chunk.fileMode)")
        print(DEBUG_TAG+"\ttime: \(chunk.time)")
        
        // If Directory
        if chunk.fileType == FileType.DIRECTORY.rawValue {
            do { // Create directory
                try FileWriter.createNewDirectory(withName: chunk.relativePath)
            }
            catch let error as FileWriter.FileReceiveError {
                switch error {
                case .DIRECTORY_EXISTS: print(DEBUG_TAG+"Directory exists (\(error))")
                    currentRelativePath = chunk.relativePath
                default: print(DEBUG_TAG+"Error: \(error)"); break
                }
            } catch { print(DEBUG_TAG+"unknown error") }
        } else {
            
            // if starting a new file
            if chunk.relativePath != currentRelativePath {
                
                print(DEBUG_TAG+" creating new file")
                
                // close out old file
                if let file = currentFile {
                    file.finish()
                    completedFiles.append(file)
                }
                
                currentRelativePath = chunk.relativePath
                
                // TODO: this automatically overwrites, provide option to avoid
                let file = FileWriter(filename: currentRelativePath)
                currentFile = file
            } // else continue writing to current file
            
            currentFile?.write(chunk.chunk)
        }
        
        bytesTransferred += chunk.chunk.count
        
        updateObserversInfo()
    }
    
    // MARK: finish
    func finishReceive(){
        print(DEBUG_TAG+" finished receiving transfer")
        currentFile?.finish()
        status = .FINISHED
//        updateObserversInfo()
    }
    
    // MARK: stop
    func stopReceiving(){
        
    }
    
    
    
    // MARK: decline
    func declineTransfer(){
        
    }
    
    // MARK: fail
    func failReceive(){
        
    }
    
    
    
    
    
}



//MARK: observers
extension ReceiveFileOperation {
    
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


