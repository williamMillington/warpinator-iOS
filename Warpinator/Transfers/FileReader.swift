//
//  FileReader.swift
//  Warpinator
//
//  Created by William Millington on 2021-12-15.
//

import Foundation



// MARK: FileSelection
struct FileSelection: Hashable {
    
    let type: TransferItemType = .FILE
    
    let name: String
    let bytesCount: Int
    
    let path: String
    let bookmark: Data
    
}

extension FileSelection: Equatable {
    static func ==(lhs: FileSelection, rhs: FileSelection) -> Bool {
        return lhs.path == rhs.path
    }
}



// MARK: FileReader
final class FileReader: NSObject, ReadsFile {
    
    lazy var DEBUG_TAG: String = "FileReader \"\(filename)\": "
    
    let file: FileSelection
    
    let filename: String
//    let fileExtension: String
    
    var fileURL: URL
    let filepath: String
    var relativeFilePath: String {
        return filename //+ "." + fileExtension
    }
    var fileHandle: FileHandle
    
    
    var fileIsBeingAccessed: Bool = false
    
    
    var totalBytes: Int
    var sent = 0
    var readHead: UInt64 = 0
    
    
    var observers: [ObservesFileOperation] = []
    
    
    init?(for file: FileSelection){
        
        self.file = file
        
        filename = file.name
        totalBytes = file.bytesCount
        filepath = file.path
        
        do {
            var bookmarkIsBad = false
            fileURL = try URL(resolvingBookmarkData: file.bookmark, bookmarkDataIsStale: &bookmarkIsBad)
            
            
            guard !bookmarkIsBad,
                  fileURL.startAccessingSecurityScopedResource() else {
                print("FileReader: url denied access")
                return nil
            }
            
            fileIsBeingAccessed = true
            fileHandle = try FileHandle(forReadingFrom: fileURL)
            
        } catch {
            
            print("FileReader: Could not load bookmarked URL: \(error)")
            
            return nil
        }
        
    }
    
    // MARK: reinit
    func reinitialize(){
        
        sent = 0
        readHead = 0
        
        do {
            var bookmarkIsBad = false
            fileURL = try URL(resolvingBookmarkData: file.bookmark, bookmarkDataIsStale: &bookmarkIsBad)
            
            guard !bookmarkIsBad,
                fileURL.startAccessingSecurityScopedResource() else {
                print("FileReader: url denied access"); return
            }
            
            fileIsBeingAccessed = true
            fileHandle = try FileHandle(forReadingFrom: fileURL)
            
        } catch {
            print("FileReader: Could not load bookmarked URL: \(error)")
        }
    }
    
    
    // MARK: readNextChunk
    func readNextChunk() -> FileChunk? {
        
        defer { updateObserversInfo() }
        
        guard fileIsBeingAccessed,
              fileHandle.offsetInFile < totalBytes else {
            
//            updateObserversInfo()
            print(DEBUG_TAG+"No more data.")
            return nil
        }
        
        fileHandle.seek(toFileOffset: readHead)
        
        let datachunk = fileHandle.readData(ofLength: SendFileOperation.chunk_size)
        
        let fileChunk: FileChunk = .with {
            $0.relativePath = relativeFilePath
            $0.fileType = TransferItemType.FILE.rawValue
            $0.chunk = datachunk
        }

        sent += datachunk.count
        readHead += UInt64( datachunk.count )

//        updateObserversInfo()
        
        return fileChunk
    }
    
    
    // MARK: close
    func close(){
        
        defer { updateObserversInfo() }
        
        guard fileIsBeingAccessed else { return }
        
        fileHandle.closeFile()
        fileIsBeingAccessed = false
        fileURL.stopAccessingSecurityScopedResource()
        
        print(DEBUG_TAG+"File is closed")
    }
    
    
    deinit {
        if fileIsBeingAccessed { // in case of interruption during access
            close()
        }
    }
    
}




//MARK: observers
extension FileReader {
    
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





