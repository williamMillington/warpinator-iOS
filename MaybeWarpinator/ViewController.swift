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

//    let server: Server = Server()
    
    var mainService: MainService = MainService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.backgroundColor = .blue
        
//        server.start()
        
        MainService.shared.start()
        
        
    }


}

