//
//  ListedFileSelectionView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-14.
//

import UIKit


//MARK: viewModel
final class ListedFileSelectionViewModel {
    
    private let fileSelection: FileSelection
//    var onUpdate: ()->Void = {}
    
    var name: String {
        return fileSelection.name
    }
    
    var size: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let bytesCount = fileSelection.bytesCount
        
        return formatter.string(fromByteCount:  Int64( bytesCount) )
    }
    
    init(_ selection: FileSelection){
        fileSelection = selection
    }
    
}



//MARK: view
final class ListedFileSelectionView: UIView {

    private let DEBUG_TAG: String = "ListedFileSelectionView: "
    
    var viewModel: ListedFileSelectionViewModel?
    
    let fileNameLabel: UILabel = {
        let label = UILabel()
        label.text = "--Filename--"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let fileSizeLabel: UILabel = {
        let label = UILabel()
        label.text = "--.--B"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    override init(frame: CGRect){
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    convenience init(withViewModel model: ListedFileSelectionViewModel){
        self.init()
        
        backgroundColor = UIColor.orange.withAlphaComponent(0.2)
        
        viewModel = model
        
        // add subviews and constraints
        setUpView()
        
        updateDisplay()
    }
    
    
    func setUpView(){
        
        var constraints: [NSLayoutConstraint] = []
        
        addSubview(fileNameLabel)
        addSubview(fileSizeLabel)
        
        constraints += [
            
            fileNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            fileNameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            fileSizeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            fileSizeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.2)
            
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    
    func updateDisplay(){
        
        guard let viewModel = viewModel else { return }
        
        fileNameLabel.text = "\(viewModel.name)"
        fileSizeLabel.text = "\(viewModel.size)"
        
    }

    
    
}
