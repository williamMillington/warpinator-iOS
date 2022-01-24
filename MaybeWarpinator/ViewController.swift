//
//  ViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-09-30.
//

import UIKit
import GRPC
import NIO

final class ViewController: UIViewController {
    
    private let DEBUG_TAG: String = "ViewController: "
    
    var coordinator: MainCoordinator?
    
    let refreshButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Refresh", for: .normal)
        button.backgroundColor = .blue
        button.alpha = 0.5 // 'grayed' out while disabled
        button.isUserInteractionEnabled = false // disabled for inital setup
        return button
    }()
    
    @IBOutlet var settingsButton: UIButton!
    
    @IBOutlet var remotesStack: UIStackView!
    
    
    
    
    @IBOutlet var IPaddressLabel: UILabel!
    @IBOutlet var displayNameLabel: UILabel!
    @IBOutlet var deviceLabel: UILabel!
    
    
    
    weak var settingsManager: SettingsManager?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // remove placeholder from xib
        for view in remotesStack.arrangedSubviews {   view.removeFromSuperview()  }
        
        
        displayNameLabel.attributedText = NSAttributedString(string: "\(settingsManager!.name)",
                                                             attributes: [ .font: UIFont.boldSystemFont(ofSize: 22)])
        
        deviceLabel.attributedText = NSAttributedString(string: "@hostname",
                                                             attributes: [ .font: UIFont.boldSystemFont(ofSize: 20)])
        
        IPaddressLabel.attributedText = NSAttributedString(string: "\(Utils.getIP_V4_Address())",
                                                           attributes: [ .font: UIFont.systemFont(ofSize: 20,
                                                                                                  weight: .light)])
        
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
    
    
    
    @IBAction func userDidPushSettingsButton(){
        
        coordinator?.showSettings()
        
        
    }
    
    
    
    func remoteAdded(_ remote: Remote){
        
        let viewModel = ListedRemoteViewModel(remote)
        
        print(DEBUG_TAG+"Adding view for connection \(viewModel.displayName)")
        
        let remoteView = ListedRemoteView(withViewModel: viewModel) {
            self.coordinator?.userSelected(viewModel.uuid)
        }
        
        // insert right before expanderviewr
//        remotesStack.insertArrangedSubview(remoteView, at: (remotesStack.arrangedSubviews.count - 1) )
        remotesStack.insertArrangedSubview(remoteView, at: (remotesStack.arrangedSubviews.count) )
    }
    
    
    
    
    func remoteRemoved(with uuid: String){
        
        for view in remotesStack.arrangedSubviews as! [ListedRemoteView]{
            if view.viewModel!.uuid == uuid {
                remotesStack.removeArrangedSubview(view)
                return
            }
        }
        
    }
    
    
    
}

