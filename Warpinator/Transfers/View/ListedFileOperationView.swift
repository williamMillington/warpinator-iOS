//
//  ListedFileView.swift
//  Warpinator
//
//  Created by William Millington on 2021-12-08.
//

import UIKit




// MARK: View
@IBDesignable
final class ListedFileOperationView: UIView {

    private let DEBUG_TAG: String = "ListedFileOperationView: "
    
    
    lazy var selectionImageView: UIImageView = {
        
        let image = UIImage(systemName: "doc",
                            compatibleWith: self.traitCollection)!.withRenderingMode(.alwaysTemplate)
        
        let view = UIImageView(image: image)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = Utils.textColour
//        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
//        view.setContentCompressionResistancePriority(.de, for: .vertical)
        return view
    }()
    
    
    let fileTypeLabel: UILabel = {
        let label = UILabel()
        label.text = "Type"
        label.textColor = Utils.textColour
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let fileNameLabel: UILabel = {
        let label = UILabel()
        label.text = "File --"
        label.textColor = Utils.textColour
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingMiddle
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let bytesLabel: UILabel = {
        let label = UILabel()
        label.text = "--.--B"
        label.textColor = Utils.textColour
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
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
    
    
    //
    // MARK: setUpView
    func setUpView(){
        
        var constraints: [NSLayoutConstraint] = []
        
        addSubview(selectionImageView)
        addSubview(fileNameLabel)
        addSubview(fileTypeLabel)
        addSubview(bytesLabel)
        
        constraints += [
            
            selectionImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),

            selectionImageView.topAnchor.constraint(lessThanOrEqualTo: topAnchor, constant: 10),
            selectionImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            selectionImageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),

            selectionImageView.widthAnchor.constraint(equalTo: selectionImageView.heightAnchor),
            
            
            fileNameLabel.leadingAnchor.constraint(equalTo: selectionImageView.trailingAnchor, constant: 10),
            fileNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            fileNameLabel.topAnchor.constraint(equalTo: selectionImageView.topAnchor, constant: 1),
            fileNameLabel.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            
            
            fileTypeLabel.leadingAnchor.constraint(equalTo: selectionImageView.trailingAnchor, constant: 10),
            fileTypeLabel.topAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            fileTypeLabel.bottomAnchor.constraint(equalTo: selectionImageView.bottomAnchor, constant: -1),
            
            
            bytesLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            bytesLabel.topAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            bytesLabel.bottomAnchor.constraint(equalTo: selectionImageView.bottomAnchor, constant: -1)
//            ,
//            
//            heightAnchor.constraint(greaterThanOrEqualTo: widthAnchor, multiplier: 0.15)
            
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
        
        fileNameLabel.text = "\(viewModel.name)"
        bytesLabel.text = "\(viewModel.size)"
        fileTypeLabel.text = "\(viewModel.type)"
    }
    

}






//MARK: prepareForInterfaceBiulder
extension ListedFileOperationView {
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        
        setUpView()
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



//
// MARK: - FileReader VM
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


//
// MARK: - FolderReader VM
final class ListedFolderReaderViewModel: NSObject, ListedFileViewModel, ObservesFileOperation {
    
    private let operation: FolderReader
    var onUpdated: () -> Void = {}
    
    
    var name: String {
        return operation.selectionName
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
    
    init(_ selection: FolderReader){
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


//
// MARK: - FileWriterVM
final class ListedFileWriterViewModel: NSObject, ListedFileViewModel, ObservesFileOperation {
    
    private var operation: FileWriter
    var onUpdated: ()->Void = {}
    
    var type: String {
        // TODO: expose MIME
        return "File"
    }
    
    var name: String {
        
        return operation.downloadName
    }
    
    var size: String {
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let bytes = operation.bytesWritten
        
        return formatter.string(fromByteCount:  Int64( bytes) )
    }
    
    
    var progress: Double {
        return 0
    }
    
    
    init(_ operation: FileWriter){
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


//
// MARK: - FolderWriterVM
final class ListedFolderWriterViewModel: NSObject, ListedFileViewModel, ObservesFileOperation {
    
    private var operation: FolderWriter
    var onUpdated: ()->Void = {}
    
    var type: String {
        // TODO: expose MIME
        return "Folder"
    }
    
    var name: String {
        return operation.downloadName
    }
    
    var size: String {
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let bytes = operation.bytesWritten
        
        return formatter.string(fromByteCount:  Int64( bytes) )
    }
    
    
    var progress: Double {
        return 0
    }
    
    
    init(_ operation: FolderWriter){
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



