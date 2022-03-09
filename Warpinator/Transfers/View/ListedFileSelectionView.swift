//
//  ListedFileSelectionView.swift
//  Warpinator
//
//  Created by William Millington on 2021-12-14.
//

import UIKit


//MARK: View
@IBDesignable
final class ListedFileSelectionView: UIView {

    private let DEBUG_TAG: String = "ListedFileSelectionView: "
    
    var viewModel: ListedFileSelectionViewModel?
    
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
    
    
    let fileNameLabel: UILabel = {
        let label = UILabel()
        label.text = "--Filename--"
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.font = UIFont.systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    
    let fileSizeLabel: UILabel = {
        let label = UILabel()
        label.text = "--.--B"
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.font = UIFont.systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()
    
    
    var tapRecognizer: TapGestureRecognizerWithClosure?
    
    
    override init(frame: CGRect){
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    convenience init(withViewModel model: ListedFileSelectionViewModel,
                     onTap action: @escaping ()->Void = {}) {
        self.init()
        
        viewModel = model
        
        // add subviews and constraints
        setUpView()
        
        // add onTap action
        tapRecognizer = TapGestureRecognizerWithClosure(action: action)
        addGestureRecognizer(tapRecognizer!)
        
        updateDisplay()
    }
    
    
    func setUpView(){
        
        var constraints: [NSLayoutConstraint] = []
        
        addSubview(selectionImageView)
        addSubview(fileNameLabel)
        addSubview(fileSizeLabel)
        
        constraints += [
            
            selectionImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),

            selectionImageView.topAnchor.constraint(lessThanOrEqualTo: topAnchor, constant: 10),
            selectionImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            selectionImageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),

            selectionImageView.widthAnchor.constraint(equalTo: selectionImageView.heightAnchor),
            
            fileNameLabel.leadingAnchor.constraint(equalTo: selectionImageView.trailingAnchor, constant: 10),
//            fileNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            fileNameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            fileNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: fileSizeLabel.leadingAnchor, constant: -5),
            
            fileSizeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            fileSizeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
//            heightAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.25)
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.15)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        
        backgroundColor = Utils.foregroundColour
        layer.cornerRadius = 5
        
        layer.borderWidth = 1
        layer.borderColor = Utils.borderColour.cgColor
    }
    
    
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        fileNameLabel.text = "\(viewModel.name)"
        fileSizeLabel.text = "\(viewModel.size)"
        
    }

    
}



//MARK: ViewModel
final class ListedFileSelectionViewModel {
    
    private let selection: TransferSelection
    
    var name: String {
        return selection.name
    }
    
    var size: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let bytesCount = selection.bytesCount
        
        return "(\(formatter.string(fromByteCount:  Int64( bytesCount) ) ))"
    }
    
    init(_ selection: TransferSelection){
        self.selection = selection 
    }
    
}










//MARK: - Interface Builder
extension ListedFileSelectionView {
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        
        fileNameLabel.text = "File name "
        fileSizeLabel.text = "402.03MB"
        
    }
}
