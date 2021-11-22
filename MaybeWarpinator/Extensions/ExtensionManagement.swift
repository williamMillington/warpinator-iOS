//
//  ExtensionManagement.swift
//  NoteScore
//
//  Created by William Millington on 2021-05-25.
//

import UIKit




public protocol ExtensionManagerCompatible {
    associatedtype someType
    var extended: someType { get }
}


public extension ExtensionManagerCompatible {
    var extended: ExtensionManager<Self> {
        get { return ExtensionManager(self) }
    }
}


public struct ExtensionManager<Base> {
    let base: Base
    init(_ base: Base ){
        self.base = base
    }
}


// MARK: - Foundation Types
extension Int: ExtensionManagerCompatible {}

extension Double: ExtensionManagerCompatible {} // also counts for TimeInterval

extension CGFloat: ExtensionManagerCompatible {}

extension Array: ExtensionManagerCompatible {}

extension String: ExtensionManagerCompatible {}



// MARK: - Apple Types
extension NSAttributedString: ExtensionManagerCompatible {}

extension UIColor: ExtensionManagerCompatible {}

extension UIViewController: ExtensionManagerCompatible {}

extension FileManager: ExtensionManagerCompatible {}
