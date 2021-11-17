//
//  MainCoordinator.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit


class MainCoordinator: NSObject, Coordinator {
    
    
    var childCoordinators = [Coordinator]()
    var navController: UINavigationController
    
    
    
    
    init(withNavigationController controller: UINavigationController){
        navController = controller
        
//        navController.setToolbarHidden(true, animated: false)
        navController.setNavigationBarHidden(true, animated: false)
        
        
        Utils.lockOrientation(.portrait)
    }
    
    
    func start() {
        
        showMenu()
    }
    
    
    func showMenu(){
        
        // if the previously exists in the stack, rewind
        if let mainMenuVC = navController.viewControllers.first(where: { controller in
            return controller is ViewController
        }) {
            navController.popToViewController(mainMenuVC, animated: false)
        }
        else {
            
            let mainMenuVC = ViewController()

            mainMenuVC.coordinator = self
            
            navController.pushViewController(mainMenuVC, animated: false)
        }
    }
    
    
    
    func userSelected(_ remote: RemoteDetails){
        
        
        
        
    }
    
    
    
    func coordinatorDidFinish(_ child: Coordinator){
        for (i, coordinator) in childCoordinators.enumerated() {
            if coordinator === child {
                showMenu()
                childCoordinators.remove(at: i)
                break
            }
        }
    }
}
