//
//  ListedRemoteView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit


// MARK: View
@IBDesignable
final class ListedRemoteView: UIView {
    
    private let DEBUG_TAG: String = "ListedRemoteView: "
    
    var viewModel: ListedRemoteViewModel?
    
    
    private var placeHolderImage : UIImage! {
//        let bundle = Bundle(for: type(of: self))
        return UIImage(systemName: "timelapse",
//                       in: bundle,
                       compatibleWith: self.traitCollection)!.withRenderingMode(.alwaysTemplate)
    }
    
    private lazy var userImageView : UIImageView = {
        let view = UIImageView(image: placeHolderImage)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = Utils.textColour
        return view
    }()
    
    
    let displayNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Display Name"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.1)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.text = "username@hostname"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.1)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    
    let deviceStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Status..."
        label.backgroundColor = UIColor.green.withAlphaComponent(0.1)
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
    
    
    convenience init(withViewModel model: ListedRemoteViewModel, onTap action: @escaping ()->Void = {}){
        self.init()
        
//        backgroundColor = UIColor.orange.withAlphaComponent(0.2)
        
        viewModel = model
        viewModel?.onInfoUpdated = {
            self.updateDisplay()
        }
        
        // add subviews and constraints
        setUpView()
        
        // add onTap action
        tapRecognizer = TapGestureRecognizerWithClosure(action: action)
        addGestureRecognizer(tapRecognizer!)
        
        updateDisplay()
    }
    
    
    func setUpView(){
        
        var constraints: [NSLayoutConstraint] = []
        
        
        addSubview(userImageView)
        
        addSubview(displayNameLabel)
        addSubview(deviceNameLabel)
        
        addSubview(deviceStatusLabel)
        
        constraints += [
            
            
            userImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            
            userImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            userImageView.topAnchor.constraint(lessThanOrEqualTo: displayNameLabel.topAnchor),
            userImageView.bottomAnchor.constraint(greaterThanOrEqualTo: deviceNameLabel.bottomAnchor),
            
            userImageView.widthAnchor.constraint(equalTo: userImageView.heightAnchor),
            
            displayNameLabel.leadingAnchor.constraint(equalTo: userImageView.trailingAnchor, constant: 5),
            displayNameLabel.bottomAnchor.constraint(equalTo: centerYAnchor),
            
            
            deviceNameLabel.topAnchor.constraint(equalTo: centerYAnchor),
            
            deviceNameLabel.leadingAnchor.constraint(equalTo: displayNameLabel.leadingAnchor),
            
            
            deviceStatusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            deviceStatusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.2)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        backgroundColor = Utils.foregroundColour
        
        layer.cornerRadius = 5
        
        layer.borderWidth = 1
        layer.borderColor = Utils.borderColour.cgColor
    }
    
    
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        // Make sure we are updating UI on the main thread!
        DispatchQueue.main.async {
            self.displayNameLabel.text = viewModel.displayName
            self.deviceStatusLabel.text = viewModel.status
        }
        
    }
    
}



//MARK: interface builder
extension ListedRemoteView {
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUpView()
    }
}




//MARK: -
//MARK: - ViewModel
final class ListedRemoteViewModel: NSObject, ObservesRemote {

    private var remote: Remote
    var onInfoUpdated: ()->Void = {}
    var onTransferAdded: (TransferOperationViewModel)->Void = { viewmodel in }

    public var displayName: String {
        return remote.details.displayName
    }


    public var uuid: String {
        return remote.details.uuid
    }

    public var status: String {
        
        switch remote.details.status {
        case .FetchingCredentials,
             .AquiringDuplex, .DuplexAquired,
             .OpeningConnection : return "Connecting"
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





