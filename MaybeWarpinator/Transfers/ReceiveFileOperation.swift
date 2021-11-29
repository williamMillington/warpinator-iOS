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
    
    var completedFiles: [FileReceiver] = []
    var currentFile: FileReceiver?
    
    
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
        
//        updateObserversInfo()
    }
    
    
    // MARK: processChunk
    func processChunk(_ chunk: FileChunk){
        
        print(DEBUG_TAG+" reading chunk:")
        print(DEBUG_TAG+"\trelativePath: \(chunk.relativePath)")
        print(DEBUG_TAG+"\tfileType: \( FileType(rawValue: chunk.fileType)!) ")
        print(DEBUG_TAG+"\tfileMode: \(chunk.fileMode)")
        print(DEBUG_TAG+"\ttime: \(chunk.time)")
        
        
        if chunk.fileType == FileType.DIRECTORY.rawValue {
            do {
                try FileReceiver.createNewDirectory(withName: chunk.relativePath)
            }
            catch let error as FileReceiver.FileReceiveError {
                switch error {
                case .DIRECTORY_EXISTS: print(DEBUG_TAG+"Directory exists (\(error))")
                    currentRelativePath = chunk.relativePath
                default: print(DEBUG_TAG+"Error: \(error)"); break
                }
            } catch { print(DEBUG_TAG+"unknown error") }
        } else {
            
            // starting a new file
            if chunk.relativePath != currentRelativePath {
                
                print(DEBUG_TAG+" creating new file")
                // close out old file
                if let file = currentFile {
                    file.finish()
                    completedFiles.append(file)
                }
                
                currentRelativePath = chunk.relativePath
                
                let file = FileReceiver(filename: currentRelativePath)
                currentFile = file
            }
            
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




// MARK: - FileReceiver
class FileReceiver {
    
    
    enum FileReceiveError: Error {
        case FILE_EXISTS, DIRECTORY_EXISTS
        case SPACE_UNAVAILABLE
        case SYSTEM_ERROR(Error)
    }
    
    
    static var DEBUG_TAG: String = "FileReceiver (static): "
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
        
        let fileParentURL = fileManager.extended.documentsDirectory
        
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
    
    
    static func createNewDirectory(withName name: String) throws {
        
        print(DEBUG_TAG+"attempting to create new directory: \(name)")
        let fileManager = FileManager.default
//        let fileParentURL = fileManager.extended.documentsDirectory
        
        let directoryURL = fileManager.extended.documentsDirectory.appendingPathComponent("\(name)")
        
        print(DEBUG_TAG+"checking if something exists at \(directoryURL.path)")
        
        if fileManager.fileExists(atPath: directoryURL.path) {
            print(DEBUG_TAG+"\tdirectory already exists")
            throw FileReceiveError.DIRECTORY_EXISTS
        } else {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                print(DEBUG_TAG+"\tSuccessfully created directory")
            } catch {
                print(DEBUG_TAG+"\tfailed to create directory")
                throw FileReceiveError.SYSTEM_ERROR(error)
            }
        }
        
    }
    
}
