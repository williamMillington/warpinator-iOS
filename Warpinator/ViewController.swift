//
//  ViewController.swift
//  Warpinator
//
//  Created by William Millington on 2021-09-30.
//

import UIKit
import GRPC
import NIO


final class ViewController: UIViewController {
    
    private let DEBUG_TAG: String = "ViewController: "
    
    var coordinator: MainCoordinator?
    
//    let refreshButton: UIButton = {
//        let button = UIButton()
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.setTitle("Refresh", for: .normal)
//        button.backgroundColor = .blue
//        button.alpha = 0.5 // 'grayed' out while disabled
//        button.isUserInteractionEnabled = false // disabled for inital setup
//        return button
//    }()
    
    
    @IBOutlet var titleLabel: UILabel!
    
    @IBOutlet var settingsButton: UIButton!
    
    @IBOutlet var remotesStack: UIStackView!
    
    
    @IBOutlet var IPaddressLabel: UILabel!
    @IBOutlet var displayNameLabel: UILabel!
    @IBOutlet var deviceLabel: UILabel!
    
    
    
    weak var settingsManager: SettingsManager?
    
    
    var errorScreen: ErrorView?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // remove placeholder from xib
        for view in remotesStack.arrangedSubviews {   view.removeFromSuperview()  }
        
        let displayNameString = "\(settingsManager!.displayName)"
        displayNameLabel.attributedText = NSAttributedString(string: displayNameString,
                                                             attributes: [ .font: UIFont.boldSystemFont(ofSize: 22)])
        
        let deviceString = "\(settingsManager!.userName)@\(settingsManager!.hostname)"
        deviceLabel.attributedText = NSAttributedString(string: deviceString,
                                                             attributes: [ .font: UIFont.boldSystemFont(ofSize: 20)])
        
        let ipstring = "\(Utils.getIP_V4_Address())"
        IPaddressLabel.attributedText = NSAttributedString(string: ipstring,
                                                           attributes: [ .font: UIFont.systemFont(ofSize: 20,
                                                                                                  weight: .light)])
        
//        showErrorScreen()
    }

    
    func setRefreshButtonEnabled(_ enabled: Bool){
        
//        if enabled {
//            refreshButton.alpha = 1
//            refreshButton.isUserInteractionEnabled = true
//        } else {
//            refreshButton.alpha = 0.5
//            refreshButton.isUserInteractionEnabled = false
//        }
    }
    
    
    //
    // MARK: go to settings
    @IBAction func userDidPushSettingsButton(){
        
        coordinator?.showSettings()
        
    }
    
    
    
    //
    // MARK: remote added
    func remoteAdded(_ remote: Remote){
        
        let viewModel = ListedRemoteViewModel(remote)
        
        print(DEBUG_TAG+"Adding view for connection \(viewModel.displayName)")
        
        let remoteView = ListedRemoteView(withViewModel: viewModel) {
            self.coordinator?.remoteSelected(viewModel.uuid)
        }
        
        // insert right before expanderviewr
//        remotesStack.insertArrangedSubview(remoteView, at: (remotesStack.arrangedSubviews.count - 1) )
        remotesStack.insertArrangedSubview(remoteView, at: (remotesStack.arrangedSubviews.count) )
    }
    
    
    
    
    func remoteRemoved(with uuid: String){
        
        for view in remotesStack.arrangedSubviews as! [ListedRemoteView]{
            if view.viewModel!.uuid == uuid {
                remotesStack.removeArrangedSubview(view)
                view.removeFromSuperview()
                return
            }
        }
        
    }
    
    
    // MARK: show error screen
    func showErrorScreen(){
        
        print(DEBUG_TAG+"showing error screen")
        
        errorScreen = ErrorView(onTap: {
            self.hideErrorScreen()
            self.coordinator?.restartServers()
        })
        
        errorScreen?.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(errorScreen!)
        
        let constraints = [
            errorScreen!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorScreen!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorScreen!.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            errorScreen!.bottomAnchor.constraint(equalTo: IPaddressLabel.topAnchor, constant: 10)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        view.setNeedsLayout()
    }
    
    
    // MARK: hide error screen
    func hideErrorScreen(){
        
        guard let screen = errorScreen else {
            print(DEBUG_TAG+"No error screen"); return
        }
        
        print(DEBUG_TAG+"removing error screen")
        NSLayoutConstraint.deactivate(screen.constraints)
        
        screen.removeFromSuperview()
        
        errorScreen = nil
        
    }
    
    
}





// MARK: Error View
final class ErrorView: UIView {
    
    private let DEBUG_TAG: String = "ErrorView: "
    
    let errorAnnouncementLabel: UILabel = {
        let label = UILabel()
        label.text = "An error occurred, tap to restart server "
        label.tintColor = Utils.textColour
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    var tapRecognizer: TapGestureRecognizerWithClosure?
    
    override init(frame: CGRect){
        super.init(frame: frame)
        setUpView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpView()
    }
    
    
    convenience init(onTap action: @escaping ()->Void = {}){
        self.init(frame: .zero)
        
        // add subviews and constraints
        setUpView()
        
        // add onTap action
        tapRecognizer = TapGestureRecognizerWithClosure(action: action)
        addGestureRecognizer(tapRecognizer!)
        
    }
    
    
    //
    // MARK: setUpView
    func setUpView(){
        
        addSubview(errorAnnouncementLabel)
        
        let constraints = [
            errorAnnouncementLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorAnnouncementLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        backgroundColor = UIColor.blue.withAlphaComponent(0.5)//Utils.foregroundColour
        
        layer.cornerRadius = 5
        
        layer.borderWidth = 1
//        layer.borderColor = Utils.borderColour.cgColor
        
    }
    
}
