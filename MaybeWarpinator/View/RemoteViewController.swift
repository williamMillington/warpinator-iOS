//
//  RemoteViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-18.
//

import UIKit

class RemoteViewController: UIViewController {

    
    var coordinator: MainCoordinator?
    
    
    let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Uknown Device"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let usernameLabel: UILabel = {
        let label = UILabel()
        label.text = "UknownUser@UknownDevice"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let ipaddressLabel: UILabel = {
        let label = UILabel()
        label.text = "IP.un.kno.wn"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    var transfersLabel: UILabel = {
        let label = UILabel()
        label.text = "Transfers:"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    var transfersStack: UIStackView = {
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
    
    
    
    let sendFilesButton:UIButton = {
        let button = UIButton()
        button.setTitle("Send Files", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .blue
        button.alpha = 0.5 // 'grayed' out while disabled
        button.isUserInteractionEnabled = false // disabled for inital setup
        return button
    }()
    
    
    var viewModel: RemoteViewModel?
    
    init(withViewModel viewModel: RemoteViewModel) {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
        
        self.viewModel = viewModel
        
        deviceNameLabel.text = viewModel.displayName
        usernameLabel.text = viewModel.userName
        ipaddressLabel.text = viewModel.iNetAddress
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        view.backgroundColor = .white
        
        view.addSubview(deviceNameLabel)
        view.addSubview(usernameLabel)
        view.addSubview(sendFilesButton)
        view.addSubview(ipaddressLabel)
        
        view.addSubview(transfersLabel)
        view.addSubview(transfersStack)
        
        let topAnchor = view.safeAreaLayoutGuide.topAnchor
        let sideMargin: CGFloat = 10
        
        let constraints: [NSLayoutConstraint] = [
            
            deviceNameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 25),
            deviceNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            
            usernameLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor),
            usernameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            
            ipaddressLabel.centerYAnchor.constraint(equalTo: usernameLabel.centerYAnchor),
            ipaddressLabel.leadingAnchor.constraint(equalTo: usernameLabel.trailingAnchor, constant: 10),
            
            
            transfersLabel.bottomAnchor.constraint(equalTo: transfersStack.topAnchor, constant: -10),
            transfersLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            
            
            transfersStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            transfersStack.bottomAnchor.constraint(equalTo: sendFilesButton.topAnchor, constant: -10),
            transfersStack.widthAnchor.constraint(equalTo: sendFilesButton.widthAnchor),
            transfersStack.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            
            
            sendFilesButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sendFilesButton.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -(sideMargin*2)  ),
            sendFilesButton.heightAnchor.constraint(equalTo: sendFilesButton.widthAnchor, multiplier: 0.2),
            sendFilesButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        
        
    }
    
    
    
    
}
