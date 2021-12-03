//
//  FileOperationViewModel.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-02.
//

import Foundation


protocol FileOperationViewModel {
    
    var type: String { get }
    var name: String { get }
    var size: String { get }
    var progress: Double { get }
    
}


class FileReceiverViewModel: FileOperationViewModel {
    
    var operation: FileReceiver
    var onUpdated: ()->Void = {}
    
    var type: String {
        return "File"
    }
    
    var name: String {
        return operation.filename
    }
    
    var size: String {
        return "--.--MB"
    }
    
    var progress: Double {
        return 0
    }
    
    
    init(operation: FileReceiver){
        self.operation = operation
    }
    
    func update(){
        DispatchQueue.main.async {
            self.onUpdated()
        }
    }
    
}


class FileSenderViewModel: FileOperationViewModel {
    
    var operation: FileSender
    var onUpdated: ()->Void = {}
    
    var type: String {
        return "." + operation.fileExtension
    }
    
    var name: String {
        return operation.filename
    }
    
    var size: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let bytes = operation.fileBytes.count
        return formatter.string(fromByteCount:  Int64( bytes) )
    }
    
    var progress: Double {
        return 0
    }
    
    
    init(operation: FileSender){
        self.operation = operation
    }
    
    func update(){
        DispatchQueue.main.async {
            self.onUpdated()
        }
    }
    
}

