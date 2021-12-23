//
//  ListeFileView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-08.
//

import UIKit




// MARK: View
final class ListedFileOperationView: UIView {

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
    
    var viewModel: ListedFileViewModel?
    
    override init(frame: CGRect){
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    convenience init(withViewModel model: ListedFileViewModel, onTap action: @escaping ()->Void = {}){
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





// MARK: ListedFileViewModel
protocol ListedFileViewModel {
    
    var onUpdated: ()->Void { get set }
    
    var type: String { get }
    var name: String { get }
    var size: String { get }
    var progress: Double { get }
    
}



// MARK: -
// MARK: - Reader View Model
final class ListedFileReaderViewModel: NSObject, ListedFileViewModel, ObservesFileOperation {
    
    private let operation: FileReader
    var onUpdated: () -> Void = {}
    
    
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
    
    init(_ selection: FileReader){
        operation = selection
        super.init()
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



// MARK: -
// MARK: - Sender View Model
final class ListedFileWriterViewModel: NSObject, ListedFileViewModel, ObservesFileOperation {
    
    private var operation: FileWriter
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
        super.init()
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
