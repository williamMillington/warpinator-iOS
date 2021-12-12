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
    
    let deviceStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "(--device status--)"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let transferStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "--transfer status--"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let cancelTransferButton: UIButton = {
        let button = UIButton()
        button.setTitle("Cancel", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .blue
        button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
//        button.alpha = 0.5 // 'grayed' out while disabled
//        button.isUserInteractionEnabled = false // disabled for inital setup
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
        
        transferViewModel?.onInfoUpdated = {
            self.updateDisplay()
        }
        
        remoteViewModel?.onInfoUpdated = {
            self.updateDisplay()
        }
        
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
        view.addSubview(deviceStatusLabel)
        
        view.addSubview(transferStatusLabel)
        
        view.addSubview(operationsStack)
        
        view.addSubview(cancelTransferButton)
        
        var viewConstraints: [NSLayoutConstraint] = []
        
        let topAnchor = view.safeAreaLayoutGuide.topAnchor
        let sideMargin: CGFloat = 10
        
        viewConstraints +=  [
            
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            backButton.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            
            transferDescriptionLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor),
            transferDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            deviceNameLabel.topAnchor.constraint(equalTo: transferDescriptionLabel.bottomAnchor, constant: 5),
            deviceNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            deviceStatusLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor),
            deviceStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
//            operationsStack.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 25),
            operationsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            operationsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
            operationsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            operationsStack.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            operationsStack.bottomAnchor.constraint(equalTo: cancelTransferButton.topAnchor, constant: -10),
            
            
            transferStatusLabel.bottomAnchor.constraint(equalTo: operationsStack.topAnchor, constant: -5),
            transferStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            cancelTransferButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            cancelTransferButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
            cancelTransferButton.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.1),
            cancelTransferButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
            
        ]
        
        NSLayoutConstraint.activate(viewConstraints)
        
        /* If this is not called, Autolayout will think that the stackview is height 0,
         and will set all subsequent subviews to height == 0.
         Then it will complain that some idiot set all the subview heights to 0. */
        view.layoutIfNeeded()
        
        
        // load intial info
        
        updateDisplay()
        
        for viewmodel in transferViewModel!.files {
            addFileViewToStack(withViewModel: viewmodel)
        }
        
        
    }
    
    
    
    private func addFileViewToStack(withViewModel viewmodel: FileViewModel){
        let ltview = ListedFileView(withViewModel: viewmodel)
        
        operationsStack.insertArrangedSubview(ltview, at: (operationsStack.arrangedSubviews.count - 1))
    }
    
    
    
    func updateDisplay(){
        
        print(DEBUG_TAG+"updating info")
        
        guard let remoteViewModel = remoteViewModel else { return }
        guard let transferViewModel = transferViewModel else { return }
        
        print(DEBUG_TAG+"\tview models available")
        
        deviceNameLabel.text = remoteViewModel.userName
        deviceStatusLabel.text = "(\(remoteViewModel.status))"
        
        transferStatusLabel.text = "\(transferViewModel.status)"
        
        if transferViewModel.status == .FINISHED {
            print(DEBUG_TAG+"\ttransfer finished")
            cancelTransferButton.isUserInteractionEnabled = false
            cancelTransferButton.alpha = 0.5
        }
        
    }
    
    
    
    @objc func cancel(){
        
        
        
    }
    
    
    @objc func retry(){
        
        
    }
    
    
    
    @objc func back(){
        coordinator?.showRemote()
    }
    

}
