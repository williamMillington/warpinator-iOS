//
//  RemoteViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-18.
//

import UIKit




//MARK: View Controller
final class RemoteViewController: UIViewController {

    
    var coordinator: RemoteCoordinator?
    
    @IBOutlet var avatarImageView: UIImageView!
    
    @IBOutlet var displayNameLabel: UILabel!
//    let displayNameLabel: UILabel = {
//        let label = UILabel()
//        label.text = "Uknown Device"
//        label.tintColor = Utils.textColour
////        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        return label
//    }()
    
    @IBOutlet var deviceNameLabel: UILabel!
//    let deviceNameLabel: UILabel = {
//        let label = UILabel()
//        label.tintColor = Utils.textColour
//        label.text = "UknownUser@UknownDevice"
////        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        label.lineBreakMode = .byTruncatingTail
//        return label
//    }()
    
    @IBOutlet var ipaddressLabel: UILabel!
    
    @IBOutlet var statusLabel: UILabel!
//    let ipaddressLabel: UILabel = {
//        let label = UILabel()
//        label.tintColor = Utils.textColour
//        label.text = "IP.un.kno.wn"
////        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        label.textAlignment = .right
//        return label
//    }()
    
    
//    @IBOutlet var transfersLabel: UILabel!
//    var transfersLabel: UILabel = {
//        let label = UILabel()
//        label.text = "Transfers:"
//        label.tintColor = Utils.textColour
////        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        return label
//    }()
    
    @IBOutlet var transfersStack: UIStackView!
//    var transfersStack: UIStackView = {
//        let stack = UIStackView()
//        stack.translatesAutoresizingMaskIntoConstraints = false
//        stack.alignment = .fill
//        stack.distribution = .fillProportionally
//        stack.spacing = 5
//        stack.axis = .vertical
////        stack.backgroundColor = UIColor.blue.withAlphaComponent(0.2)
//
//        let expanderView = UIView()
//        expanderView.translatesAutoresizingMaskIntoConstraints = false
////        expanderView.backgroundColor = UIColor.blue.withAlphaComponent(0.2)
//
//        // without this, height is constrained to 0 for some dumb reason,
//        // and breaks stackview's attempts to resize it
//        expanderView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
//
//        stack.addArrangedSubview(expanderView)
//
//        return stack
//    }()
    
    
    @IBOutlet var backButton: UIButton!
//    let backButton: UIButton = {
//        let button = UIButton()
//        button.setTitle("< back", for: .normal)
//        button.setTitleColor( Utils.textColour, for: .normal)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.backgroundColor = .white
//        button.addTarget(self, action: #selector(back), for: .touchUpInside)
//        return button
//    }()
    
    @IBOutlet var sendFilesButton: UIButton!
//    let sendFilesButton: UIButton = {
//        let button = UIButton()
////        button.setTitle("Send Files", for: .normal)
//        button.setAttributedTitle( NSAttributedString(string: "Send Files",
//                                                      attributes: [ .font : UIFont.systemFont(ofSize: 30,
//                                                                                              weight: .medium),
//                                                                    .foregroundColor : UIColor.white]),
//                                   for: .normal)
//        button.backgroundColor = #colorLiteral(red: 0.2705163593, green: 0.4721807509, blue: 1, alpha: 1)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.addTarget(self, action: #selector(sendFiles), for: .touchUpInside)
//
//        button.layer.cornerRadius = 5
////        button.alpha = 0.5 // 'grayed' out while disabled
////        button.isUserInteractionEnabled = false // disabled for inital setup
//        return button
//    }()
    
    
    var viewModel: RemoteViewModel?
    
    
    init(withViewModel viewModel: RemoteViewModel) {
        super.init(nibName: "RemoteViewController", bundle: Bundle(for: type(of: self)))
        
        
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
        
        view.backgroundColor = Utils.backgroundColour
        
        for view in transfersStack.arrangedSubviews {   view.removeFromSuperview()  }
        
//        view.backgroundColor = .white
//
//        view.addSubview(backButton)
//
//        view.addSubview(displayNameLabel)
//        view.addSubview(deviceNameLabel)
//        view.addSubview(ipaddressLabel)
//
//        view.addSubview(transfersLabel)
//        view.addSubview(transfersStack)
//
//        view.addSubview(sendFilesButton)
        
        
//        let topAnchor = view.safeAreaLayoutGuide.topAnchor
//        let sideMargin: CGFloat = 10
        
//        let constraints: [NSLayoutConstraint] = [
//
//            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//            backButton.topAnchor.constraint(equalTo: topAnchor, constant: 25),
//
//            displayNameLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 10),
//            displayNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//
//            deviceNameLabel.topAnchor.constraint(equalTo: displayNameLabel.bottomAnchor),
//            deviceNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//            deviceNameLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
//
//            ipaddressLabel.centerYAnchor.constraint(equalTo: deviceNameLabel.centerYAnchor),
//            ipaddressLabel.leadingAnchor.constraint(equalTo: deviceNameLabel.trailingAnchor, constant: 10),
//            ipaddressLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.4),
            
            
//            transfersLabel.bottomAnchor.constraint(equalTo: transfersStack.topAnchor, constant: -10),
//            transfersLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//
//            transfersStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            transfersStack.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
//            transfersStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//            transfersStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
//
//            transfersStack.bottomAnchor.constraint(equalTo: sendFilesButton.topAnchor, constant: -10),
//
//            sendFilesButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            sendFilesButton.widthAnchor.constraint(equalTo: transfersStack.widthAnchor),
//            sendFilesButton.heightAnchor.constraint(equalTo: sendFilesButton.widthAnchor, multiplier: 0.2),
//            sendFilesButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
//
//        ]
//
//        NSLayoutConstraint.activate(constraints)
        
        /* If this is not called, Autolayout will think that the stackview is height 0,
         and will set all subsequent subviews to height == 0.
         Then it will complain that some idiot set all the subview heights to 0. */
//        view.layoutIfNeeded()
        
        
        // load intial info
        
        updateDisplay()
        
        for transfer_viewmodel in self.viewModel!.transfers {
            addTransferViewToStack(withViewModel: transfer_viewmodel)
        }
        
        avatarImageView.image = UIImage(systemName: "person.fill",
                                        compatibleWith: self.traitCollection)!.withRenderingMode(.alwaysTemplate)
        
    }
    
    
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        var attrs = displayNameLabel.attributedText?.attributes(at: 0, effectiveRange: nil)
        let displayNameString = NSAttributedString(string: viewModel.displayName,
                                                   attributes: attrs)
        
        attrs = deviceNameLabel.attributedText?.attributes(at: 0, effectiveRange: nil)
        let usernameString = NSAttributedString(string: viewModel.deviceName,
                                                   attributes: attrs)
        
        attrs = ipaddressLabel.attributedText?.attributes(at: 0, effectiveRange: nil)
        let ipString = NSAttributedString(string: viewModel.iNetAddress,
                                                   attributes: attrs)
        
        
        attrs = statusLabel.attributedText?.attributes(at: 0, effectiveRange: nil)
        let statusString = NSAttributedString(string: viewModel.status,
                                                   attributes: attrs)
        
        displayNameLabel.attributedText = displayNameString
        deviceNameLabel.attributedText = usernameString
        ipaddressLabel.attributedText = ipString
        
        statusLabel.attributedText = statusString
        
        
        if let image = viewModel.avatarImage {
            self.avatarImageView.image = image
            self.view.setNeedsLayout()
        }
        
    }
    
    
    private func addTransferViewToStack(withViewModel viewmodel: ListedTransferViewModel){
        let ltview = ListedTransferView(withViewModel: viewmodel, onTap: {
            self.coordinator?.userSelectedTransfer(withUUID: viewmodel.UUID )
        })
        transfersStack.insertArrangedSubview(ltview, at: (transfersStack.arrangedSubviews.count))
    }
    
    
    
    @IBAction @objc func sendFiles(){
        
//        coordinator?.mockSendTransfer()
        coordinator?.createTransfer()
        
    }
    
    
    @IBAction @objc func back(){
        coordinator?.back()
    }
}

extension RemoteViewController {
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        
    }
}






//MARK: View Model
final class RemoteViewModel: NSObject, ObservesRemote {
    
    private var remote: Remote
    var onInfoUpdated: ()->Void = {}
    var onTransferAdded: (ListedTransferViewModel)->Void = { viewmodel in }
    
    var avatarImage: UIImage? {
        return remote.details.userImage
    }
    
    var displayName: String {
        return remote.details.displayName
    }
    
    var deviceName: String {
        return remote.details.username + "@" + remote.details.hostname
    }
    
//    var userName: String {
//        return remote.details.username
//    }
    
    var iNetAddress: String {
        return remote.details.ipAddress
    }
    
    var hostname: String {
        return remote.details.hostname
    }
    
    var status: String {
        return remote.details.status.rawValue
    }
    
    
    var transfers: [ListedTransferViewModel] {

        var viewmodels:[ListedTransferViewModel] = []
        let operations: [TransferOperation] = remote.sendingOperations + remote.receivingOperations

        for operation in operations  {
            viewmodels.append( ListedTransferViewModel(for: operation) )
        }

        return viewmodels
    }
    
    
    init(_ remote: Remote) {
        self.remote = remote
        super.init()
        
        remote.addObserver(self)
    }
    
    
    func infoDidUpdate(){
        DispatchQueue.main.async { // execute UI on main thread
            self.onInfoUpdated()
        }
    }
    
    func operationAdded(_ operation: TransferOperation){
        DispatchQueue.main.async { // execute UI on main thread
            self.onTransferAdded(ListedTransferViewModel(for: operation))
        }
    }
    
    deinit {
        remote.removeObserver(self)
    }
}
