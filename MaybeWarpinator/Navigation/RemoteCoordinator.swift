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
        
    }
    
    func start() {
//        print(DEBUG_TAG+"starting")
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
            
//            print(DEBUG_TAG+"creating vc")
            let vm = RemoteViewModel(remote)
            let remoteVC = RemoteViewController(withViewModel: vm)
            remoteVC.coordinator = self
            
//            print(DEBUG_TAG+"pushing vc")
            navController.pushViewController(remoteVC, animated: false)
        }
    }
    
    
    
    func userSelectedTransfer(withUUID uuid: UInt64 ){
        
        if let operation = remote.findTransferOperation(for: uuid){
            
            // If we need to accept the transfer first
            if operation.status == .WAITING_FOR_PERMISSION &&
                operation.direction == .RECEIVING {
                
                openAcceptTransferViewController(forTransferOperation: operation)
                
            } else {
                openTransferViewController(forTransferOperation: operation)
            }
            
        } else {
            print(DEBUG_TAG+"ain't no operation for that there uuid")
        }
        
    }
    
    
    private func openTransferViewController(forTransferOperation operation: TransferOperation){
        
        let vm = TransferOperationViewModel(for: operation)
        let rm = RemoteViewModel(remote)
        let vc = TransferViewController(withTransfer: vm, andRemote: rm)
        vc.coordinator = self
        navController.pushViewController(vc, animated: false)
        
    }
    
    
    // MARK: view transfer request
    private func openAcceptTransferViewController(forTransferOperation operation: TransferOperation){
        
        let vm = ReceiveTransferViewModel(operation: operation, from: remote)
        let vc = ReceiveTransferViewController(withViewModel: vm)
        vc.coordinator = self
        navController.pushViewController(vc, animated: false)
        
    }
    
    
    
    
    
    // MARK: accept transfer
    func acceptTransfer(forTransferUUID uuid: UInt64){
        
        print(DEBUG_TAG+"user approved transfer with uuid \(uuid)")
        
        if let operation = remote.findReceiveOperation(withStartTime: uuid) {
            print(DEBUG_TAG+"\t transfer found")
//            operation.startReceive()
            remote.callClientStartTransfer(for: operation)
            showRemote()
        } else {
            print(DEBUG_TAG+"ain't no operation for that there uuid")
        }
        
    }
    
    
    // MARK: decline transfer
    func declineTransfer(forTransferUUID uuid: UInt64){
        
        print(DEBUG_TAG+"user declined transfer with uuid \(uuid)")
        
        if let operation = remote.findReceiveOperation(withStartTime: uuid) {
            print(DEBUG_TAG+"\t transfer found")
            operation.decline(nil)
//            operation.startReceive()
            showRemote()
        }else {
            print(DEBUG_TAG+"ain't no operation for that there uuid")
        }
        
    }
    
    
    // MARK: cancel transfer
    func cancelTransfer(forTransferUUID uuid: UInt64){
        
        print(DEBUG_TAG+"user cancelled transfer with uuid \(uuid)")
        
        if let operation = remote.findTransferOperation(for: uuid) {
            print(DEBUG_TAG+"\t transfer found")
            operation.orderStop(nil)
        }else {
            print(DEBUG_TAG+"ain't no operation for that there uuid")
        }
        
    }
    
    
    // MARK: retry transfer
    func retryTransfer(forTransferUUID uuid: UInt64){
        
        print(DEBUG_TAG+"user elected to re-attempt transfer with uuid \(uuid)")
        
        if let operation = remote.findSendOperation(withStartTime: uuid) {
            print(DEBUG_TAG+"\t send transfer found")
            
            operation.prepareToSend()
            
            remote.sendRequest(toTransfer: operation)
            
        } else {
            print(DEBUG_TAG+"ain't no operation for that there uuid")
        }
        
    }
    
    
    
    
    func createTransfer(){
        
        
        let transferCoordinator = CreateTransferCoordinator(for: remote, parent: self, withNavigationController: navController)
        
        childCoordinators.append(transferCoordinator)
        transferCoordinator.start()
        
        
    }
    
    
//    func openDocumentPicker(){
//        
//        
//        
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







//MARK: Mock
extension RemoteCoordinator {
    func mockReceiveTransfer(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let mockOp = ReceiveFileOperation.MockOperation.make(for: self.remote)
            self.remote.addReceivingOperation(mockOp)
        }
    }
    
    
    func mockSendTransfer(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let filenames: [FileName] = [
                FileName(name: "TestFileToSend", ext: "rtf" ),
//                FileName(name: "Dear_Evan_Hansen_PV_Score", ext: "pdf" ),
                FileName(name: "The_Last_Five_Years", ext: "pdf" )
            ]
            self.remote.sendFiles( filenames )
        }
    }
}
