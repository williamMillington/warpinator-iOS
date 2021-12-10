//
//  FileWriter.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-02.
//

import Foundation


class FileWriter {
    
    enum FileReceiveError: Error {
        case FILE_EXISTS, DIRECTORY_EXISTS
        case SPACE_UNAVAILABLE
        case SYSTEM_ERROR(Error)
    }
    
    
    static var DEBUG_TAG: String = "FileWriter (static): "
    lazy var DEBUG_TAG: String = "FileWriter \(filename): "
    
    let filename: String
    
    let fileURL: URL
    let filepath: String
    var fileHandle: FileHandle  {
        do {
            return try FileHandle(forUpdating: fileURL)
        } catch {  print(DEBUG_TAG+"couldn't aquire FileHandle: \(error)")  }
        
        return FileHandle(forUpdatingAtPath: filepath)!
    }
    
    var writtenBytesCount: Int = 0
    
    var observers: [FileReceiverViewModel] = []
    
    
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
        updateObserversInfo()
    }
    
    func write(_ data: Data){
        print(DEBUG_TAG+"\twriting to file...")
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
        
        writtenBytesCount += data.count
        updateObserversInfo()
    }
    
    func finish(){
        fileHandle.closeFile()
    }
    
    
    func fail(){
        print(DEBUG_TAG+"filewriting has failed.")
        fileHandle.closeFile()
        
        // delete unfinished file
        let fileManager = FileManager.default
        do {
            print(DEBUG_TAG+"\tDeleting unfinished file: \(filepath)")
            try fileManager.removeItem(atPath: filepath)
        } catch {
            print(DEBUG_TAG+"\tAn error occurred attempting to delete file: \(filepath)")
        }
    }
    
    
    static func createNewDirectory(withName name: String) throws {
        
        let fileManager = FileManager.default
        let directoryURL = fileManager.extended.documentsDirectory.appendingPathComponent("\(name)")
        
        print(DEBUG_TAG+"attempting to create new directory: \(directoryURL.path)")
        
        if fileManager.fileExists(atPath: directoryURL.path) {
            print(DEBUG_TAG+"\t \(directoryURL.path) already exists")
            throw FileReceiveError.DIRECTORY_EXISTS
        } else {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                print(DEBUG_TAG+"\tSuccessfully created directory")
            } catch {
                print(DEBUG_TAG+"\tFailed to create directory")
                throw FileReceiveError.SYSTEM_ERROR(error)
            }
        }
    }
}


//MARK: observers
extension FileWriter {
    
    func addObserver(_ model: FileReceiverViewModel){
        observers.append(model)
    }
    
    func removeObserver(_ model: FileReceiverViewModel){
        
        for (i, observer) in observers.enumerated() {
            if observer === model {
                observers.remove(at: i)
            }
        }
    }
    
    func updateObserversInfo(){
        observers.forEach { observer in
            observer.update()  
        }
    }
}
