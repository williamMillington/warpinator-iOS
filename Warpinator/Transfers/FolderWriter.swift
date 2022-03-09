//
//  FolderWriter.swift
//  Warpinator
//
//  Created by William Millington on 2022-01-24.
//

import Foundation


// MARK: FolderWriter
final class FolderWriter: NSObject, WritesFile {
    
    static var DEBUG_TAG: String = "FolderWriter (static): "
    lazy var DEBUG_TAG: String = "FolderWriter \(downloadName): "
    
    
    // Names of files, as provided by the client.
    // Used in determining the file in which a given chunk belongs, which may change,
    // depending if we have to rename due to name conflicts
    var downloadName: String
    var downloadRelativePath: String
    
    
    // The values that will be written to the filesystem (renaming feature)
    lazy var fileSystemName: String = downloadName
    var fileSystemParentPath: String
    var fileSystemRelativePath: String { return  fileSystemParentPath + "\(fileSystemName)"  }
    
    var renameCount = 0
    var overwrite = false
    
    
    let baseURL = FileManager.default.extended.documentsDirectory
    var itemURL: URL {
        return baseURL.appendingPathComponent(fileSystemRelativePath)
    }
    
    var completedFiles: [WritesFile] = []
    var currentWriter: WritesFile? = nil
    
    var bytesWritten: Int {
        let currWriterBytes = currentWriter?.bytesWritten ?? 0
        return currWriterBytes + completedFiles.map { return $0.bytesWritten  }.reduce(0, +)
    }
    
    var observers: [ObservesFileOperation] = []
    
    
    
    init(withRelativePath path: String, fileSystemParentPath moddedParentPath: String? = nil, overwrite: Bool) {
        
        downloadRelativePath = path
        
        let pathParts = path.components(separatedBy: "/")
        
        let parentPathParts = pathParts.dropLast()
        let parentPath = parentPathParts.isEmpty  ?  ""  :  parentPathParts.joined(separator: "/") + "/"
        fileSystemParentPath = moddedParentPath ?? parentPath
        
        downloadName = pathParts.last ?? ""
        
        super.init()
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: itemURL.path) {
            
            // Rename
            if !overwrite {
                fileSystemName = rename(downloadName)
            } else { //overwrite
                do {
                    print(DEBUG_TAG+"overwriting preexisting folder...")
                    try fileManager.removeItem(at: itemURL)
                } catch {
                    
                    print(DEBUG_TAG+"Error overwriting folder: \(error)")
                    fileSystemName = rename(downloadName)
                }
            }
            
        }
        
        
        
        // create new directory
        // TODO: rewrite to unambiguously deal with the inability to write
        do {  try fileManager.createDirectory(atPath: itemURL.path,
                                    withIntermediateDirectories: true,
                                    attributes: nil)
            print("created folder called \(fileSystemRelativePath)")
//            print("\t\t(system path: \(itemURL.path))")
        } catch { print(DEBUG_TAG+"Error: can't create folder: \(itemURL.path)") }
        
        
    }
    
    
    // MARK: rename folder
    // TODO: rewrite to be gooder?
    //  - right now 5 renames result in "<name>12345" instead of "<name>5"
    func rename(_ name: String) -> String {

        var newName = "Folder_Renaming_Failed"
        
        while renameCount <= 1000 {
            renameCount += 1
            print("renaming \(name) (\(renameCount))")
            
            newName = name + "\(renameCount)"
            let path = baseURL.path + "/" + fileSystemParentPath + "\(newName)"
            
            if !FileManager.default.fileExists(atPath: path)  {
                break // rename(downloadName)
            }
        }
        
        print(DEBUG_TAG+"new name is \(newName)")
        return newName
    }
    
    
    
    // MARK: processChunk
    func processChunk(_ chunk: FileChunk) throws {
        
        // Check chunk belongs in this folder
        guard isValidSubPath(chunk.relativePath) else {
            print(DEBUG_TAG+"\t\(chunk.relativePath) does not belong in \(downloadRelativePath)")
            throw WritingError.FILENAME_MISMATCH
        }
        
        defer { updateObserversInfo() }
        
        // if we have a writer, try it
        if let writer = currentWriter {
            do {
                try writer.processChunk(chunk)
                return // If successful, we're done here
            } catch WritingError.FILENAME_MISMATCH { // New File/Folder
                    // close out old writer
                    writer.close()
                    completedFiles.append(writer)
            }
        }
        
        // Create writer to handle chunk
        
        // check if folder or file
        if chunk.fileType == TransferItemType.DIRECTORY.rawValue {
            currentWriter = FolderWriter(withRelativePath: chunk.relativePath,
                                         fileSystemParentPath: fileSystemRelativePath + "/",
                                         overwrite: overwrite)
        } else {
            
            currentWriter = FileWriter(withRelativePath: chunk.relativePath,
                                    modifiedRelativeParentPath: fileSystemRelativePath + "/",
                                    overwrite: overwrite)
            
            // - Pass along chunk.
            // - no need to catch, if we still encounter an error here, it's a 'real' error related to writing, and outside the scope of this function
            try currentWriter?.processChunk(chunk)
        }
        
    }
    
    
    //
    //MARK: isValidSubpath
    private func isValidSubPath(_ otherPath: String) -> Bool {
        
        print(DEBUG_TAG+"checking if \(otherPath) is a subpath of \(downloadRelativePath) ")
        
        let pathParts = downloadRelativePath.components(separatedBy: "/")
        let subpathParts = otherPath.components(separatedBy: "/")
        
        // a subpath will contain it's parentpath, so subPathParts.count
        // should always be greater than pathParts.count.
        // If equal, it's the same folder, OR a file with the same name; reject
        guard subpathParts.count > pathParts.count else {
            return false
        }
        
        
        for i in 0..<pathParts.count {
            
            // if -at any point- these parts don't match up, then otherpath does not
            // belong in this folder
            guard let subpathComponent = subpathParts[nullable: i],
                  subpathComponent == subpathParts[i] else {
                return false
            }
        }
        
        return true
    }
    
    
    //
    // MARK: close
    func close() {
        currentWriter?.close()
        currentWriter = nil
        updateObserversInfo()
    }
    
    
    // MARK: fail
    func fail(){
        print(DEBUG_TAG+"\tfailing filewrite:")
        guard currentWriter != nil else { return  }
        
        currentWriter?.fail()
        currentWriter = nil
    }
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


extension FolderWriter: ObservesFileOperation {
    func infoDidUpdate() {
        updateObserversInfo()
    }
}
