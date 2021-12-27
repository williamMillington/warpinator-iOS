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
        
        navController.setNavigationBarHidden(true, animated: false)
        
        Utils.lockOrientation(.portrait)
        MainService.shared.start()
    }
    
    
    func start() {
        
        showMenu()
        
        mockRemote()
    }
    
    
    func showMenu(){
        
        // if the previously exists in the stack, rewind
        if let mainMenuVC = navController.viewControllers.first(where: { controller in
            return controller is ViewController
        }) {
            navController.popToViewController(mainMenuVC, animated: false)
        }
        else {
            
            let bundle = Bundle(for: type(of: self))
            let mainMenuVC = ViewController(nibName: "MainView", bundle: bundle)
            mainMenuVC.coordinator = self
            
            MainService.shared.remoteManager.remotesViewController = mainMenuVC
            
            navController.pushViewController(mainMenuVC, animated: false)
        }
    }
    
    
    
    func userSelected(_ remoteUUID: String){
        
//        print(DEBUG_TAG+"user selected remote \(remoteUUID)")
        
        if let remote = MainService.shared.remoteManager.containsRemote(for: remoteUUID) {
            
            let remoteCoordinator = RemoteCoordinator(for: remote, parent: self, withNavigationController: navController)
            
            childCoordinators.append(remoteCoordinator)
            remoteCoordinator.start()
            
        }
        
    }
    
    
    func mockTransferReceive(){
        
        let remote = Remote(details: RemoteDetails.MOCK_DETAILS)
        let transfer = MockReceiveTransfer()
        
        let vm = ReceiveTransferViewModel(operation: transfer, from: remote)
        let vc = ReceiveTransferViewController(withViewModel: vm)
        
        navController.pushViewController(vc, animated: false)
        
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


extension MainCoordinator {
    
    func mockRemote(){
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            
            
            for i in 0..<2 {
                
                var mockDetails = RemoteDetails.MOCK_DETAILS
                mockDetails.uuid = mockDetails.uuid + "__\(i)\(i+1)"
                
                let mockRemote = Remote(details: mockDetails)
                
                self.mainService.remoteManager.addRemote(mockRemote)
            }
            
        }
        
        
    }
    
}
