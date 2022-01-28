//
//  Data+ChunkIterator.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2022-01-27.
//

import Foundation



struct DataIterator: Sequence, IteratorProtocol {
    let data: Data
    let chunkSize: Int
    private var index = 0
    init(_ data: Data, withChunkSize size: Int){
        self.data = data
        chunkSize = size
    }
    
    mutating func next() -> Data? {
        
        guard index < data.count else { return nil }
        
        var endIndex = index + chunkSize
        if endIndex >= data.count {
            endIndex = data.count - 1
        }
        
        defer {  index = endIndex + 1  }
        
        return Data( data[index...endIndex] )
    }
}


extension Data {
    func iterator(withChunkSize size: Int) -> DataIterator {
        return DataIterator(self, withChunkSize: size)
    }
}
