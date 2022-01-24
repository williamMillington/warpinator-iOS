//
//  FileWriter.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-02.
//

import Foundation

// MARK: FileWriter
class FileWriter {
    
    enum FileReceiveError: Error {
        case FILE_EXISTS, DIRECTORY_EXISTS
        case SPACE_UNAVAILABLE
        case SYSTEM_ERROR(Error)
    }
    
    
    static var DEBUG_TAG: String = "FileWriter (static): "
    lazy var DEBUG_TAG: String = "FileWriter \(filename): "
    
    var filename: String
    let fileParentURL = FileManager.default.extended.documentsDirectory
    
    /* Computing these variables allows the
     FileWriter to use a placeholder name until writing actually starts.
     This means that –before we actually have the name of the file– we can
     hand this FileWriter to a viewmodel that will update when the file actually starts downloading,
     instead of trying to create create empty viewmodels that we have to keep track of and fill later,
     and keep track of which file we're on, how many files left, blah blah blah.
     */
    var fileURL: URL {
        return fileParentURL.appendingPathComponent(filename)
    }
    
    var filepath: String {
        return fileURL.path
    }
    
    var fileHandle: FileHandle? {
        do {
            return try FileHandle(forUpdating: fileURL)
        } catch {
            print(DEBUG_TAG+"couldn't aquire FileHandle from URL: \(error)")
            print(DEBUG_TAG+"\tattempting to load from path")
            return FileHandle(forUpdatingAtPath: filepath)
        }
    }
    
    var writtenBytesCount: Int = 0
    
    
    var observers: [ObservesFileOperation] = []
    
    
    init(filename name: String){
        self.filename = name
    }
    
    // MARK: createFile
    func createFile(){
        let fileManager = FileManager.default
        
        // file already exists
        if fileManager.fileExists(atPath: filepath) {
            print(DEBUG_TAG+"deleting preexisting file")
            try! fileManager.removeItem(at: fileURL)
        }
        
        fileManager.createFile(atPath: filepath, contents: nil)
        updateObserversInfo()
    }
    
    // MARK: write
    func write(_ data: Data){
//        print(DEBUG_TAG+"\t\t writing to file...")
        
        guard let handle = fileHandle else {
            print(DEBUG_TAG+"\t\tERROR: writing to file failed...")
            return
        }
        
        handle.seekToEndOfFile()
        handle.write(data)
        
        writtenBytesCount += data.count
        updateObserversInfo()
    }
    
    
    // MARK: finish
    func finish(){
        fileHandle?.closeFile()
        updateObserversInfo()
    }
    
    
    // MARK: fail
    func fail(){
        print(DEBUG_TAG+"\tfailing filewrite:")
        fileHandle?.closeFile()
        
        // delete unfinished file
        let fileManager = FileManager.default
        do {
            print(DEBUG_TAG+"\tDeleting unfinished file: \(filepath)")
            try fileManager.removeItem(atPath: filepath)
        } catch {
            print(DEBUG_TAG+"\tAn error occurred attempting to delete file: \(filepath)")
        }
        updateObserversInfo()
    }
    
    // MARK: static createDir
    static func createNewDirectory(withName name: String) throws {
        
        let fileManager = FileManager.default
        let directoryURL = fileManager.extended.documentsDirectory.appendingPathComponent("\(name)")
        
//        print(DEBUG_TAG+"attempting to create new directory: \(directoryURL.path)")
        
        if fileManager.fileExists(atPath: directoryURL.path) {
//            print(DEBUG_TAG+"\t \(directoryURL.path) already exists")
            throw FileReceiveError.DIRECTORY_EXISTS
        } else {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
//                print(DEBUG_TAG+"\tSuccessfully created directory")
            } catch {
//                print(DEBUG_TAG+"\tFailed to create directory")
                throw FileReceiveError.SYSTEM_ERROR(error)
            }
        }
    }
}


//MARK: observers
extension FileWriter {
    
    func addObserver(_ model: ObservesFileOperation){
        observers.append(model)
    }
    
    func removeObserver(_ model: ObservesFileOperation){
        
        for (i, observer) in observers.enumerated() {
            if observer === model {
                observers.remove(at: i)
            }
        }
    }
    
    func updateObserversInfo(){
        observers.forEach { observer in
            observer.infoDidUpdate()  
        }
    }
}

