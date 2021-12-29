//
//  ButtonScrollView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-17.
//
import UIKit

//@IBDesignable
class ButtonScrollView: UIScrollView {

    override func touchesShouldCancel(in view: UIView) -> Bool {
        
        if view is UIControl {
            return true
        }
        
        return super.touchesShouldCancel(in: view)
    }
    
//    override func updateConstraints() {
//        print("ButtonScrollView: updating constraints")
//        super.updateConstraints()
//        print("ButtonScrollView: finished updating constraints")
//    }
//
//
//    override func layoutSubviews() {
//        print("ButtonScrollView: laying out subviews")
//        super.layoutSubviews()
//        print("ButtonScrollView: finished laying out subviews")
//    }
    
}

extension ButtonScrollView {
//    func prepareFor
}
