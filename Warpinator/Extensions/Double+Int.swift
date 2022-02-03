//
//  Double+Int.swift
//  NoteScore
//
//  Created by William Millington on 2021-05-26.
//
import UIKit





extension Double {
    
    static func + (lhs: Double, rhs: Int) -> Double {
        return lhs + Double(rhs)
    }
    
    static func + (lhs: Int, rhs: Double) -> Double {
        return Double(lhs) + rhs
    }
    
    
    static func - (lhs: Double, rhs: Int) -> Double {
        return lhs - Double(rhs)
    }
    
    static func - (lhs: Int, rhs: Double) -> Double {
        return Double(lhs) - rhs
    }
    
    
    static func * (lhs: Double, rhs: Int) -> Double {
        return lhs * Double(rhs)
    }
    
    static func * (lhs: Int, rhs: Double) -> Double {
        return Double(lhs) * rhs
    }
    
    
    static func / (lhs: Double, rhs: Int) -> Double {
        return lhs / Double(rhs)
    }
    
    static func / (lhs: Int, rhs: Double) -> Double {
        return Double(lhs) / rhs
    }
}
