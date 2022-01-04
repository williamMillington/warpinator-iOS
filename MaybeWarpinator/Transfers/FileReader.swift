//
//  FileReader.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-15.
//

import Foundation



protocol ReadsFile {
    func readNextChunk() -> FileChunk?
}


// MARK: FileSelection
struct FileSelection: Hashable {
    
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
final class FileReader: ReadsFile  {
    
    lazy var DEBUG_TAG: String = "FileReader \"\(filename):\" "
    
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
        
//        print(DEBUG_TAG+"\tReading next chunk")
//        print(DEBUG_TAG+"\tsent: \(sent)")
//        print(DEBUG_TAG+"\tfileOffset: \(fileHandle.offsetInFile)")
//        print(DEBUG_TAG+"\tread-head: \(readHead)")
//        print(DEBUG_TAG+"\ttotal: \(totalBytes)")

        
        
        guard fileIsBeingAccessed,
              fileHandle.offsetInFile < totalBytes else {
            
            updateObserversInfo()
            
            fileHandle.closeFile()
            fileIsBeingAccessed = false
            fileURL.stopAccessingSecurityScopedResource()
            
            print(DEBUG_TAG+"No more data to be read"); return nil
        }
        
        
        fileHandle.seek(toFileOffset: readHead)
        
        
        let datachunk = fileHandle.readData(ofLength: SendFileOperation.chunk_size)
        
        let fileChunk: FileChunk = .with {
            $0.relativePath = relativeFilePath
            $0.fileType = FileType.FILE.rawValue
            $0.chunk = datachunk //Data(bytes: datachunk, count: datachunk.count)
        }

        sent += datachunk.count
        readHead += UInt64( datachunk.count )

        updateObserversInfo()
        
        return fileChunk
    }
    
    
    // MARK: close
    func close(){
        
        fileHandle.closeFile()
        fileIsBeingAccessed = false
        fileURL.stopAccessingSecurityScopedResource()
        
        updateObserversInfo()
        
        print(DEBUG_TAG+"File is closed")
    }
    
    
    deinit {
        if fileIsBeingAccessed { // in case of interruption
            fileURL.stopAccessingSecurityScopedResource()
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






// MARK: ChunkIterator
// Manages the iteration of multiple FileSelectionReaders
final class ChunkIterator {
    
    
    var fileReaders: [ReadsFile]
    
    var readerIndex = 0
    var currentReader: ReadsFile
    
    
    init(for readers: [ReadsFile]){
        fileReaders = readers
        currentReader = fileReaders[0]
    }
    
    
    func nextChunk() -> FileChunk? {
        
        // if the current reader has another chunk, return it
        if let chunk = currentReader.readNextChunk() {
            return chunk
        }
        
        // if not, load the next reader and continue
        readerIndex += 1
        
        // no more readers
        if readerIndex >= fileReaders.count {
            return nil
        }
        
        currentReader = fileReaders[readerIndex]
        return nextChunk() // I created o̶b̶s̶c̶u̶r̶i̶t̶y̶ elegance through recursion! My degree wasn't useless!
    }
}


extension ChunkIterator: Sequence, IteratorProtocol {
    typealias Element = FileChunk
    
    func next() -> FileChunk? {
        return nextChunk()
    }
}
