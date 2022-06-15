//
//  ListedRemoteView.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit


// MARK: View
@IBDesignable
final class ListedRemoteView: UIView {
    
    private let DEBUG_TAG: String = "ListedRemoteView: "
    
    var viewModel: ListedRemoteViewModel?
    
    private lazy var userImageView : UIImageView = {
        
        let image = UIImage(systemName: "person.fill",
                            compatibleWith: self.traitCollection)!.withRenderingMode(.alwaysTemplate)
        
        let view = UIImageView(image: image)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = Utils.textColour
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }()
    
    
    let displayNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Display Name"
        label.tintColor = Utils.textColour
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.1)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.text = "username@hostname"
        label.tintColor = Utils.textColour
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.1)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        return label
    }()
    
    
    
    let deviceStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Status..."
        label.tintColor = Utils.textColour
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.1)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    
    var tapRecognizer: TapGestureRecognizerWithClosure?
    
    
    //
    //
    // MARK: - init
    override init(frame: CGRect){
        super.init(frame: frame)
        setUpView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpView()
    }
    
    
    convenience init(withViewModel model: ListedRemoteViewModel,
                     onTap action: @escaping ()->Void = {}){
        self.init()
        
//        backgroundColor = UIColor.orange.withAlphaComponent(0.2)
        
        viewModel = model
        viewModel?.onInfoUpdated = { [weak self] in
            self?.updateDisplay()
        }
        
        // add subviews and constraints
        setUpView()
        
        // add onTap action
        tapRecognizer = TapGestureRecognizerWithClosure(action: action)
        addGestureRecognizer(tapRecognizer!)
        
        updateDisplay()
    }
    
    
    //
    // MARK: setUpView
    func setUpView(){
        
        setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        var constraints: [NSLayoutConstraint] = []
        
        addSubview(userImageView)
        
        addSubview(displayNameLabel)
        addSubview(deviceNameLabel)
        
        addSubview(deviceStatusLabel)
        
        constraints += [
            
            userImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            
            userImageView.topAnchor.constraint(lessThanOrEqualTo: topAnchor, constant: 10),
            userImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            userImageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -5),
            
            userImageView.widthAnchor.constraint(equalTo: userImageView.heightAnchor),
            
            displayNameLabel.leadingAnchor.constraint(equalTo: userImageView.trailingAnchor, constant: 5),
            displayNameLabel.bottomAnchor.constraint(equalTo: centerYAnchor),
            
            deviceNameLabel.leadingAnchor.constraint(equalTo: displayNameLabel.leadingAnchor),
            deviceNameLabel.topAnchor.constraint(equalTo: centerYAnchor),
            deviceNameLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.5),
            
            
            deviceStatusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            deviceStatusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.2)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        backgroundColor = Utils.foregroundColour
        
        layer.cornerRadius = 5
        
        layer.borderWidth = 1
        layer.borderColor = Utils.borderColour.cgColor
        
    }
    
    
    //
    // MARK: updateDisplay
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        let bold = UIFont.boldSystemFont(ofSize:  self.frame.size.height / 3)
        let standard = UIFont.systemFont(ofSize:  self.frame.size.height / 4)
        
        displayNameLabel.attributedText = viewModel.displayName.extended
            .attributed( [ .font : bold,
                           .foregroundColor : Utils.textColour] )
        
        deviceNameLabel.attributedText = viewModel.deviceName.extended
            .attributed( [ .font : standard,
                           .foregroundColor : Utils.textColour] )
        
        deviceStatusLabel.attributedText = viewModel.status.extended
            .attributed( [ .font : standard,
                           .foregroundColor : Utils.textColour] )
        
        
        if let image = viewModel.avatarImage {
            self.userImageView.image = image
            self.setNeedsLayout()
        }
        
        
        
        
    }
}






//
// MARK: - ViewModel
final class ListedRemoteViewModel: NSObject, ObservesRemote {

    private var remote: Remote
    
    var onInfoUpdated: ()->Void = {}
    var onTransferAdded: (TransferOperationViewModel) -> Void = { viewmodel in }

    
    var avatarImage: UIImage? {
        return remote.details.userImage
    }
        
    
    var displayName: String {
        return remote.details.displayName
    }
    
    
    var deviceName: String {
        return remote.details.username + "@" + remote.details.hostname
    }
    

    var uuid: String {
        return remote.details.uuid
    }

    var status: String {
        
        switch remote.details.status {
        case .FetchingCredentials,
             .AquiringDuplex, 
             .OpeningConnection : return "Connecting"
        case .Error: return "Error"
        default: return remote.details.status.rawValue
        }
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
    
    func operationAdded(_ operation: TransferOperation) { }

    deinit {
        remote.removeObserver(self)
    }
}







//MARK: - Interface Builder
extension ListedRemoteView {
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        
        setUpView()
        
        let bold = UIFont.boldSystemFont(ofSize:  self.frame.size.height / 3)
        let standard = UIFont.systemFont(ofSize:  self.frame.size.height / 4)
        
        self.displayNameLabel.attributedText = "Display Name".extended
            .attributed([ .font : bold,
                            .foregroundColor : Utils.textColour  ])
        
        self.deviceNameLabel.attributedText = "Device Name".extended
            .attributed([ .font : standard,
                            .foregroundColor : Utils.textColour  ])
        
        self.deviceStatusLabel.attributedText = "Connecting".extended
            .attributed([ .font : standard,
                            .foregroundColor : Utils.textColour  ])
        
    }
}
