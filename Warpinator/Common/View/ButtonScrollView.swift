//
//  ButtonScrollView.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-17.
//
import UIKit

// Allows UIScrollView to passthrough touches to button subviews
final class ButtonScrollView: UIScrollView {

    override func touchesShouldCancel(in view: UIView) -> Bool {
        
        if view is UIControl {
            return true
        }
        
        return super.touchesShouldCancel(in: view)
    }
}
