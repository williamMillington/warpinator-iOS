//
//  ViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-09-30.
//

import UIKit
import GRPC
import NIO

class ViewController: UIViewController {

    var mainService: MainService = MainService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.backgroundColor = .blue
        
        
        MainService.shared.start()
        
        
    }


}

