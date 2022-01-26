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
    lazy var DEBUG_TAG: String = "FileWriter \(downloadName): "
    
    // Names of files, as provided by the client.
    // Used in determining the file in which a given chunk belongs, which may change,
    // depending on renaming
    var downloadName: String
    var downloadRelativePath: String
    
    
    // The values that will be written to the filesystem (renaming feature)
    lazy var fileSystemName = downloadName
    var fileSystemParentPath: String
    
    
    var fileExtension: String = ""
    lazy var extensionlessFileSystemName = itemURL.deletingPathExtension().lastPathComponent
    
    
    var renameCount = 0
    var overwrite = false
    
    let baseURL = FileManager.default.extended.documentsDirectory
    var itemURL: URL {
        return baseURL.appendingPathComponent( fileSystemParentPath + "\(fileSystemName)" )
    }
    
    var fileHandle: FileHandle?
    var bytesWritten: Int = 0
    
    var observers: [ObservesFileOperation] = []
    
    
    // MARK: - init
    init(withRelativePath path: String, modifiedRelativeParentPath moddedParentPath: String? = nil, overwrite: Bool){
        
        
        let pathParts = path.components(separatedBy: "/")
        
        downloadRelativePath = path
        downloadName = pathParts.last ?? "File"
        
        let parentPathParts = pathParts.dropLast()
        let parentPath = parentPathParts.isEmpty  ?  ""  :  parentPathParts.joined(separator: "/") + "/"
        fileSystemParentPath = moddedParentPath ?? parentPath
        print(DEBUG_TAG+"fileystemparentpath is \(fileSystemParentPath)")
        fileExtension = itemURL.pathExtension
        
        
        // file already exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: itemURL.path) {
            
            // Rename
            if !overwrite {
                fileSystemName = rename(downloadName) + ".\(fileExtension)"
            } else { //Overwrite
                
                do {
                    print(DEBUG_TAG+"\toverwriting preexisting file")
                    try fileManager.removeItem(at: itemURL)
                } catch {
                    // if overwrite fails, rename
                    print(DEBUG_TAG+"\tfailed to overwrite, renaming...")
                    fileSystemName = rename(downloadName) + ".\(fileExtension)"
                }
            }
        }
        
        
        fileManager.createFile(atPath: itemURL.path, contents: nil)
        print(DEBUG_TAG+"created file called \( fileSystemParentPath + "\(fileSystemName)" )")
        
        
        
        fileHandle = try? FileHandle(forUpdating: itemURL)
    }
    
    
    
    // MARK: rename file
    // TODO: rewrite to be gooder?
    private func rename(_ name: String) -> String {
        
        print(DEBUG_TAG+"Renaming \(name) (\(renameCount))")
        
        var newName = "File_Renaming_Failed"
        
        while renameCount <= 1000 {
            renameCount += 1
            
            newName = extensionlessFileSystemName + "\(renameCount)"
            let path = baseURL.path + "/" + fileSystemParentPath + "\(newName)" + fileExtension
            
            if !FileManager.default.fileExists(atPath: path)  {
                break // return rename(fileSystemName)
            }
        }
        
        print(DEBUG_TAG+"\tnew name is \(newName)")
        return newName
    }
    
    
    
    
    // MARK: processChunk
    func processChunk(_ chunk: FileChunk) throws {
        
        // CHECK IF CHUNK BELONGS
        guard chunk.relativePath == downloadRelativePath else {
            throw WritingError.FILENAME_MISMATCH
        }
        
        defer {
            updateObserversInfo()
        }
        
        guard let handle = fileHandle else {
            print(DEBUG_TAG+"UnexpectedError: fileHandle not found?")
            return
        }
        
        let data = chunk.chunk
        
        handle.seekToEndOfFile()
        handle.write(data)
        
        bytesWritten += data.count
        
    }
    
    
    // MARK: close
    func close(){
        fileHandle?.closeFile()
        updateObserversInfo()
    }
    
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

