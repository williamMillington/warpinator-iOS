//
//  MainCoordinator.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit


class MainCoordinator: NSObject, Coordinator {
    
    private let DEBUG_TAG: String = "MainCoordinator: "
    
    var childCoordinators = [Coordinator]()
    var navController: UINavigationController
    
    
    var mainService: MainService = MainService()
    
    
    init(withNavigationController controller: UINavigationController){
        navController = controller
        
//        navController.setToolbarHidden(true, animated: false)
        navController.setNavigationBarHidden(true, animated: false)
        
        
        Utils.lockOrientation(.portrait)
    }
    
    
    func start() {
        
        showMenu()
        
        
        MainService.shared.start()
        
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
            
            MainService.shared.remoteManager.remotesViewController = mainMenuVC
            
            navController.pushViewController(mainMenuVC, animated: false)
        }
    }
    
    
    
    func userSelected(_ remoteUUID: String){
        
        
        print(DEBUG_TAG+"user selected remote \(remoteUUID)")
        
        if let remote = MainService.shared.remoteManager.containsRemote(for: remoteUUID) {
            
            let viewmodel = RemoteViewModel(remote)
            
            let remoteVC = RemoteViewController(withViewModel: viewmodel)
            remoteVC.coordinator = self
            
            navController.pushViewController(remoteVC, animated: false)
        }
        
    }
    
    
    
//    func showRemote(_ viewModel: RemoteViewModel){
//
//
//        let mainMenuVC = ViewController()
//        mainMenuVC.coordinator = self
//
//
//        navController.pushViewController(mainMenuVC, animated: false)
//
//
//    }
    
    
    
    
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
