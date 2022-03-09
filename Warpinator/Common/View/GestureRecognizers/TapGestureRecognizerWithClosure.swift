//
//  TapGestureRecognizerWithClosure.swift
//  Warpinator
//
//  Created by William Millington on 2021-03-11.
//

import UIKit


final class TapGestureRecognizerWithClosure: UITapGestureRecognizer {
    private var action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        self.addTarget(self, action: #selector(execute))
    }

    @objc private func execute() {
        action()
    }
}
