//
//  ChunkIterator.swift
//  Warpinator
//
//  Created by William Millington on 2022-01-09.
//

import Foundation



protocol ReadsFile: NSObject {
    func readNextChunk() -> FileChunk?
    func close()
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
        
        // if the current reader has another chunk, return that chunk
        if let chunk = currentReader.readNextChunk() {
            return chunk
        }
        
        // if not, load the next reader and continue
        currentReader.close()
        readerIndex += 1
        
        // if no more readers
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
