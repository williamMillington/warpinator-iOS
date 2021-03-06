//
//  FileManager+Misc.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-12.
//

import Foundation



extension ExtensionManager where Base == FileManager {
    var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
}
