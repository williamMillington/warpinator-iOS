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
    
    var remotesStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.backgroundColor = .purple
        return stack
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        view.backgroundColor = .green
        
        var viewConstraints: [NSLayoutConstraint] = []
        
        view.addSubview(remotesStack)
        view.addSubview(refreshButton)
        
        let sideMargin: CGFloat = 10
        
        viewConstraints +=  [
            
            refreshButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            refreshButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            refreshButton.widthAnchor.constraint(equalTo: remotesStack.widthAnchor, multiplier: 0.5),
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
        
        
//        MainService.shared.start()
        
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
    
    
    
    
    
    func connectionAdded(){
        
        
        
        
        
        
    }
    
    
    
    
    
    
    
    
    
    
}

