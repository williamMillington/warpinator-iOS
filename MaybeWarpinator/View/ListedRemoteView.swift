//
//  ListedRemoteView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit



class ListedRemoteView: UIView {
    
    var viewModel: RemoteViewModel?
    
    let stackview: UIStackView = {
       let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Uknown Device"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    let deviceStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Status..."
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    override init(frame: CGRect){
        super.init(frame: frame)
//        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
//        setup()
    }
    
    
    convenience init(withViewModel model: RemoteViewModel){
        self.init()
        
        viewModel = model
        
        
        var constraints: [NSLayoutConstraint] = []
        
        addSubview(stackview)
        
        constraints += [
            stackview.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackview.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackview.topAnchor.constraint(equalTo: topAnchor),
            stackview.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        stackview.addArrangedSubview(deviceNameLabel)
        stackview.addArrangedSubview(deviceStatusLabel)
    }
    
}
