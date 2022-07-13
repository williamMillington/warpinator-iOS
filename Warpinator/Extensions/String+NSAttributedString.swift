//
//  String+NSAttributedString.swift
//  Warpinator
//
//  Created by William Millington on 2022-04-29.
//

import Foundation


extension ExtensionManager where Base == String {
    
    //
    // Basically syntactic sugar for creating an attributed string from a given set of
    // attributes
    // MARK: attributed
    func attributed(_ attributes: [NSAttributedString.Key : Any]? ) -> NSAttributedString {
        return NSAttributedString(string: self.base, attributes: attributes)
    }
    
    
    
    
    
    
    
    
    
    
    
}
