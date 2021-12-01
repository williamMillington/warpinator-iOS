//
//  RemoteCoordinator.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-01.
//

import UIKit


class RemoteCoordinator: NSObject, Coordinator, SubCoordinator {
    
    private let DEBUG_TAG: String = "RemoteCoordinator: "
    
    var parent: Coordinator
    
    var childCoordinators = [Coordinator]()
    var navController: UINavigationController
    
    var remote: Remote
    
    init(for r: Remote, parent p: Coordinator, withNavigationController controller: UINavigationController){
        
        parent = p
        remote = r
        navController = controller
        
        super.init() 
        
        
//        navController.setToolbarHidden(true, animated: false)
        navController.setNavigationBarHidden(true, animated: false)
        
        
        Utils.lockOrientation(.portrait)
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let mockOp = ReceiveFileOperation.MockOperation.make(for: self.remote)
            self.remote.addReceivingOperation(mockOp)
        }
        
        
    }
    
    func start() {
        print(DEBUG_TAG+"starting")
        showRemote()
        
    }
    
    func back(){
        parent.coordinatorDidFinish(self)
    }
    
    
    func showRemote(){
        
        // if the previously exists in the stack, rewind
        if let remoteVC = navController.viewControllers.first(where: { controller in
            return controller is RemoteViewController
        }) {
            navController.popToViewController(remoteVC, animated: false)
        }
        else {
            
            print(DEBUG_TAG+"creating vc")
            let vm = RemoteViewModel(remote)
            let remoteVC = RemoteViewController(withViewModel: vm)
            remoteVC.coordinator = self
            
            print(DEBUG_TAG+"pushing vc")
            navController.pushViewController(remoteVC, animated: false)
        }
    }
    
    
    func userSelectedTransfer(withUUID uuid: UInt64     ){
        
        if let operation = remote.findTransferOperation(for: uuid){
            
            
            if operation.status == .WAITING_FOR_PERMISSION {
                
                let vm = ReceiveTransferViewModel(operation: operation, from: remote)
                let vc = ReceiveTransferViewController(withViewModel: vm)
                vc.coordinator = self
                navController.pushViewController(vc, animated: false)
                
            } else {
                
                let vm = TransferOperationViewModel(for: operation)
                let rm = RemoteViewModel(remote)
                let vc = TransferViewController(withTransfer: vm, andRemote: rm)
                vc.coordinator = self
                navController.pushViewController(vc, animated: false)
                
            }
            
            
            
            
        } else {
            print(DEBUG_TAG+"ain't no operation for that there uuid")
        }
        
        
    }
    
    
    
    
    
    func coordinatorDidFinish(_ child: Coordinator){
        for (i, coordinator) in childCoordinators.enumerated() {
            if coordinator === child {
                childCoordinators.remove(at: i)
                break
            }
        }
    }
}