//
//  TransferFile.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-12.
//

import Foundation




class TransferFile {
    
    lazy var DEBUG_TAG: String = "TransferFile \(filename): "
    
    let filename: String
    
    let fileURL: URL
    let filepath: String
    var fileHandle: FileHandle  {
        
        do {
            return try FileHandle(forUpdating: fileURL)
        } catch {
            print(DEBUG_TAG+"couldn't aquire FileHandle: \(error)")
        }
        
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
        
        print(DEBUG_TAG+"creating file named: \(filename) at path \(filepath)")
        fileManager.createFile(atPath: filepath, contents: nil)
                
        
        
        print(DEBUG_TAG+"check operation success")
        if fileManager.fileExists(atPath: filepath) {
            print(DEBUG_TAG+"\toperation successful")
        } else {
            print(DEBUG_TAG+"\toperation WAS NOT successful")
        }
        
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






