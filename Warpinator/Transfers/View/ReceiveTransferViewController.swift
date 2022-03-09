//
//  ReceiveTransferViewController.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-29.
//

import UIKit



//MARK: View Controller
final class ReceiveTransferViewController: UIViewController {

    lazy var DEBUG_TAG: String = "ReceiveTransferViewController:"
    
    var coordinator: RemoteCoordinator?
    
    //
    // MARK: labels
    let transferDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Transfer from"
        label.textColor = Utils.textColour
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    //
    // MARK: buttons
    let acceptButton: UIButton = {
        let button = UIButton()
        button.setTitle("Accept", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor =  #colorLiteral(red: 0.4274509804, green: 0.7058823529, blue: 0.2588235294, alpha: 1)    // .blue
        button.addTarget(self, action: #selector(accept), for: .touchUpInside)
        return button
    }()
    
    
    //
    let declineButton: UIButton = {
        let button = UIButton()
        button.setTitle("Decline", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = #colorLiteral(red: 0.7831932107, green: 0.1171585075, blue: 0.006766619796, alpha: 1)      // .blue
        button.addTarget(self, action: #selector(decline), for: .touchUpInside)
        return button
    }()
    
    //
    let backButton: UIButton = {
        let button = UIButton()
        button.setTitle("< Back", for: .normal)
        button.setTitleColor( Utils.textColour , for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(back), for: .touchUpInside)
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
    
    
    // MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Utils.backgroundColour
        
        var viewConstraints: [NSLayoutConstraint] = []
        
        view.addSubview(transferDescriptionLabel)
        view.addSubview(acceptButton)
        view.addSubview(declineButton)
        view.addSubview(backButton)
        
        let sideMargin: CGFloat = 15
        
        viewConstraints +=  [
            
            transferDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            transferDescriptionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 15),
            transferDescriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -15),
            transferDescriptionLabel.bottomAnchor.constraint(equalTo: acceptButton.topAnchor, constant: -20),
            acceptButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -5),
            acceptButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            acceptButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.25),
            
            declineButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 5),
            declineButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            declineButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.25),
            
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 25),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin)
            
        ]
        
        NSLayoutConstraint.activate(viewConstraints)
        
        let string = "Transfer from " + (viewmodel?.deviceName ??  "No Device Name")
        transferDescriptionLabel.text = string
        
    }
    
    
    //
    // MARK: back
    @objc func back(){
        coordinator?.start()
    }
    
    //
    // MARK: accept
    @objc func accept(){
        coordinator?.acceptTransfer(forTransferUUID: viewmodel!.transferUUID)
    }
    
    //
    // MARK: decline
    @objc func decline(){
        coordinator?.declineTransfer(forTransferUUID: viewmodel!.transferUUID)
    }
    
    
}



//MARK: View Model
final class ReceiveTransferViewModel {
    
    let operation: TransferOperation
    let remote: Remote
    
    var deviceName: String {
        return remote.details.displayName
    }
    
    var transferUUID: UInt64 {
        return operation.UUID
    }
    
    
    init(operation: TransferOperation, from remote: Remote){
        self.operation = operation
        self.remote = remote
    }
    
}
