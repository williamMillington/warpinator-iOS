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
        MainService.shared.start()
    }
    
    
    func start() {
        
        showMenu()
        
//        mockRemote()
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
        
        
//        print(DEBUG_TAG+"user selected remote \(remoteUUID)")
        
        if let remote = MainService.shared.remoteManager.containsRemote(for: remoteUUID) {
            
//            print(DEBUG_TAG+"remote found")
            
            let remoteCoordinator = RemoteCoordinator(for: remote, parent: self, withNavigationController: navController)
            
            childCoordinators.append(remoteCoordinator)
            remoteCoordinator.start()
            
//            let viewmodel = RemoteViewModel(remote)
//
//            let remoteVC = RemoteViewController(withViewModel: viewmodel)
//            remoteVC.coordinator = self
//
//            navController.pushViewController(remoteVC, animated: false)
        }
        
    }
    
    
    func mockTransferReceive(){
        
        
        let remote = Remote(details: RemoteDetails.MOCK_DETAILS)
        let transfer = MockReceiveTransfer()
        
        
//        let receiveTransferVC= = ReceiveTransferViewController(
        let vm = ReceiveTransferViewModel(operation: transfer, from: remote)
        let vc = ReceiveTransferViewController(withViewModel: vm)
        
//        vc.coordinator = self
        
        navController.pushViewController(vc, animated: false)
        
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


extension MainCoordinator {
    
    func mockRemote(){
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            
            var mockDetails = RemoteDetails.MOCK_DETAILS
            mockDetails.uuid = mockDetails.uuid + "__555"
            
            let mockRemote = Remote(details: mockDetails)
            
            self.mainService.remoteManager.addRemote(mockRemote)
        }
        
        
    }
    
}
