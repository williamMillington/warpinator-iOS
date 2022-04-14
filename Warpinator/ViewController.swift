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
    var serverLoadingScreen: ServerLoadingView?
    
    
    //
    // MARK: viewDidLoad
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
        view.backgroundColor = Utils.backgroundColour
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
        
//        print(DEBUG_TAG+"Adding view for connection \(viewModel.displayName)")
        
        let remoteView = ListedRemoteView(withViewModel: viewModel) {
            self.coordinator?.remoteSelected(viewModel.uuid)
        }
        
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
    
    
    //
    // MARK: show error screen
    func showErrorScreen(_ error: Error, withMessage message: String){
        
        print(DEBUG_TAG+"showing error screen")
        
        guard errorScreen == nil else {
            print(DEBUG_TAG+"screen already up")
            return
        }
        
        errorScreen = ErrorView(error, withMessage: message, onTap: {
            self.removeErrorScreen()
            self.coordinator?.restartServers()
        })
        
        errorScreen?.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(errorScreen!)
        
        let constraints = [
            errorScreen!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorScreen!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorScreen!.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            errorScreen!.bottomAnchor.constraint(equalTo: displayNameLabel.topAnchor, constant: -5)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        view.setNeedsLayout()
    }
    
    
    //
    // MARK: remove error screen
    func removeErrorScreen(){
        
        guard let screen = errorScreen else {
            print(DEBUG_TAG+"No error screen"); return
        }
        
        print(DEBUG_TAG+"removing error screen")
        NSLayoutConstraint.deactivate(screen.constraints)
        
        screen.removeFromSuperview()
        
        errorScreen = nil
        
    }
    
    
    
    func showLoadingScreen(){
        
        print(DEBUG_TAG+"showing loading screen")
        
        guard serverLoadingScreen == nil else {
            print(DEBUG_TAG+"screen already up")
            return
        }
        
        serverLoadingScreen = ServerLoadingView()
        serverLoadingScreen?.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(serverLoadingScreen!)
        
        let constraints = [
            serverLoadingScreen!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            serverLoadingScreen!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            serverLoadingScreen!.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            serverLoadingScreen!.bottomAnchor.constraint(equalTo: displayNameLabel.topAnchor, constant: -5)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        view.setNeedsLayout()
    }
    
    
    func removeLoadingScreen(){
        guard let screen = serverLoadingScreen else {
            print(DEBUG_TAG+"No loading screen"); return
        }
        
        print(DEBUG_TAG+"removing loading screen")
        NSLayoutConstraint.deactivate(screen.constraints)
        
        screen.removeFromSuperview()
        
        serverLoadingScreen = nil
    }
    
    
    
    
    
    
}















// MARK: - Server View
final class ServerLoadingView: UIView {
    
    private let DEBUG_TAG: String = "ServerLoadingView: "
    
    let loadingTextLabel: UILabel = {
        let label = UILabel()
        label.text = "Server is starting up, please wait... "
        label.textColor = Utils.textColour
        label.tintColor = Utils.textColour
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
//    var tapRecognizer: TapGestureRecognizerWithClosure?
    
    override init(frame: CGRect){
        super.init(frame: frame)
        setUpView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpView()
    }
    
    
//    convenience init(onTap action: @escaping ()->Void = {}){
    convenience init(){
        self.init(frame: .zero)
        
        // add subviews and constraints
        setUpView()
        
        // add onTap action
//        tapRecognizer = TapGestureRecognizerWithClosure(action: action)
//        addGestureRecognizer(tapRecognizer!)
        
    }
    
    
    //
    // MARK: setUpView
    func setUpView(){
        
        addSubview(loadingTextLabel)
        
        let constraints = [
            loadingTextLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingTextLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
//        backgroundColor = UIColor.blue.withAlphaComponent(0.5)
        backgroundColor = Utils.backgroundColour
        
        
    }
    
}















// MARK: - Error View
final class ErrorView: UIView {
    
    private let DEBUG_TAG: String = "ErrorView: "
    
    let errorAnnouncementLabel: UILabel = {
        let label = UILabel()
        label.text = "An error occurred, tap to restart server"
        label.textColor = Utils.textColour
        label.tintColor = Utils.textColour
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let errorDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = Utils.textColour
        label.tintColor = Utils.textColour
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let messageLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = Utils.textColour
        label.tintColor = Utils.textColour
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
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
    
    
    convenience init(_ error: Error, withMessage message: String, onTap action: @escaping ()->Void = {}){
        self.init(frame: .zero)
        
        errorDescriptionLabel.text = "\(error)"
        messageLabel.text = message
        
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
        addSubview(errorDescriptionLabel)
        addSubview(messageLabel)
        
        let constraints = [
            errorAnnouncementLabel.bottomAnchor.constraint(equalTo: errorDescriptionLabel.topAnchor, constant: -15 ),
            errorAnnouncementLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            errorDescriptionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorDescriptionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: errorDescriptionLabel.bottomAnchor, constant: 10),
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            errorAnnouncementLabel.widthAnchor.constraint(equalTo: widthAnchor, constant: -10),
            errorDescriptionLabel.widthAnchor.constraint(equalTo: widthAnchor, constant: -10),
            messageLabel.widthAnchor.constraint(equalTo: widthAnchor, constant: -10)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
//        backgroundColor = UIColor.blue.withAlphaComponent(0.5)
        backgroundColor = Utils.backgroundColour
        
    }
    
}
