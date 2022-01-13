//
//  FolderReader.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2022-01-09.
//

import Foundation


// MARK: FolderSelection
struct FolderSelection: Hashable
//                        , TransferSelection
{
    
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
//    let fileExtension: String
    
//    var fileURL: URL
//    let filepath: String
//    var relativeFilePath: String {
//        return filename //+ "." + fileExtension
//    }
//    var fileHandle: FileHandle
    
    
    var accessInProgress: Bool = false
    
    
    var totalBytes: Int = 0
    var sent = 0
    var readHead: UInt64 = 0
    
    
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

//            var error: NSError? = nil
//            NSFileCoordinator().coordinate(readingItemAt: folderURL, error: &error) { url in
            
            // GRAB ALL ITEMS
            let keys: [URLResourceKey] = [.nameKey, .fileSizeKey, .pathKey, .isDirectoryKey]
            
            guard let files = FileManager.default.enumerator(at: folderURL,
                                                             includingPropertiesForKeys: keys) else {
                print("FolderReader: can't access folder URL")
                return nil
            }
            
            
//            let topLevelName = folder.name
            
            
            
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
                    
//                    if directory {
                        //DO SOMTHNG ABOUT DICTRES
//                        print("FolderReader: IS DIRECTORY")
                        
                        let selection = FolderSelection(name: filename, path: itemURL.path, bookmark: bookmark)
                        
                        if let reader = FolderReader(for: selection) {
                            subreaders.append(reader)
                        }
                        
                        
//                        continue
//                    }
                    
                } else {
                
                
                    // IF FILE, create FileReader
                    // There's something I don't like about the following lines.
                    // If we expect that any of this might fail, I feel like it should be handled differently.
                    // Not sure how. Smells funny.
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
            print("FolderReader: sumin fucked up URL: \(error)")
            return nil
        }
        
        
        
        
//        filename = file.name
//        totalBytes = file.bytesCount
//        filepath = file.path
//
//        do {
//            var bookmarkIsBad = false
//            fileURL = try URL(resolvingBookmarkData: file.bookmark, bookmarkDataIsStale: &bookmarkIsBad)
//
//
//            guard !bookmarkIsBad,
//                  fileURL.startAccessingSecurityScopedResource() else {
//                print("FileReader: url denied access")
//                return nil
//            }
//
//            fileIsBeingAccessed = true
//            fileHandle = try FileHandle(forReadingFrom: fileURL)
//
//        } catch {
//
//            print("FileReader: Could not load bookmarked URL: \(error)")

//        }
        
    }
    
    
    // MARK: reinit
    func reinitialize(){
        
        sent = 0
        readHead = 0
        
//        do {
//            var bookmarkIsBad = false
//            fileURL = try URL(resolvingBookmarkData: file.bookmark, bookmarkDataIsStale: &bookmarkIsBad)
//
//
//            guard !bookmarkIsBad,
//                fileURL.startAccessingSecurityScopedResource() else {
//                print("FileReader: url denied access"); return
//            }
//
//            fileIsBeingAccessed = true
//            fileHandle = try FileHandle(forReadingFrom: fileURL)
//
//        } catch {
//            print("FileReader: Could not load bookmarked URL: \(error)")
//        }
        
    }
    
    
    // MARK: readNextChunk
    func readNextChunk() -> FileChunk? {
        
//        print(DEBUG_TAG+"\tReading next chunk")
//        print(DEBUG_TAG+"\tsent: \(sent)")
//        print(DEBUG_TAG+"\tfileOffset: \(fileHandle.offsetInFile)")
//        print(DEBUG_TAG+"\tread-head: \(readHead)")
//        print(DEBUG_TAG+"\ttotal: \(totalBytes)")

        
        guard accessInProgress
//              ,fileHandle.offsetInFile < totalBytes
        else {

            updateObserversInfo()

//            fileHandle.closeFile()
            accessInProgress = false
//            fileURL.stopAccessingSecurityScopedResource()

            print(DEBUG_TAG+"No more data to be read"); return nil
        }

        
        // The first chunk will be the chunk indicating that there is a folder
        chunkCheck: if self === currentReader {
            
            currentReader = nil
            
            return FileChunk.with({
                $0.relativePath = folder.name
                $0.fileType = TransferItemType.DIRECTORY.rawValue
                $0.time = FileTime()
            })
            
        } else {
            
            // check if there's a chunk to return, return nil otherwise
            
            // if current reader is still going, keep going
            if let tempChunk = currentReader?.readNextChunk() {
                
                // (append this folder's name to its the chunk's relativeFilePath)
                let amendedRelativeFilePath = folder.name + "/" + tempChunk.relativePath
                
                // Copy all other FileChunk fields from tempchunk
                let amendedChunk = FileChunk.with {
                    
                    $0.relativePath = amendedRelativeFilePath
                    
                    $0.fileType = tempChunk.fileType
                    $0.symlinkTarget = tempChunk.symlinkTarget
                    $0.chunk = tempChunk.chunk
                    $0.fileMode = tempChunk.fileMode
                    $0.time = tempChunk.time
                }
                
                
                return amendedChunk
            }
            
            currentReader?.close()
            
            if readerIndex == subreaders.count {
                // no more chunks, no more readers
                break chunkCheck
            }
            
            currentReader = subreaders[readerIndex]
            readerIndex += 1
            
            return readNextChunk()
        }
        
        
        accessInProgress = false
        
        return nil

//        fileHandle.seek(toFileOffset: readHead)
//
//
//        let datachunk = fileHandle.readData(ofLength: SendFileOperation.chunk_size)
//
//        let fileChunk: FileChunk = .with {
//            $0.relativePath = relativeFilePath
//            $0.fileType = TransferItemType.FILE.rawValue
//            $0.chunk = datachunk //Data(bytes: datachunk, count: datachunk.count)
//        }
//
//        sent += datachunk.count
//        readHead += UInt64( datachunk.count )
//
//        updateObserversInfo()
        
//        return fileChunk
        
    }
    
    
    // MARK: close
    func close(){
        
        // closing out anything
        subreaders.forEach {
            $0.close()
        }
        
//        fileHandle.closeFile()
//        fileIsBeingAccessed = false
//        fileURL.stopAccessingSecurityScopedResource()
//
//        updateObserversInfo()
//
//        print(DEBUG_TAG+"File is closed")
    }
    
    
    deinit {
        close()
//        if accessInProgress { // in case of interruption
////            fileURL.stopAccessingSecurityScopedResource()
//        }
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





