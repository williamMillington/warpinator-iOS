//
//  String+substring.swift
//  NS_MarkVII
//
//  Created by William Millington on 2020-11-23.
//

import Foundation



// lifted from stackoverflow
//
// allows subscripting strings
extension ExtensionManager where Base == String { 
    
    var length: Int {
        return base.count
    }
    
    func substring(fromIndex: Int) -> String {
        return base.extended[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return base.extended[0 ..< max(0, toIndex)]
    }
 
    subscript (i: Int) -> String {
        return base.extended[i ..< i + 1]
    }
    
    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = base.index(base.startIndex, offsetBy: range.lowerBound)
        let end = base.index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(base[start ..< end])
    }
    
    
}



//extension String {
//
////    var length: Int {
////        return count
////    }
//
////    subscript (i: Int) -> String {
////        return self[i ..< i + 1]
////    }
//
////    func substring(fromIndex: Int) -> String {
////        return self[min(fromIndex, length) ..< length]
////    }
////
////    func substring(toIndex: Int) -> String {
////        return self[0 ..< max(0, toIndex)]
////    }
//
////    subscript (r: Range<Int>) -> String {
////        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
////                                            upper: min(length, max(0, r.upperBound))))
////        let start = index(startIndex, offsetBy: range.lowerBound)
////        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
////        return String(self[start ..< end])
////    }
//}
