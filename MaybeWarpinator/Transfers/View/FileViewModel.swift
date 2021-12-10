//
//  FileViewModel.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-02.
//

import Foundation


protocol FileViewModel {
    
    var onUpdated: ()->Void { get set }
    
    var type: String { get }
    var name: String { get }
    var size: String { get }
    var progress: Double { get }
    
}


class FileReceiverViewModel: FileViewModel {
    
    var operation: FileWriter
    var onUpdated: ()->Void = {}
    
    var type: String {
        return "File"
    }
    
    var name: String {
        return operation.filename
    }
    
    var size: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let bytes = operation.writtenBytesCount
        return formatter.string(fromByteCount:  Int64( bytes) )
    }
    
    var progress: Double {
        return 0
    }
    
    
    init(operation: FileWriter){
        self.operation = operation
    }
    
    func update(){
        DispatchQueue.main.async {
            self.onUpdated()
        }
    }
    
}


class FileSenderViewModel: FileViewModel {
    
    var operation: FileReader
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
    
    
    init(operation: FileReader){
        self.operation = operation
    }
    
    
    func update(){
        DispatchQueue.main.async {
            self.onUpdated()
        }
    }
    
}
