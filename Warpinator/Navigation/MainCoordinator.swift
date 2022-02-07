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
    
    lazy var server: Server = Server(settingsManager: settingsManager)
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
        
    }
    //
    // MARK: start
    func start() {
        
        showMainViewController()
        startServers()
//        mockRemote()
    }
    
    
    //
    // MARK: start servers
    private func startServers(){
        print(DEBUG_TAG+"starting servers: ")
        server.start()
        registrationServer.start()
        
        
    }
    
    
    //
    // MARK: stop servers
    private func stopServers(){
        print(DEBUG_TAG+"stopping servers: ")
        
        remoteManager.shutdownAllRemotes()
        
        _ = server.stop()
        _ = registrationServer.stop()
        
    }
    
    
    
    //
    // MARK: restart servers
    func restartServers(){
        
//        remoteManager.shutdownAllRemotes()
//
//        _ = server.stop()
//        _ = registrationServer.stop()
        stopServers()
        startServers()
        
        
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
    func remoteSelected(_ remoteUUID: String){
        
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
            
//            let bundle = Bundle(for: type(of: self))
            let settingsVC = SettingsViewController(settingsManager: settingsManager)
//            (nibName: "SettingsViewController", bundle: bundle)
            
            settingsVC.coordinator = self
            settingsVC.settingsManager = settingsManager
            
            navController.pushViewController(settingsVC, animated: false)
        }
        
    }
    
    
    
    //
    // MARK: returnFromSettings
    func  returnFromSettings(restartRequired restart: Bool) {
        
        if restart {
            restartServers()
        }
        
        showMainViewController()
        
    }
    
    
    
    
    
    //
    // MARK: shutdown
    func beginShutdown(){
        
        remoteManager.shutdownAllRemotes()
        
        // TODO: make these receive a future, so we
        // can try to coordinate the eventloopgroup shutdown
        
        _ = server.stop()
        _ = registrationServer.stop() 
        
        _ = serverEventLoopGroup.shutdownGracefully(queue: cleanupQueue) { error in
            print(self.DEBUG_TAG+"Completed serverEventLoopGroup shutdown")
        }
        _ = remoteEventLoopGroup.shutdownGracefully(queue: cleanupQueue) { error in
            print(self.DEBUG_TAG+"Completed remoteEventLoopGroup shutdown")
        }
        
    }
    
    
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
