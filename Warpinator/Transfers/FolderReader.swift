//
//  FolderReader.swift
//  Warpinator
//
//  Created by William Millington on 2022-01-09.
//

import Foundation


// MARK: FolderSelection
struct FolderSelection: Hashable {
    
    let type: TransferItemType = .DIRECTORY
    
    let name: String
    let bytesCount: Int = 0
    
    let path: String
    let bookmark: Data
    
}


extension FolderSelection: Equatable {
    static func ==(lhs: FolderSelection, rhs: FolderSelection) -> Bool {
        return lhs.path == rhs.path
    }
}



// MARK: FolderReader
final class FolderReader: NSObject, ReadsFile  {
    
    lazy var DEBUG_TAG: String = "FolderReader: "//"FileReader \"\(filename):\" "
    
    let folder: FolderSelection
    
    var subreaders: [ReadsFile] = []
    var readerIndex: Int = 0
    lazy var currentReader: ReadsFile? = self
    var selectionName: String {
        return folder.name
    }
    
    var accessInProgress: Bool = false
    
    var totalBytes: Int = 0
    
    var observers: [ObservesFileOperation] = []
    
    
    // Assume folder of one level
    init?(for folder: FolderSelection){
        self.folder = folder
        
        super.init()
        
         
        do  {
            
            // ACCESS FOLDER
            var bookmarkIsBad = false
            let folderURL = try URL(resolvingBookmarkData: folder.bookmark, bookmarkDataIsStale: &bookmarkIsBad)


            guard !bookmarkIsBad,
                  folderURL.startAccessingSecurityScopedResource() else {
                print("FolderReader: url denied access")
                return nil
            }
            
            accessInProgress = true
            defer {
                if accessInProgress {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }

            // GRAB ALL ITEMS
            let keys: [URLResourceKey] = [.nameKey, .fileSizeKey, .pathKey, .isDirectoryKey]
            
            guard let files = FileManager.default.enumerator(at: folderURL,
                                                             includingPropertiesForKeys: keys) else {
                print("FolderReader: can't access folder URL")
                return nil
            }
            
            
            // ITERATE THROUGH FOLDER ITEMS
            for case let itemURL as URL in files {
                
                
                guard itemURL.startAccessingSecurityScopedResource() else {
                    print("FolderReader: Could not access scoped url")
                    return
                }
                
                
                // GRAB ITEM DETAILS
                let filename = itemURL.lastPathComponent
                
                var fileKeys: Set<URLResourceKey> = [.nameKey, .fileSizeKey, .isDirectoryKey]
                
                
                if #available(iOS 14.0, *) {  fileKeys.insert(.contentTypeKey)  }
                
                
                let values = try itemURL.resourceValues(forKeys: fileKeys)
                let bookmark = try itemURL.bookmarkData(options: .minimalBookmark,
                                                        includingResourceValuesForKeys: nil, relativeTo: nil)
                
                itemURL.stopAccessingSecurityScopedResource()
                
                
                
                // IF DIRECTORY, create FolderReader
                if let directory = values.isDirectory, directory {
                    
                    let selection = FolderSelection(name: filename, path: itemURL.path, bookmark: bookmark)
                    
                    if let reader = FolderReader(for: selection) {
                        subreaders.append(reader)
                    }
                    
                } else {
                    
                    
                    // IF FILE, create FileReader
                    // There's something I don't like about the following lines.
                    // If we expect that any of this might fail, I feel like it should be handled differently.
                    // Not sure how at the moment.
                    var size = 0
                    if let s = values.fileSize  {
                        size = s
                    }
                    
                    var name = "Name_Error"
                    if let n = values.name {
                        name = n
                    }
                    
                    let selection = FileSelection(name: name, bytesCount: size, path: itemURL.path, bookmark: bookmark)
                    
                    
                    if let reader = FileReader(for: selection) {
                        subreaders.append(reader)
                    }
                }
                
            }
        } catch {
            print("FolderReader: bad URL: \(error)")
            return nil
        }
        
    }
    
    
    // MARK: reinit
    func reinitialize(){
        
    }
    
    
    // MARK: readNextChunk
    func readNextChunk() -> FileChunk? {
        
        guard accessInProgress else {
            print(DEBUG_TAG+"No chunk found")
            updateObserversInfo()
            
            return nil
        }

        
        // TODO: rewrite without 'chunkCheck' outer if
        
        // The first chunk will be the chunk indicating that this is a folder
        chunkCheck: if self === currentReader {
            
            currentReader = nil
            
            return FileChunk.with({
                $0.relativePath = folder.name
                $0.fileType = TransferItemType.DIRECTORY.rawValue
                $0.time = FileTime()
            })
            
        } else { // <- unnecessary 'else'. Gross.
            
            // check if there's are any more readers/chunks
            
            // if current reader is still going, keep going
            if let tempChunk = currentReader?.readNextChunk() {
                
                // append this folder's name to the chunk's relativeFilePath
                let amendedChunk = FileChunk.with {
                    
                    $0.relativePath = folder.name + "/" + tempChunk.relativePath
                    
                    $0.fileType = tempChunk.fileType
                    $0.symlinkTarget = tempChunk.symlinkTarget
                    $0.chunk = tempChunk.chunk
                    $0.fileMode = tempChunk.fileMode
                    $0.time = tempChunk.time
                }
                
                return amendedChunk
            }
            
            // else, move on to next reader
            currentReader?.close()
            
            
            if readerIndex == subreaders.count {
                // no more chunks, no more readers. Break out
                break chunkCheck
            }
            
            currentReader = subreaders[readerIndex]
            readerIndex += 1
            
            return readNextChunk()
        }
        
        
        accessInProgress = false
        
        return nil
        
    }
    
    
    // MARK: close
    func close(){
        
        // closing out anything
        subreaders.forEach {
            $0.close()
        }
        
        accessInProgress = false
        
        updateObserversInfo()

        print(DEBUG_TAG+"Folder is closed")
    }
    
    
    deinit {
        close()
    }
    
}




//MARK: observers
extension FolderReader {
    
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





