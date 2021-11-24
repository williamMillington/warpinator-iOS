//
//  TransferViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-24.
//

import UIKit



class TransferViewController: UIViewController {

    
    var coordinator: MainCoordinator?
    
    
    var viewModel: RemoteViewModel?
    
    init(withViewModel viewModel: RemoteViewModel) {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
        
        self.viewModel = viewModel
        
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    
    
    
    

}
