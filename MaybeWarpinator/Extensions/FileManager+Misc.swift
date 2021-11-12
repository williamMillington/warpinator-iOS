//
//  FileManager+Misc.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-12.
//

import Foundation


extension FileManager{
    
    var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
}
