//
//  FolderWriter.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2022-01-24.
//

import Foundation


// MARK: FolderWriter
class FolderWriter: WritesFile {
    
    static var DEBUG_TAG: String = "FolderWriter (static): "
    lazy var DEBUG_TAG: String = "FolderWriter \(originalName): "
    
    var originalName: String
    var originalRelativePath: String
    
    // used if any of parent folders were renamed due to conflicts
    var modifiedRelativePath: String?
    
    var completedChildWriters: [WritesFile] = []
    var currentWriter: WritesFile? = nil
    
    
    lazy var writtenName: String = originalName
    
    var writtenParentPath: String {
        var path = originalRelativePath
        if let modpath = modifiedRelativePath {  path = modpath  }
        
        let pathParts = path.components(separatedBy: "/")
        let parentPathParts = pathParts.dropLast()
        
        
        //TODO: possibly needs to include edge-case <count == 1>?
        let parentPath = parentPathParts.count == 0 ? "" : parentPathParts.joined(separator: "/") + "/"
//            parentPathParts.reduce("") { x, y in
//            return x + "/" + y
//        } + "/"
        
        print(DEBUG_TAG+"writtenParentPath is \(parentPath)")
        return parentPath
    }
    
    var writtenRelativePath: String {
        
        var path = originalRelativePath
        if let modpath = modifiedRelativePath {  path = modpath  }
        
        
        let pathParts = path.components(separatedBy: "/")
        let parentPathParts = pathParts.dropLast()
        
        //TODO: possibly needs to include edge-case <count == 1>?
        let parentPath = parentPathParts.count == 0 ? "" : parentPathParts.joined(separator: "/") + "/"
//        parentPathParts.reduce("") { x, y in
//            return x + "/" + y
//        } + "/"
        
        print(DEBUG_TAG+"writtenRelativePath is \(  (parentPath+"\(writtenName)")   )")
        return  parentPath+"\(writtenName)"
    }
    
    var renameCount = 0
    
    
    
    let baseURL = FileManager.default.extended.documentsDirectory
    var folderURL: URL {
        return baseURL.appendingPathComponent(writtenRelativePath)
    }
    
    var folderPath: String {
        return folderURL.path
    }
    
    var writtenBytesCount: Int = 0
    var overwrite: Bool = false
    
    var observers: [ObservesFileOperation] = []
    
    
//    init(foldername name: String){
//        foldername = name
//        basePath = foldername
//    }
    
    
    init(withRelativePath path: String, modifiedRelativeParentPath modPath: String? = nil, overwrite: Bool) {
        
        originalRelativePath = path
        modifiedRelativePath = modPath
        
        let pathParts = path.components(separatedBy: "/")
        
        originalName = pathParts.last ?? ""
        
        
        if let modPath = modPath {
            modifiedRelativePath = modPath + "/\(originalName)"
        }
        
        
        let fileManager = FileManager.default
//        let directoryURL = fileManager.extended.documentsDirectory.appendingPathComponent("\(foldername)")
        
//        print(DEBUG_TAG+"attempting to create new directory: \(directoryURL.path)")
        
        if fileManager.fileExists(atPath: folderPath) {
//            print(DEBUG_TAG+"\t \(directoryURL.path) already exists")
//            throw WritingError.DIRECTORY_EXISTS
            
            
            // Rename
            if !overwrite {
                
                writtenName = rename(originalName)
                
                
            } else { //overwrite
                print(DEBUG_TAG+"")
                do {
                    print(DEBUG_TAG+"deleting preexisting folder...")
                    try fileManager.removeItem(at: folderURL)
                } catch {
                    
                    print(DEBUG_TAG+"Error overwriting folder: \(error)")
                    writtenName = rename(originalName)
                }
            }
            
        }
        
        
        
        // create new directory
        // TODO: rewrite to unambiguously deal with the inability to write
        do {  try fileManager.createDirectory(atPath: folderPath,
                                    withIntermediateDirectories: true,
                                    attributes: nil)
            print("created folder called \(writtenRelativePath)")
            print("\t\t(system path: \(folderPath))")
        } catch { print(DEBUG_TAG+"Error: can't create folder: \(folderPath)") }
        
        
//        else {
//            do {
//                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
////                print(DEBUG_TAG+"\tSuccessfully created directory")
//            } catch {
////                print(DEBUG_TAG+"\tFailed to create directory")
//                throw WritingError.UNDEFINED_ERROR(error)
//            }
//        }
        
        
        
        
        
        
    }
    
    
    // MARK: rename folder
    // TODO: rewrite to be gooder?
    //  - right now 5 renames result in "<name>12345" instead of "<name>5"
    func rename(_ name: String) -> String {
        
        print(DEBUG_TAG+"Renaming \(name)")
        
        var newName = "Folder_Renaming_Failed"
        renameCount += 1
        
        if renameCount <= 1000 {
            
            newName = name + "\(renameCount)"
            
            let path = baseURL.path + "/" + writtenParentPath + "\(newName)"
            
            print(DEBUG_TAG+"checking for existence of \(path)")
            
            if FileManager.default.fileExists(atPath: path)  {
                return rename(newName)
            }
        }
        
        
        modifiedRelativePath = writtenParentPath + "\(newName)"
        
        print(DEBUG_TAG+"new name is \(newName)")
        print(DEBUG_TAG+"\t\told relativePath \(originalRelativePath)")
        print(DEBUG_TAG+"\t\tnew relativePath \(modifiedRelativePath!)")
        
        return newName
    }
    
    
    
    // MARK: processChunk
    func processChunk(_ chunk: FileChunk) throws {
        
        
        // CHECK IF RELATIVE PATH IS SUB-PATH
//        print(DEBUG_TAG+"comparing relative paths")
//        print(DEBUG_TAG+"\tfolder originalRelativePath: \(originalRelativePath)")
//        print(DEBUG_TAG+"\tchunk relativePath: \(chunk.relativePath)")
        
        guard isValidSubPath(chunk.relativePath) else {
            print(DEBUG_TAG+"\t\(chunk.relativePath) does not belong in \(originalRelativePath)")
            throw WritingError.FILENAME_MISMATCH
        }
        
        
        
        
        if let writer = currentWriter {
            
            do {
                try writer.processChunk(chunk)
                return // If no error, we're done here
            } catch WritingError.FILENAME_MISMATCH {

                    // close out old writer
                    writer.close()
                    completedChildWriters.append(writer)
                    
            }
        }
            // New item!
            
            // check if folder or file
        if chunk.fileType == TransferItemType.DIRECTORY.rawValue {
            currentWriter = FolderWriter(withRelativePath: chunk.relativePath,
                                         modifiedRelativeParentPath: modifiedRelativePath,
                                         overwrite: overwrite)
        } else {
            
            // create file writer
            let writer = FileWriter(withRelativePath: chunk.relativePath,
                                    modifiedRelativeParentPath: modifiedRelativePath ,
                                    overwrite: overwrite)
            
            
            currentWriter = writer
            
            
            // - Pass along chunk.
            // - If we still encounter an error here, it's a 'real' error related to writing, and outside the scope
            // of this function
            try currentWriter?.processChunk(chunk)
        }
        
        
        
    }
    
    
    
    //MARK: isValidSubpath
    private func isValidSubPath(_ otherPath: String) -> Bool {
        
        print(DEBUG_TAG+"checking if \(otherPath) is a subpath of \(originalRelativePath) ")
        
        let pathParts = originalRelativePath.components(separatedBy: "/")
        let subpathParts = otherPath.components(separatedBy: "/")
        
        // if a subpath will necessarily contain it's parent path, so subPathParts.count
        // should never be less than pathParts.count.
        // If they're equal, then that just the same folder, OR a file with the same name,
        // which we should also not accept
        // TODO: POSSIBLE BUG. IF WE SEND/RECEIVE A SUBFOLDER WITH THE SAME NAME AS A TOP-LEVEL FOLDER...
        // PROBLEMS?
        // For receiving, this should be dealt with before we reach this stage, as it would be renamed before this
        // in FolderWriter.init
        guard subpathParts.count > pathParts.count else {
            return false
        }
        
        
        // if -at any point- these bad boys don't match up, then otherpath does not
        // belong in this folder
        for i in 0..<pathParts.count {
            
            let pathComponent = pathParts[i]
            let subpathComponent = subpathParts[i]
            
            print(DEBUG_TAG+"\tpathComponent: \(pathComponent)")
            print(DEBUG_TAG+"\tsubpathComponent: \(subpathComponent)")
            
            if pathComponent != subpathComponent {
                return false
            }
        }
        
        return true
    }
    
    
    
    func close() {
        
        currentWriter?.close()
        updateObserversInfo()
        
    }
    
    
    
//    // MARK: write
//    func write(_ data: Data){
////        print(DEBUG_TAG+"\t\t writing to file...")
////
////        guard let handle = fileHandle else {
////            print(DEBUG_TAG+"\t\tERROR: writing to file failed...")
////            return
////        }
////
////        handle.seekToEndOfFile()
////        handle.write(data)
////
////        writtenBytesCount += data.count
//        updateObserversInfo()
//    }
    
    
    // MARK: finish
//    func finish(){
////        fileHandle?.closeFile()
//        updateObserversInfo()
//    }
    
    
    // MARK: fail
//    func fail(){
////        print(DEBUG_TAG+"\tfailing filewrite:")
////        fileHandle?.closeFile()
////
////        // delete unfinished file
////        let fileManager = FileManager.default
////        do {
////            print(DEBUG_TAG+"\tDeleting unfinished file: \(filepath)")
////            try fileManager.removeItem(atPath: filepath)
////        } catch {
////            print(DEBUG_TAG+"\tAn error occurred attempting to delete file: \(filepath)")
////        }
//        updateObserversInfo()
//    }
    
    // MARK: static createDir
//    static func createNewDirectory(withName name: String) throws {
//
//        let fileManager = FileManager.default
//        let directoryURL = fileManager.extended.documentsDirectory.appendingPathComponent("\(name)")
//
////        print(DEBUG_TAG+"attempting to create new directory: \(directoryURL.path)")
//
//        if fileManager.fileExists(atPath: directoryURL.path) {
////            print(DEBUG_TAG+"\t \(directoryURL.path) already exists")
//            throw FolderReceiveError.DIRECTORY_EXISTS
//        } else {
//            do {
//                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
////                print(DEBUG_TAG+"\tSuccessfully created directory")
//            } catch {
////                print(DEBUG_TAG+"\tFailed to create directory")
//                throw FolderReceiveError.SYSTEM_ERROR(error)
//            }
//        }
//    }
}



//MARK: observers
extension FolderWriter {
    
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
