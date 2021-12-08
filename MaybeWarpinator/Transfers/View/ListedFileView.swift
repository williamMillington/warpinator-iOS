//
//  ListeFileView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-08.
//

import UIKit

class ListedFileView: UIView {

    private let DEBUG_TAG: String = "ListedFileView: "
    
    var viewModel: FileViewModel?
    
//    let filePreviewImage: UIImage = {
//       let fileName = ""
//        return UIImage(named: fileName)!
//    }()
    
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
