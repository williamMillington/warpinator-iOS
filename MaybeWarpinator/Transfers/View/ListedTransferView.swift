//
//  ListedTransferView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-28.
//

import UIKit


// MARK: View
final class ListedTransferView: UIView {

    private let DEBUG_TAG: String = "ListedTransferView: "
    
    // MARK: labels
    let filesLabel: UILabel = {
        let label = UILabel()
        label.text = "Uknown Device"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let transferStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Status..."
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    var tapRecognizer: TapGestureRecognizerWithClosure?
    
    var viewModel: ListedTransferViewModel?
    
    
    override init(frame: CGRect){
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    convenience init(withViewModel model: ListedTransferViewModel, onTap action: @escaping ()->Void = {}){
        self.init()
        
        backgroundColor = UIColor.orange.withAlphaComponent(0.2)
        
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
    
    // MARK: setupView
    func setUpView(){
        
        var constraints: [NSLayoutConstraint] = []
        
        addSubview(filesLabel)
        addSubview(transferStatusLabel)
        
        constraints += [
            
            filesLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            filesLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            transferStatusLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            transferStatusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.2)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    
    // MARK: updateDisplay
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        filesLabel.text = "\(viewModel.fileCount)"
        transferStatusLabel.text = "\(viewModel.status)"
        
    }

}




// MARK: -
// MARK: - View Model
final class ListedTransferViewModel: NSObject, ObservesTransferOperation {
    
    private var operation: TransferOperation
    
    var onInfoUpdated: ()->Void = {}
    
    var UUID: UInt64 {
        return operation.UUID
    }
    
    var fileCount: String {
        return "\(operation.fileCount)"
    }
    
    var status: String {
        
        switch operation.status {
        case .FAILED(_): return "Failed"
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
    
    deinit {
        operation.removeObserver(self)
    }
}
