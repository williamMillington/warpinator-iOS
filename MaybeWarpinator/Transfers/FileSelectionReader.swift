//
//  FileSelectionReader.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-15.
//

import Foundation



class FileSelectionReader: ReadsFile  {
    
    lazy var DEBUG_TAG: String = "FileSelectionReader \"\(filename):\" "
    
    let filename: String
//    let fileExtension: String
    
    let fileURL: URL
    var fileIsBeingAccessed: Bool = false
    let filepath: String
    var relativeFilePath: String {
        return filename //+ "." + fileExtension
    }
    let fileHandle: FileHandle
    
    
    var totalBytes: Int
    var sent = 0
    var readHead: UInt64 = 0
    
    
    var observers: [ListedFileSelectionReaderViewModel] = []
    
    
    init?(for file: FileSelection){
        
        filename = file.name
        totalBytes = file.bytesCount
        filepath = file.path
        
        do {
            var bookmarkIsBad = false
            fileURL = try URL(resolvingBookmarkData: file.bookmark, bookmarkDataIsStale: &bookmarkIsBad)
            
            
            guard !bookmarkIsBad,
                  fileURL.startAccessingSecurityScopedResource() else {
                print("FileSelectionReader: url denied access")
                return nil
            }
            
            fileIsBeingAccessed = true
            fileHandle = try FileHandle(forReadingFrom: fileURL)
            
        } catch {
            
            print("FileSelectionReader: Could not load bookmarked URL: \(error)")
            
            return nil
        }
        
        
//        filepath = Bundle.main.path(forResource: filename,
//                                    ofType: fileExtension)!
//        fileURL = URL(fileURLWithPath: filepath)
//
//        loadFileData()
//        updateObserversInfo()
    }
    
    
    func reset(){
        sent = 0
        readHead = 0
    }
    
//    func loadFileData(){
//
//
//
//
//    }
    
    
    func readNextChunk() -> FileChunk? {
        
        print(DEBUG_TAG+"\tReading next chunk")
        print(DEBUG_TAG+"\tsent: \(sent)")
        print(DEBUG_TAG+"\tfileOffset: \(fileHandle.offsetInFile)")
        print(DEBUG_TAG+"\tread-head: \(readHead)")
        print(DEBUG_TAG+"\ttotal: \(totalBytes)")

        
        
        guard fileHandle.offsetInFile < totalBytes else {
            
            updateObserversInfo()
            
            fileHandle.closeFile()
            fileURL.stopAccessingSecurityScopedResource()
            fileIsBeingAccessed = false
            
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
    
    
    
    deinit {
        if fileIsBeingAccessed { // in case of interruption
            fileURL.stopAccessingSecurityScopedResource()
        }
    }
    
}





////MARK: -
////MARK: - sequence
//
//
//
////MARK: iterator
//extension FileSelectionReader: Sequence, IteratorProtocol {
//    typealias Element = FileChunk
//
//    func next() -> FileChunk? {
//        return readNextChunk()
//    }
//}


//MARK: observers
extension FileSelectionReader {
    
    func addObserver(_ model: ListedFileSelectionReaderViewModel){
        observers.append(model)
    }
    
    func removeObserver(_ model: ListedFileSelectionReaderViewModel){
        
        for (i, observer) in observers.enumerated() {
            if observer === model {
                observers.remove(at: i)
            }
        }
    }
    
    func updateObserversInfo(){
//        observers.forEach { observer in
//            observer.update()
//        }
    }
}
