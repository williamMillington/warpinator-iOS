//
//  CreateTransferCoordinator.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-13.
//

import UIKit
import UniformTypeIdentifiers
import MobileCoreServices


class CreateTransferCoordinator: NSObject, Coordinator, SubCoordinator {
    
    private let DEBUG_TAG: String = "CreateTransferCoordinator: "
    
    var parent: Coordinator
    
    var childCoordinators = [Coordinator]()
    var navController: UINavigationController
    
    var remote: Remote
    
    
    init(for r: Remote, parent p: Coordinator, withNavigationController controller: UINavigationController){
        
        parent = p
        remote = r
        navController = controller
        
        super.init()
        
        navController.setNavigationBarHidden(true, animated: false)
        
        
        Utils.lockOrientation(.portrait)
    }
    
    
    func start() {
//        print(DEBUG_TAG+"starting")
        showSendingScreen()
    }
    
    func back(){
        parent.start()
        parent.coordinatorDidFinish(self)
    }
    
    
    
    func showSendingScreen(){
        
        let vm = RemoteViewModel(remote)
        
        // if the previously exists in the stack, rewind
        if let remoteVC = navController.viewControllers.first(where: { controller in
            return controller is CreateSendTransferViewController
        }) {
            navController.popToViewController(remoteVC, animated: false)
        }
        else {
            
            let remoteVC = CreateSendTransferViewController(withViewModel: vm)
            remoteVC.coordinator = self
            
            
            navController.pushViewController(remoteVC, animated: false)
        }
        
        
    }
    
    
    func sendFiles(_ selections: [FileSelection]){
        
        remote.sendFiles(selections)
        back()
    }
    
    
    
//    func cancel(){
//        parent.start()
//        back()
//    }
    
    
    func coordinatorDidFinish(_ child: Coordinator){
        for (i, coordinator) in childCoordinators.enumerated() {
            if coordinator === child {
                childCoordinators.remove(at: i)
                break
            }
        }
    }
    
}




//extension CreateTransferCoordinator: UIDocumentPickerDelegate {
//
//    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
//
//        print(DEBUG_TAG+"Documents picked")
//
//        for url in urls {
//            print(DEBUG_TAG+"\(url)")
//            print(DEBUG_TAG+"\t\(url.lastPathComponent)")
//            print(DEBUG_TAG+"\t\(url.pathExtension)")
//            print(DEBUG_TAG+"\t\(url.hasDirectoryPath)")
//
//        }
//
//    }
//
//    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
//
//        print(DEBUG_TAG+"Document picker cancelled")
//        controller.dismiss(animated: true)
////        showSendingScreen()
//    }
//
//
//}
