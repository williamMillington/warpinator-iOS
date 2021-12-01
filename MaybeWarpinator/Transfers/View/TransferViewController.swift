//
//  TransferViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-24.
//

import UIKit



class TransferViewController: UIViewController {
    
    lazy var DEBUG_TAG: String = "TransferViewController:"
    
    var coordinator: MainCoordinator?
    
    let directionDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "from/to"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.text = "DeviceName"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let deviceStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "--status--"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let pauseTransferButton: UIButton = {
        let button = UIButton()
        button.setTitle("Pause", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .blue
        button.alpha = 0.5 // 'grayed' out while disabled
        button.isUserInteractionEnabled = false // disabled for inital setup
        return button
    }()
    
    let cancelTransferButton: UIButton = {
        let button = UIButton()
        button.setTitle("Cancel", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .blue
        button.alpha = 0.5 // 'grayed' out while disabled
        button.isUserInteractionEnabled = false // disabled for inital setup
        return button
    }()
    
    
    var operationsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.alignment = .fill
        stack.distribution = .fillProportionally
        stack.spacing = 5
        stack.axis = .vertical
        stack.backgroundColor = UIColor.blue.withAlphaComponent(0.2)
        
        let expanderView = UIView()
        expanderView.translatesAutoresizingMaskIntoConstraints = false
        expanderView.backgroundColor = UIColor.blue.withAlphaComponent(0.2)
        
        // without this, height is constrained to 0 for some dumb reason,
        // and breaks stackview's attempts to resize it
        expanderView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
        
        stack.addArrangedSubview(expanderView)
        
        return stack
    }()
    
    
    
    var remoteViewModel: RemoteViewModel?
    var transferViewModel: TransferOperationViewModel?
    
    
    init(withTransfer t_viewModel: TransferOperationViewModel, andRemote r_viewModel: RemoteViewModel) {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
        
        transferViewModel = t_viewModel
        remoteViewModel = r_viewModel
        
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        
        

    }
    
    
    
    
    

}
