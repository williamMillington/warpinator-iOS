//
//  TransferViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-24.
//

import UIKit



class TransferViewController: UIViewController {
    
    lazy var DEBUG_TAG: String = "TransferViewController:"
    
    var coordinator: RemoteCoordinator?
    
    let transferDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Transfer"
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
    
    // I don't think pausing a transfer is currently supported by the api
//    let pauseTransferButton: UIButton = {
//        let button = UIButton()
//        button.setTitle("Pause", for: .normal)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.backgroundColor = .blue
//        button.alpha = 0.5 // 'grayed' out while disabled
//        button.isUserInteractionEnabled = false // disabled for inital setup
//        return button
//    }()
    
    
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
    
    
    let backButton: UIButton = {
        let button = UIButton()
        button.setTitle("back", for: .normal)
        button.setTitleColor( .blue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.addTarget(self, action: #selector(back), for: .touchUpInside)
        return button
    }()
    
    
    var remoteViewModel: RemoteViewModel?
    var transferViewModel: TransferOperationViewModel?
    
    
    init(withTransfer t_viewModel: TransferOperationViewModel, andRemote r_viewModel: RemoteViewModel) {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
        
        transferViewModel = t_viewModel
        remoteViewModel = r_viewModel
        
        transferDescriptionLabel.text = "Transfer \(transferViewModel!.direction)"
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        view.addSubview(backButton)
        view.addSubview(transferDescriptionLabel)
        view.addSubview(deviceNameLabel)
        
        view.addSubview(operationsStack)
        
        view.addSubview(cancelTransferButton)
        
        var viewConstraints: [NSLayoutConstraint] = []
        
        let topAnchor = view.safeAreaLayoutGuide.topAnchor
        let sideMargin: CGFloat = 10
        
        viewConstraints +=  [
            
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            backButton.topAnchor.constraint(equalTo: topAnchor, constant: 25),
            
            transferDescriptionLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
            transferDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            deviceNameLabel.topAnchor.constraint(equalTo: transferDescriptionLabel.bottomAnchor, constant: 10),
            deviceNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            operationsStack.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 25),
            operationsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            operationsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
            operationsStack.bottomAnchor.constraint(equalTo: cancelTransferButton.topAnchor, constant: -15),
            
            cancelTransferButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            cancelTransferButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
            cancelTransferButton.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.1),
            cancelTransferButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
            
        ]
        
        NSLayoutConstraint.activate(viewConstraints)
        
    }
    
    
    @objc func back(){
        coordinator?.showRemote()
    }
    

}
