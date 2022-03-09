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
    var remoteUUID: String
    
    var startTime: Double
    
    var totalSize: Double
    var bytesTransferred: Double = 0
    var bytesPerSecond: Double = 0
    var cancelled: Bool = false
    
    var fileCount: Int = 1
    
    var singleName: String = ""
    var singleMime: String = ""
    
    var topDirBaseNames: [String] = []
    
    var overwriteWarning: Bool = false
    
    var currentRelativePath: String = ""
    
    
    
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
        
        
        
        
        
        
        
        
        
        
        
    }
    
    
    func startReceive(){
        
    }
    
    
    func stopReceiving(){
        
    }
    
    
    func finishReceive(){
        
    }
    
    
    func failReceive(){
        
    }
    
    
    func declineTransfer(){
        
    }
    
    
}
