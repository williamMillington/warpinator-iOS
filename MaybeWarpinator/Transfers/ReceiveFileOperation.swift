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
                $0.readableName = remote.details.displayName
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
    
    var files: [FileWriter] = []
    var writerIndex = 0
    var currentFile: FileWriter?
    
    
    var observers: [TransferOperationViewModel] = []
    
    
    lazy var queueLabel = "RECEIVE_\(owningRemoteUUID)_\(UUID)"
    lazy var receivingChunksQueue = DispatchQueue(label: queueLabel, qos: .utility)
    
    
    var operationInfo: OpInfo
    
    
    //MARK: init
    init(_ transferRequest: TransferOpRequest, forRemote remote: Remote){
        
        request = transferRequest
        owningRemote = remote
        
        direction = .RECEIVING
        status = .INITIALIZING
        
        
        startTime = transferRequest.info.timestamp
        totalSize = transferRequest.size
        fileCount = Int(transferRequest.count)
        
        directories = transferRequest.topDirBasenames
        
        operationInfo = .with {
            $0.ident = Server.SERVER_UUID
            $0.timestamp = transferRequest.info.timestamp
            $0.readableName = Utils.getDeviceName()
        }
        
    }
}



//MARK: - Receive
extension ReceiveFileOperation {
    
    
    //MARK: prepare
    func prepareReceive(){
        
        print(DEBUG_TAG+" preparing to receive...")
        
        // check if space exists
        let availableSpace = Utils.queryAvailableDiskSpace()
        print(DEBUG_TAG+" available space \(availableSpace) vs transfer size \(totalSize)")
        guard availableSpace > totalSize else {
            print(DEBUG_TAG+"\t Not enough space"); return
        }
        
        print(DEBUG_TAG+"\t Space is available");
        
        // In case of retry
        bytesTransferred = 0
        bytesPerSecond = 0
        
        // reset filewriters
        files = []
        for i in 0..<fileCount {
            // Create 'empty' FileWriters
            files.append(FileWriter(filename: "File \(i)"))
        }
        writerIndex = 0
        currentRelativePath = ""
        currentFile = nil
        
        
        status = .WAITING_FOR_PERMISSION
        
        updateObserversInfo()
        
    }
    
    
    //MARK: start
    func startReceive(usingClient client: WarpClient){
        
        print(DEBUG_TAG+" starting receive operation")
        
        status = .TRANSFERRING
        
        let dataStream = client.startTransfer(operationInfo) { chunk in
            
            guard self.status == .TRANSFERRING else {
                print("canceling chunk processing")
                return
            }
            
            self.receivingChunksQueue.async {
                self.processChunk(chunk)
            }
        }
        
        dataStream.status.whenSuccess { status in
            print(self.DEBUG_TAG+"transfer finished successfully with status \(status)")
            self.finishReceive()
        }
        
        dataStream.status.whenFailure { error in
            print(self.DEBUG_TAG+"transfer failed: \(error)")
            self.receiveWasCancelled()
        }
        
    }
    
    
    // MARK: processChunk
    func processChunk(_ chunk: FileChunk){
        
        print(DEBUG_TAG+" reading chunk:")
//        print(DEBUG_TAG+"\trelativePath: \(chunk.relativePath)")
//        print(DEBUG_TAG+"\tfileType: \( FileType(rawValue: chunk.fileType)!) ")
//        print(DEBUG_TAG+"\tfileMode: \(chunk.fileMode)")
//        print(DEBUG_TAG+"\ttime: \(chunk.time)")
        
        // If Directory
        if chunk.fileType == FileType.DIRECTORY.rawValue {
            
            do { // Create the directory
                try FileWriter.createNewDirectory(withName: chunk.relativePath)
            }
            catch let error as FileWriter.FileReceiveError { // If directory already exists
                
                switch error {
                case .DIRECTORY_EXISTS: print(DEBUG_TAG+"Directory exists (\(error))")
                    currentRelativePath = chunk.relativePath
                default: print(DEBUG_TAG+"Error: \(error)"); break
                }
                
            } catch { // uknown error
                print(DEBUG_TAG+"Unknown error")
            }
            
        } else {// Else, write file
            
            // if starting a new file
            if chunk.relativePath != currentRelativePath {
                
                print(DEBUG_TAG+" creating new file: \(chunk.relativePath)")
                
                // close out old file, if it exists
                if let file = currentFile {
                    file.finish()
//                    files.append(file)
                }
                
                currentRelativePath = chunk.relativePath
                
                // TODO: this automatically overwrites, provide option to avoid
//                let file = FileWriter(filename: currentRelativePath)
                currentFile = files[writerIndex] //   file
                writerIndex += 1
                currentFile?.filename = currentRelativePath
                currentFile?.createFile()
            } // else continue writing to current file
            
            currentFile?.write(chunk.chunk)
        }
        
        bytesTransferred += chunk.chunk.count
        
        updateObserversInfo()
    }
    
    
    // MARK: finish
    func finishReceive(){
        print(DEBUG_TAG+" Receive operation finished")
        
        if status != .TRANSFERRING {
            receiveWasCancelled()
            return
        }
        
        currentFile?.finish()
        status = .FINISHED
        print(DEBUG_TAG+"\t\tFinished")
    }

    
    
    // MARK: - Stopping
    // this side calls stop
    func orderStop(_ error: Error? = nil){
        print(self.DEBUG_TAG+"ordering stop, error: \(String(describing: error))")
        owningRemote?.callClientStopTransfer(self, error: error)
        stopRequested(error)
    }
    
    // other side calls stop
    func stopRequested(_ error: Error? = nil){
        
        print(DEBUG_TAG+"stopped with error: \(String(describing: error))")
        
        if let error = error {
            status = .FAILED(error)
        } else {
            status = .CANCELLED
        }
        
    }
    
    
    func receiveWasCancelled(){
        
        print(DEBUG_TAG+" request cancelled")
        status = .CANCELLED
        
        // cancel current writing operation
        currentFile?.fail()
    }
    
    
    // MARK: decline
    func decline(_ error: Error? = nil){
        
        print(DEBUG_TAG+" declining request...")
        
        owningRemote?.callClientDeclineTransfer(self, error: error)
        status = .CANCELLED
        
        currentFile?.fail()
    }
    
    
    
}



//MARK: Observers
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


