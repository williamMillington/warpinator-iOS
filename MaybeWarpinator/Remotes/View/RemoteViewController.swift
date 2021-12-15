//
//  RemoteViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-18.
//

import UIKit

class RemoteViewController: UIViewController {

    
    var coordinator: RemoteCoordinator?
    
    
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
    
    
    let backButton: UIButton = {
        let button = UIButton()
        button.setTitle("back", for: .normal)
        button.setTitleColor( .blue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.addTarget(self, action: #selector(back), for: .touchUpInside)
        return button
    }()
    
    
    let sendFilesButton: UIButton = {
        let button = UIButton()
        button.setTitle("Send Files", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .blue
        button.addTarget(self, action: #selector(sendFiles), for: .touchUpInside)
//        button.alpha = 0.5 // 'grayed' out while disabled
//        button.isUserInteractionEnabled = false // disabled for inital setup
        return button
    }()
    
    
    var viewModel: RemoteViewModel?
    
    init(withViewModel viewModel: RemoteViewModel) {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
        
        self.viewModel = viewModel
        
        
        self.viewModel!.onInfoUpdated = { [weak self] in
            guard let self = self else { return }
            self.updateDisplay()
        }
        
        self.viewModel!.onTransferAdded = { [weak self] viewmodel in
            guard let self = self else { return }
            self.addTransferViewToStack(withViewModel: viewmodel)
        }
        
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        view.backgroundColor = .white
        
        view.addSubview(backButton)
        
        view.addSubview(deviceNameLabel)
        view.addSubview(usernameLabel)
        view.addSubview(ipaddressLabel)
        
        view.addSubview(transfersLabel)
        view.addSubview(transfersStack)
        
        view.addSubview(sendFilesButton)
        
        
        let topAnchor = view.safeAreaLayoutGuide.topAnchor
        let sideMargin: CGFloat = 10
        
        let constraints: [NSLayoutConstraint] = [
            
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            backButton.topAnchor.constraint(equalTo: topAnchor, constant: 25),
            
            deviceNameLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
            deviceNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            
            usernameLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor),
            usernameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            
            ipaddressLabel.centerYAnchor.constraint(equalTo: usernameLabel.centerYAnchor),
            ipaddressLabel.leadingAnchor.constraint(equalTo: usernameLabel.trailingAnchor, constant: 10),
            
            
            transfersLabel.bottomAnchor.constraint(equalTo: transfersStack.topAnchor, constant: -10),
            transfersLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            
            transfersStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            transfersStack.widthAnchor.constraint(equalTo: sendFilesButton.widthAnchor),
            transfersStack.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            transfersStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            transfersStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
            
            transfersStack.bottomAnchor.constraint(equalTo: sendFilesButton.topAnchor, constant: -10),
            
            sendFilesButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sendFilesButton.widthAnchor.constraint(equalTo: transfersStack.widthAnchor),
//            sendFilesButton.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -(sideMargin*2)  ),
            sendFilesButton.heightAnchor.constraint(equalTo: sendFilesButton.widthAnchor, multiplier: 0.2),
            sendFilesButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        /* If this is not called, Autolayout will think that the stackview is height 0,
         and will set all subsequent subviews to height == 0.
         Then it will complain that some idiot set all the subview heights to 0. */
        view.layoutIfNeeded()
        
        
        // load intial info
        
        updateDisplay()
        
        for transfer_viewmodel in self.viewModel!.transfers {
            addTransferViewToStack(withViewModel: transfer_viewmodel)
        }
        
    }
    
    
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        deviceNameLabel.text = viewModel.displayName
        usernameLabel.text = viewModel.userName
        ipaddressLabel.text = viewModel.iNetAddress
        
        
    }
    
    
    private func addTransferViewToStack(withViewModel viewmodel: TransferOperationViewModel){
        let ltview = ListedTransferView(withViewModel: viewmodel, onTap: {
            self.coordinator?.userSelectedTransfer(withUUID: viewmodel.UUID )
        })
        transfersStack.insertArrangedSubview(ltview, at: (transfersStack.arrangedSubviews.count - 1))
    }
    
    
    
    @objc func sendFiles(){
        
//        coordinator?.mockSendTransfer()
        coordinator?.createTransfer()
        
    }
    
    
    @objc func back(){
        coordinator?.back()
    }
}
