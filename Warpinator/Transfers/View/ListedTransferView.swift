//
//  ListedTransferView.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-28.
//

import UIKit



// MARK: View
@IBDesignable
final class ListedTransferView: UIView {

    private let DEBUG_TAG: String = "ListedTransferView: "
    
    // MARK: labels
    let filesLabel: UILabel = {
        let label = UILabel()
        label.text = "-----"
        label.textColor = Utils.textColour
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let transferStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Status..."
        label.textColor = Utils.textColour
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    lazy var transferDirectionImageView : UIImageView = {
        
//        let image = UIImage(systemName: "timelapse",
//                            compatibleWith: self.traitCollection)!.withRenderingMode(.alwaysTemplate)
        
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = Utils.textColour
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }()
    
    var tapRecognizer: TapGestureRecognizerWithClosure?
    
    var viewModel: ListedTransferViewModel?
    
    
    
    //
    // MARK: - init
    override init(frame: CGRect){
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    convenience init(withViewModel model: ListedTransferViewModel,
                     onTap action: @escaping ()->Void = {}){
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
    
    
    //
    // MARK: setupView
    func setUpView(){
        
        var constraints: [NSLayoutConstraint] = []
        
        addSubview(transferDirectionImageView)
        addSubview(filesLabel)
        addSubview(transferStatusLabel)
        
        constraints += [
            
            transferDirectionImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            
            transferDirectionImageView.topAnchor.constraint(lessThanOrEqualTo: topAnchor, constant: 15),
            transferDirectionImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            transferDirectionImageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -15),
            
            transferDirectionImageView.widthAnchor.constraint(equalTo: transferDirectionImageView.heightAnchor),
            
            filesLabel.leadingAnchor.constraint(equalTo: transferDirectionImageView.trailingAnchor, constant: 15),
            filesLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            transferStatusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            transferStatusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
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
        
        filesLabel.text = "\(viewModel.fileCount)"
        transferStatusLabel.text = "\(viewModel.status)"
        
        transferDirectionImageView.image = viewModel.directionImage
        
        
        let waitingColour: UIColor = UIColor.init(red: 111/255.0, green: 179/255.0, blue: 71.0/255.0, alpha: 1)
        backgroundColor =  viewModel.status == "WAITING" ? waitingColour : Utils.foregroundColour
        
        
        
        setNeedsLayout()
        
    }

}





//
// MARK: - View Model
final class ListedTransferViewModel: NSObject, ObservesTransferOperation {
    
    private var operation: TransferOperation
    
    var onInfoUpdated: ()->Void = {}
    
    
    var UUID: UInt64 {
        return operation.UUID
    }
    
    
    var directionImage: UIImage {
        
        switch operation.direction {
        case .RECEIVING: return UIImage(systemName: "arrow.down.square.fill")!
        case .SENDING: return UIImage(systemName: "arrow.up.square.fill")!
        }
        
    }
    
    
    var fileCount: String {
        var fileString = "File"
        
        if operation.fileCount != 1 {
            fileString = fileString + "s"
        }
        
        return "\(operation.fileCount) " + fileString
    }
    
    
    var status: String {
        switch operation.status {
        case .FAILED(_): return "FAILED"
        case .WAITING_FOR_PERMISSION: return "WAITING"
        default: return "\(operation.status)"
        }
    }
    
    
    init(for operation: TransferOperation) {
        self.operation = operation
        super.init()
        operation.addObserver(self)
    }
    
    
    func infoDidUpdate(){
        DispatchQueue.main.async { // execute UI on main thread
            self.onInfoUpdated()
        }
    }
    
    
    func fileAdded() {
        
    }
    
    
    deinit {
        operation.removeObserver(self)
    }
}







// MARK: Interface Builder
extension ListedTransferView {
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUpView()
        
        transferDirectionImageView.image = UIImage(systemName: "arrow.down.app.fill")!
        
        filesLabel.text = "3 Files"
        transferStatusLabel.text = "Transferring"
        
    }
}
