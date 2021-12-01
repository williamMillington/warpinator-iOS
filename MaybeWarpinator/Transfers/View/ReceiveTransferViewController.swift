//
//  ReceiveTransferViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-29.
//

import UIKit

class ReceiveTransferViewController: UIViewController {

    lazy var DEBUG_TAG: String = "ReceiveTransferViewController:"
    
    var coordinator: MainCoordinator?
    
    
    let transferDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Transfer from"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let remoteDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "----------"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let acceptButton: UIButton = {
        let button = UIButton()
        button.setTitle("Accept", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .blue
        button.alpha = 0.5 // 'grayed' out while disabled
        button.isUserInteractionEnabled = false // disabled for inital setup
        return button
    }()
    
    let declineButton: UIButton = {
        let button = UIButton()
        button.setTitle("Decline", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .blue
        button.alpha = 0.5 // 'grayed' out while disabled
        button.isUserInteractionEnabled = false // disabled for inital setup
        return button
    }()
    
    
    var viewmodel: ReceiveTransferViewModel?
    
    
    init(withViewModel viewmodel: ReceiveTransferViewModel) {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
        
        self.viewmodel = viewmodel
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        var viewConstraints: [NSLayoutConstraint] = []
        
        view.addSubview(transferDescriptionLabel)
        view.addSubview(remoteDescriptionLabel)
        view.addSubview(acceptButton)
        view.addSubview(declineButton)
        
//        let sideMargin: CGFloat = 10
        
        viewConstraints +=  [
            
            transferDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            transferDescriptionLabel.bottomAnchor.constraint(equalTo: remoteDescriptionLabel.topAnchor, constant: -10),
            
            remoteDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            remoteDescriptionLabel.bottomAnchor.constraint(equalTo: acceptButton.topAnchor, constant: -10),
            
            acceptButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            acceptButton.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -5),
            
            declineButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            declineButton.topAnchor.constraint(equalTo: view.centerYAnchor, constant: 5)
            
            
            
        ]
        
        NSLayoutConstraint.activate(viewConstraints)
        
        
        remoteDescriptionLabel.text = viewmodel?.deviceName ??  "No Device Name"
        
    }
    
    
}
