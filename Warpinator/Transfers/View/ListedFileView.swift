//
//  ListeFileView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-08.
//

import UIKit




// MARK: View
class ListedFileOperationView: UIView {

    private let DEBUG_TAG: String = "ListedFileOperationView: "
    
    let filesNameLabel: UILabel = {
        let label = UILabel()
        label.text = "File --"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let bytesLabel: UILabel = {
        let label = UILabel()
        label.text = "--.--B"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    var tapRecognizer: TapGestureRecognizerWithClosure?
    
    var viewModel: FileViewModel?
    
    override init(frame: CGRect){
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    convenience init(withViewModel model: FileViewModel, onTap action: @escaping ()->Void = {}){
        self.init()
        
        backgroundColor = UIColor.orange.withAlphaComponent(0.2)
        
        viewModel = model
        viewModel?.onUpdated = {
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
        
        addSubview(filesNameLabel)
        addSubview(bytesLabel)
        
        constraints += [
            
            filesNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            filesNameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            bytesLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            bytesLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.2)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        filesNameLabel.text = "\(viewModel.name)"
        bytesLabel.text = "\(viewModel.size)"
        
    }
    

}




// MARK: -
// MARK: - Reader View Model
final class ListedFileSelectionReaderViewModel: FileViewModel {
    
    var onUpdated: () -> Void = {}
    
    private let operation: FileSelectionReader
    
    var name: String {
        return operation.filename
    }
    
    var type: String {
        return "File"
    }
    
    var size: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let bytesCount = operation.totalBytes
        
        return formatter.string(fromByteCount:  Int64( bytesCount) )
    }
    
    var progress: Double {
        return 0
    }
    
    init(_ selection: FileSelectionReader){
        operation = selection
        operation.addObserver(self)
    }
    
    
    func update(){
        DispatchQueue.main.async {
            self.onUpdated()
        }
    }
    
    deinit {
        operation.removeObserver(self)
    }
    
}



// MARK: -
// MARK: - Sender View Model
class FileWriterViewModel: FileViewModel {
    
    var operation: FileWriter
    var onUpdated: ()->Void = {}
    
    var type: String {
        // TODO: expose MIME
        return "File"
    }
    
    var name: String {
        
        return operation.filename
    }
    
    var size: String {
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let bytes = operation.writtenBytesCount
        
        return formatter.string(fromByteCount:  Int64( bytes) )
    }
    
    var progress: Double {
        return 0
    }
    
    
    init(operation: FileWriter){
        self.operation = operation
        operation.addObserver(self)
    }
    
    func infoDidUpdate(){
        DispatchQueue.main.async {
            self.onUpdated()
        }
    }
    
    deinit {
        operation.removeObserver(self)
    }
}
