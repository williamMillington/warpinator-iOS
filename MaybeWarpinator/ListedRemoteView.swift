//
//  ListedRemoteView.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit



class ListedRemoteView: UIView {
    
    var details: RemoteDetails?
    
    
    
    
    override init(frame: CGRect){
        super.init(frame: frame)
//        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
//        setup()
    }
    
    
    convenience init(details: RemoteDetails){
        self.init()
        self.details = details
    }
    
    
    
    
    
    
    
    
}
