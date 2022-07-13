//
//  LoadingMessageView.swift
//  Warpinator
//
//  Created by William Millington on 2022-04-27.
//

import UIKit

final class LoadingMessageView: UIView {
    
    private let DEBUG_TAG: String = "LoadingMessageView: "
    
    let loadingTextLabel: UILabel = {
        let label = UILabel()
        label.text = "Server is starting up, please wait... "
        label.textColor = Utils.textColour
        label.tintColor = Utils.textColour
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    override init(frame: CGRect){
        super.init(frame: frame)
        setUpView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpView()
    }
    
    
    convenience init(){
        self.init(frame: .zero)
        
        // add subviews and constraints
        setUpView()
        
    }
    
    
    //
    // MARK: setUpView
    func setUpView(){
        
        addSubview(loadingTextLabel)
        
        let constraints = [
            loadingTextLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingTextLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
//        backgroundColor = UIColor.blue.withAlphaComponent(0.5)
        backgroundColor = Utils.backgroundColour
        
    }
    
}
