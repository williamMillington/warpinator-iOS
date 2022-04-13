//
//  ExtensionManagement.swift
//  Warpinator
//
//  Created by William Millington on 2021-05-25.
//

import UIKit
import NIOSSL

/* Allows custom type-extensions to be grouped under
 the ExtensionManager namespace 'extended' .
 
 Ex.  By writing extensions on UIView as:
 
        extension UIView: ExtensionManagerCompatible {}
 
 followed by:
 
        extension ExtensionManager: where Base == UIView {
            func someCustomStringFunction() { ... }
        }
 
 This is accessed with:
 
        myUIView.extended.someCustomStringFunction()
 
 instead of the usual:
 
        myUIView.someCustomStringFunction()
 
 This is helpful for keeping track of custom implemented functions
 when reading/refactoring/moving code between projects (especially when a custom function really feels like it should have been included by default *cough*substrings*coughcough*).
*/

public protocol ExtensionManagerCompatible {
    associatedtype baseType
    var extended: baseType { get }
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



// MARK: - Swift Foundation Types
extension Int: ExtensionManagerCompatible {}

extension Double: ExtensionManagerCompatible {} // also affects TimeInterval

extension CGFloat: ExtensionManagerCompatible {}

extension Array: ExtensionManagerCompatible {}

extension String: ExtensionManagerCompatible {}

extension Data: ExtensionManagerCompatible {}



// MARK: - Apple Types
extension NSAttributedString: ExtensionManagerCompatible {}

extension UIColor: ExtensionManagerCompatible {}

extension UIViewController: ExtensionManagerCompatible {}

extension FileManager: ExtensionManagerCompatible {}

extension NIOSSLCertificate: ExtensionManagerCompatible {}

