//
//  Double+Int.swift
//  Warpinator
//
//  Created by William Millington on 2021-05-26.
//
import UIKit




// lazy type compatibility
extension Double {
    
    // MARK: +
    static func + (lhs: Double, rhs: Int) -> Double {
        return lhs + Double(rhs)
    }
    
    static func + (lhs: Int, rhs: Double) -> Double {
        return Double(lhs) + rhs
    }
    
    
    // MARK: \-
    static func - (lhs: Double, rhs: Int) -> Double {
        return lhs - Double(rhs)
    }
    
    static func - (lhs: Int, rhs: Double) -> Double {
        return Double(lhs) - rhs
    }
    
    
    // MARK: *
    static func * (lhs: Double, rhs: Int) -> Double {
        return lhs * Double(rhs)
    }
    
    static func * (lhs: Int, rhs: Double) -> Double {
        return Double(lhs) * rhs
    }
    
    
    // MARK: /
    static func / (lhs: Double, rhs: Int) -> Double {
        return lhs / Double(rhs)
    }
    
    static func / (lhs: Int, rhs: Double) -> Double {
        return Double(lhs) / rhs
    }
}
