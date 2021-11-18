//
//  ViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-09-30.
//

import UIKit
import GRPC
import NIO

class ViewController: UIViewController {
    
    private let DEBUG_TAG: String = "ViewController: "
    
    var coordinator: MainCoordinator?
    
    var mainService: MainService = MainService()
    
    var refreshButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Refresh", for: .normal)
        button.backgroundColor = .blue
        button.alpha = 0.5 // 'grayed' out while disabled
        button.isUserInteractionEnabled = false // disabled for inital setup
        return button
    }()
    
    
    var remotesScroller = ButtonScrollView()
    
    var remotesStack: UIStackView = {
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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        var viewConstraints: [NSLayoutConstraint] = []
        
        view.addSubview(remotesStack)
        view.addSubview(refreshButton)
        
        let sideMargin: CGFloat = 10
        
        viewConstraints +=  [
            
            refreshButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            refreshButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            refreshButton.widthAnchor.constraint(equalTo: remotesStack.widthAnchor, multiplier: 0.5),
            refreshButton.heightAnchor.constraint(lessThanOrEqualTo: refreshButton.widthAnchor, multiplier: 0.25),
//            refreshButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: (sideMargin *  2)),
//            refreshButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -(sideMargin *  2)),
//            refreshButton.heightAnchor.constraint(equalToConstant: 50),
            
            
            remotesStack.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 20),
            remotesStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            remotesStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            remotesStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
            remotesStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ]
        
        NSLayoutConstraint.activate(viewConstraints)
        
        MainService.shared.remoteManager.remotesViewController = self
        
        MainService.shared.start()
        
        
        
    }

    
    func setRefreshButtonEnabled(_ enabled: Bool){
        
        if enabled {
            refreshButton.alpha = 1
            refreshButton.isUserInteractionEnabled = true
        } else {
            refreshButton.alpha = 0.5
            refreshButton.isUserInteractionEnabled = false
        }
    }
    
    
    
    
    
    func connectionAdded(_ viewModel: RemoteViewModel){
        
        print(DEBUG_TAG+"Adding view for connection \(viewModel.displayName)")
        
        let remoteView = ListedRemoteView(withViewModel: viewModel) {
            self.coordinator?.userSelected(viewModel.uuid)
        }
//        remoteView.translatesAutoresizingMaskIntoConstraints = false
        
        
//        remotesStack.addArrangedSubview(remoteView)
        
        // insert right before expanderview
        remotesStack.insertArrangedSubview(remoteView, at: (remotesStack.arrangedSubviews.count - 1) )
    }
    
    
    func connectionRemoved(withh uuid: String){
        
        for view in remotesStack.arrangedSubviews as! [ListedRemoteView]{
            if view.viewModel!.uuid == uuid {
                remotesStack.removeArrangedSubview(view)
                return
            }
        }
        
    }
    
    
    
    
    
    
    
    
}

