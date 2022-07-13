//
//  ErrorMessageView.swift
//  Warpinator
//
//  Created by William Millington on 2022-04-27.
//

import UIKit

// MARK: - Error View
final class ErrorMessageView: UIView {
    
    private let DEBUG_TAG: String = "ErrorMessageView: "
    
    let errorAnnouncementLabel: UILabel = {
        let label = UILabel()
        label.text = "An error occurred, tap to restart server"
        label.textColor = Utils.textColour
        label.tintColor = Utils.textColour
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let errorDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = Utils.textColour
        label.tintColor = Utils.textColour
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    let messageLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = Utils.textColour
        label.tintColor = Utils.textColour
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
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
    
    
    convenience init(_ error: Error, withMessage message: String, onTap action: @escaping ()->Void = {}){
        self.init(frame: .zero)
        
        errorDescriptionLabel.text = "\(error)"
        messageLabel.text = message
        
        // add subviews and constraints
        setUpView()
        
        // add onTap action
        tapRecognizer = TapGestureRecognizerWithClosure(action: action)
        addGestureRecognizer(tapRecognizer!)
        
    }
    
    
    //
    // MARK: setUpView
    func setUpView(){
        
        addSubview(errorAnnouncementLabel)
        addSubview(errorDescriptionLabel)
        addSubview(messageLabel)
        
        let constraints = [
            errorAnnouncementLabel.bottomAnchor.constraint(equalTo: errorDescriptionLabel.topAnchor, constant: -15 ),
            errorAnnouncementLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            errorDescriptionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorDescriptionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: errorDescriptionLabel.bottomAnchor, constant: 10),
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            errorAnnouncementLabel.widthAnchor.constraint(equalTo: widthAnchor, constant: -10),
            errorDescriptionLabel.widthAnchor.constraint(equalTo: widthAnchor, constant: -10),
            messageLabel.widthAnchor.constraint(equalTo: widthAnchor, constant: -10)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
//        backgroundColor = UIColor.blue.withAlphaComponent(0.5)
        backgroundColor = Utils.backgroundColour
        
    }
    
}
