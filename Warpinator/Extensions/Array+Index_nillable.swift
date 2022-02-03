//
//  Array+Index_nillable.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-22.
//

import Foundation




extension Array {
    
    subscript(nullable index: Index) -> Element? {
        let indexIsValid = index >= 0 && index < count
        return indexIsValid ? self[index] : nil
    }
    
}
