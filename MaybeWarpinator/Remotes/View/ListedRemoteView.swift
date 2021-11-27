//
//  ListedRemoteView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit



class ListedRemoteView: UIView {
    
    private let DEBUG_TAG: String = "ListedRemoteView: "
    
    var viewModel: RemoteViewModel?
    
    let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Uknown Device"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let deviceStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Status..."
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    var tapRecognizer: TapGestureRecognizerWithClosure?
    
    
    override init(frame: CGRect){
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    convenience init(withViewModel model: RemoteViewModel, onTap action: @escaping ()->Void = {}){
        self.init()
        
        backgroundColor = UIColor.orange.withAlphaComponent(0.2)
        
        viewModel = model
        viewModel?.onUpdated = {
            self.updateDisplay()
        }
        
        var constraints: [NSLayoutConstraint] = []
        
        addSubview(deviceNameLabel)
        addSubview(deviceStatusLabel)
        
        constraints += [
            
            deviceNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            deviceNameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            deviceStatusLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            deviceStatusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.2)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        
        tapRecognizer = TapGestureRecognizerWithClosure(action: action)
        
        addGestureRecognizer(tapRecognizer!)
        
        updateDisplay()
    }
    
    
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        // Make sure we are updating UI on the main thread!
        DispatchQueue.main.async {
            self.deviceNameLabel.text = viewModel.displayName
            self.deviceStatusLabel.text = viewModel.status
        }
        
        
        
    }
    
    
    
}
