//
//  ListedTransferView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-28.
//

import UIKit

class ListedTransferView: UIView {

    private let DEBUG_TAG: String = "ListedTransferView: "
    
    var viewModel: TransferOperationViewModel?
    
    let filesLabel: UILabel = {
        let label = UILabel()
        label.text = "Uknown Device"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let transferStatusLabel: UILabel = {
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
    
    
    convenience init(withViewModel model: TransferOperationViewModel, onTap action: @escaping ()->Void = {}){
        self.init()
        
        backgroundColor = UIColor.orange.withAlphaComponent(0.2)
        
        viewModel = model
        viewModel?.onInfoUpdated = {
            self.updateDisplay()
        }
        
        // add subviews and constraints
        setUpView()
        
        // add onTap action
        tapRecognizer = TapGestureRecognizerWithClosure(action: action)
        addGestureRecognizer(tapRecognizer!)
        
        updateDisplay()
    }
    
    
    func setUpView(){
        
        var constraints: [NSLayoutConstraint] = []
        
        addSubview(filesLabel)
        addSubview(transferStatusLabel)
        
        constraints += [
            
            filesLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            filesLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            transferStatusLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            transferStatusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.2)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        filesLabel.text = "\(viewModel.fileCount)"
        transferStatusLabel.text = "\(viewModel.status)"
        
    }

}
