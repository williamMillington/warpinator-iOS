//
//  ListedFileViewModel.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-02.
//

import Foundation


protocol ListedFileViewModel {
    
    var onUpdated: ()->Void { get set }
    
    var type: String { get }
    var name: String { get }
    var size: String { get }
    var progress: Double { get }
    
}
