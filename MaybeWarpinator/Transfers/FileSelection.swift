//
//  FileSelection.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-14.
//

import Foundation



struct FileSelection {
    
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
