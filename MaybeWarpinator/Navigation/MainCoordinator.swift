//
//  MainCoordinator.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit
import GRPC



class MainCoordinator: NSObject, Coordinator {
    
    private let DEBUG_TAG: String = "MainCoordinator: "
    
    var childCoordinators = [Coordinator]()
    var navController: UINavigationController
    
    
    var serverEventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    var remoteEventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    
    var remoteManager: RemoteManager = RemoteManager()
    
    var settingsManager: SettingsManager = SettingsManager.shared
    
    var authManager: Authenticator = Authenticator.shared
    
    var server: Server = Server()
    lazy var registrationServer = RegistrationServer(settingsManager: settingsManager)
    
    
    
    
    lazy var queueLabel = "MainCoordinatorCleanupQueue"
    lazy var cleanupQueue = DispatchQueue(label: queueLabel, qos: .userInteractive)

    
    
    init(withNavigationController controller: UINavigationController){
        navController = controller
        
        navController.setNavigationBarHidden(true, animated: false)
        
        Utils.lockOrientation(.portrait)
        
        super.init()
//        mockRemote()
        
        remoteManager.remoteEventloopGroup = remoteEventLoopGroup
        
        
        server.eventLoopGroup = serverEventLoopGroup
        registrationServer.eventLoopGroup = serverEventLoopGroup
        
        
        server.remoteManager = remoteManager
        registrationServer.remoteManager = remoteManager
        
        server.settingsManager = settingsManager
        registrationServer.settingsManager = settingsManager
        
        
        server.authenticationManager = authManager
        
        server.start()
        registrationServer.start()
        
        
    }
    
    
    func start() {
        
        showMainViewController()
        
//        mockRemote()
    }
    
    
    // MARK: main viewcontroller
    func showMainViewController(){
        
        // if the previously exists in the stack, rewind
        if let mainMenuVC = navController.viewControllers.first(where: { controller in
            return controller is ViewController
        }) {
            navController.popToViewController(mainMenuVC, animated: false)
        } else {
            
            let bundle = Bundle(for: type(of: self))
            let mainMenuVC = ViewController(nibName: "MainView", bundle: bundle)
            
            mainMenuVC.coordinator = self
            mainMenuVC.settingsManager = settingsManager
            
            remoteManager.remotesViewController = mainMenuVC
            
            navController.pushViewController(mainMenuVC, animated: false)
        }
    }
    
    
    
    // MARK: remote selected
    func userSelected(_ remoteUUID: String){
        
//        print(DEBUG_TAG+"user selected remote \(remoteUUID)")
        
        if let remote = remoteManager.containsRemote(for: remoteUUID) {
            
            let remoteCoordinator = RemoteCoordinator(for: remote, parent: self, withNavigationController: navController)
            
            childCoordinators.append(remoteCoordinator)
            remoteCoordinator.start()
            
        }
    }
    
    
    
    
    // MARK: show settings
    func showSettings() {
        
        
        // if the previously exists in the stack, rewind
        if let settingsVC = navController.viewControllers.first(where: { controller in
            return controller is SettingsViewController
        }) {
            navController.popToViewController(settingsVC, animated: false)
        } else {
            
            let bundle = Bundle(for: type(of: self))
            let settingsVC = SettingsViewController(nibName: "SettingsViewController", bundle: bundle)
            
            settingsVC.coordinator = self
            settingsVC.settingsManager = settingsManager
            
            navController.pushViewController(settingsVC, animated: false)
        }
        
    }
    
    //
    // MARK: shutdown
    func shutdown(){
        
        remoteManager.shutdownAllRemotes()
        
        // TODO: make these receive a future, so we
        // can try to coordinate the eventloopgroup shutdown
        
        server.stop()
        registrationServer.stop()
        
        serverEventLoopGroup.shutdownGracefully(queue: cleanupQueue) { error in
            print(self.DEBUG_TAG+"Completed serverEventLoopGroup shutdown")
        }
        remoteEventLoopGroup.shutdownGracefully(queue: cleanupQueue) { error in
            print(self.DEBUG_TAG+"Completed remoteEventLoopGroup shutdown")
        }
        
        
    }
    
    
//    func mockTransferReceive(){
//
//        let remote = Remote(details: RemoteDetails.MOCK_DETAILS)
//        let transfer = MockReceiveTransfer()
//
//        let vm = ReceiveTransferViewModel(operation: transfer, from: remote)
//        let vc = ReceiveTransferViewController(withViewModel: vm)
//
//        navController.pushViewController(vc, animated: false)
//
//    }
    
    
    func coordinatorDidFinish(_ child: Coordinator){
        for (i, coordinator) in childCoordinators.enumerated() {
            if coordinator === child {
                showMainViewController()
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
                
                self.remoteManager.addRemote(mockRemote)
            }
            
        }
        
        
    }
    
}
