//
//  FileWriter.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-02.
//

import Foundation


protocol WritesFile {
    var bytesWritten: Int { get }
    func processChunk(_ chunk: FileChunk) throws
    func close()
}

enum WritingError: Error {
    case FILENAME_MISMATCH
    case FILE_EXISTS, DIRECTORY_EXISTS
    case SPACE_UNAVAILABLE
    case UNDEFINED_ERROR(Error)
    
}


// MARK: FileWriter
class FileWriter: WritesFile {
    
    static var DEBUG_TAG: String = "FileWriter (static): "
    lazy var DEBUG_TAG: String = "FileWriter \(originalName): "
    
    // Names of files, as provided by the client.
    // Used in determining the file in which a given chunk belongs, which may change,
    // depending on renaming
    var originalName: String
    var originalRelativePath: String
    
    // used if any of parent folders were renamed due to conflicts
    var modifiedRelativePath: String?
    
    lazy var writtenName = originalName
    var renameCount = 0
    
    var writtenParentPath: String
//    {
//        let path = modifiedRelativePath ?? originalRelativePath
//        let parentPathParts = path.components(separatedBy: "/").dropLast()
//
//        return parentPathParts.count == 0  ?  ""  :  parentPathParts.joined(separator: "/") + "/"
//    }
    
//    var writtenRelativePath : String {   return  writtenParentPath + "\(writtenName)"   }
    
    
    let baseURL = FileManager.default.extended.documentsDirectory
    var writtenURL: URL {   return baseURL.appendingPathComponent( writtenParentPath + "\(writtenName)" )  }
    
    private var fileHandle: FileHandle?
    private var overwrite = false
    
    var bytesWritten: Int = 0
    
    
    var observers: [ObservesFileOperation] = []
    
    
    // MARK: - init
    init(withRelativePath path: String, modifiedRelativeParentPath moddedParentPath: String? = nil, overwrite: Bool){
        
        originalRelativePath = path
        
        let pathParts = path.components(separatedBy: "/")
        
        let parentPathParts = pathParts.dropLast()
        let parentPath = parentPathParts.isEmpty  ?  ""  :  parentPathParts.joined(separator: "/") + "/"
        writtenParentPath = moddedParentPath ?? parentPath //(parentPathParts.isEmpty ? "" : parentPathParts.joined(separator: "/") + "/" )
        
        originalName = pathParts.last ?? "File"
        
        
        // file already exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: writtenURL.path) {
            
            // Rename
            if !overwrite {
                writtenName = rename(originalName)
            } else { //Overwrite
                
                do {
                    print(DEBUG_TAG+"overwriting preexisting file")
                    try fileManager.removeItem(at: writtenURL)
                } catch {
                    // if overwrite fails, rename
                    print(DEBUG_TAG+"\tfailed to overwrite, renaming...")
                    writtenName = rename(originalName)
                }
            }
        }
        
        
        fileManager.createFile(atPath: writtenURL.path, contents: nil)
        
        print(DEBUG_TAG+"created file called \( writtenParentPath + "\(writtenName)" )")
//        print(DEBUG_TAG+"\t\t(system path: \(writtenURL.path))")
        
        do {
             fileHandle = try FileHandle(forUpdating: writtenURL)
        } catch {
//            print(DEBUG_TAG+"couldn't aquire FileHandle from URL: \(error)")
//            print(DEBUG_TAG+"\tattempting to load from path")
//            fileHandle = FileHandle(forUpdatingAtPath: writtenURL.path)
        }
        
    }
    
    
    
    // MARK: rename file
    // TODO: rewrite to be gooder?
    private func rename(_ name: String) -> String {
        
        print(DEBUG_TAG+"Renaming \(name)")
        
        var newName = "File_Renaming_Failed"
        renameCount += 1
        
        if renameCount <= 1000 {
            
            newName = name + "\(renameCount)"
            let path = baseURL.path + "/" + writtenParentPath + "\(newName)"
            
            if FileManager.default.fileExists(atPath: path)  {
                return rename(newName)
            }
        }
        
        print(DEBUG_TAG+"\tnew name is \(newName)")
        return newName
    }
    
    
    
    
    // MARK: processChunk
    func processChunk(_ chunk: FileChunk) throws {
        
        // CHECK IF CHUNK BELONGS
        guard chunk.relativePath == originalRelativePath else {
            throw WritingError.FILENAME_MISMATCH
        }
        
        defer {
            updateObserversInfo()
        }
        
        guard let handle = fileHandle else {
            print(DEBUG_TAG+"UnexpectedError: fileHandle not found?")
//            updateObserversInfo()
            return
        }
        
        let data = chunk.chunk
        
        handle.seekToEndOfFile()
        handle.write(data)
        
        bytesWritten += data.count
//        updateObserversInfo()
        
    }
    
    
    // MARK: close
    func close(){
        fileHandle?.closeFile()
        updateObserversInfo()
    }
    
    
    //MARK:   ////////OLDSTUFF///////
//    // M ARK: createFile
//    func createFile(){
//        let fileManager = FileManager.default
//
//        // file already exists
//        if fileManager.fileExists(atPath: filePath) {
//            print(DEBUG_TAG+"deleting preexisting file")
//            try! fileManager.removeItem(at: writtenURL)
//        }
//
//        fileManager.createFile(atPath: filePath, contents: nil)
//        updateObserversInfo()
//    }
    
    // M ARK: write
//    func write(_ data: Data){
////        print(DEBUG_TAG+"\t\t writing to file...")
//
//        guard let handle = fileHandle else {
//            print(DEBUG_TAG+"\t\tERROR: writing to file failed...")
//
//            FileManager.default.createFile(atPath: filePath, contents: nil)
//            updateObserversInfo()
//
//            return
//        }
//
//        handle.seekToEndOfFile()
//        handle.write(data)
//
//        bytesWritten += data.count
//        updateObserversInfo()
//    }
//
    
    // M ARK: finish
//    func finish(){
//        fileHandle?.closeFile()
//        updateObserversInfo()
//    }
    
    
//    // M ARK: fail
//    func fail(){
//        print(DEBUG_TAG+"\tfailing filewrite:")
//        fileHandle?.closeFile()
//
//        // delete unfinished file
//        let fileManager = FileManager.default
//        do {
//            print(DEBUG_TAG+"\tDeleting unfinished file: \(filePath)")
//            try fileManager.removeItem(atPath: filePath)
//        } catch {
//            print(DEBUG_TAG+"\tAn error occurred attempting to delete file: \(filePath)")
//        }
//        updateObserversInfo()
//    }
    
//     M ARK: static createDir
//    static func createNewDirectory(withName name: String) throws {
//
//        let fileManager = FileManager.default
//        let directoryURL = fileManager.extended.documentsDirectory.appendingPathComponent("\(name)")
//
////        print(DEBUG_TAG+"attempting to create new directory: \(directoryURL.path)")
//
//        if fileManager.fileExists(atPath: directoryURL.path) {
////            print(DEBUG_TAG+"\t \(directoryURL.path) already exists")
//            throw WritingError.DIRECTORY_EXISTS
//        } else {
//            do {
//                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
////                print(DEBUG_TAG+"\tSuccessfully created directory")
//            } catch {
////                print(DEBUG_TAG+"\tFailed to create directory")
//                throw WritingError.UNDEFINED_ERROR(error)
//            }
//        }
//    }
    
    //MARK:   ////////OLDSTUFF///////
    
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

//extension FileWriter: ObservesFileOperation {
//    func infoDidUpdate() {
//
//    }
//}






//
//extension FileWriter: WritesFile {
//
//    // MARK: processChunk
//    func processChunk(_ chunk: FileChunk) throws {
//
//        // CHECK IF CHUNK BELONGS
//        guard chunk.relativePath == originalRelativePath else {
//            throw WritingError.FILENAME_MISMATCH
//        }
//
//        guard let handle = fileHandle else {
//            print(DEBUG_TAG+"UnexpectedError: fileHandle not found?")
//            updateObserversInfo()
//            return
//        }
//
//        let data = chunk.chunk
//
//        handle.seekToEndOfFile()
//        handle.write(data)
//
//        bytesWritten += data.count
//        updateObserversInfo()
//
//    }
//
//
//    // MARK: close
//    func close(){
//        fileHandle?.closeFile()
//        updateObserversInfo()
//    }
//
//
//
//
//
////    private func checkPathIsRelative(){
////
////    }
//
//
//}
