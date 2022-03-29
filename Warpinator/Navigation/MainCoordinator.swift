//
//  MainCoordinator.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit
import GRPC
import NIO
import NIOSSL


final class MainCoordinator: NSObject, Coordinator {
    
    private let DEBUG_TAG: String = "MainCoordinator: "
    
    var childCoordinators = [Coordinator]()
    var navController: UINavigationController
    
    
    var serverEventLoopGroup: EventLoopGroup?
    var remoteEventLoopGroup: EventLoopGroup?
    
    
    var remoteManager: RemoteManager = RemoteManager()
    
    var settingsManager: SettingsManager = SettingsManager.shared
    var authManager: Authenticator = Authenticator.shared
    
    
    var server: Server?      // = Server(settingsManager: settingsManager,
                                     //authenticationManager: authManager)
    var registrationServer: RegistrationServer?      // = RegistrationServer(settingsManager: settingsManager)
    
    
//    let queueLabel = "MainCoordinatorCleanupQueue"
//    lazy var cleanupQueue = DispatchQueue(label: queueLabel, qos: .userInteractive)
    
    
    
    init(withNavigationController controller: UINavigationController){
        navController = controller
        
        navController.setNavigationBarHidden(true, animated: false)
        
        Utils.lockOrientation(.portrait)
        
        super.init()
//        mockRemote()
    }
    
    
    
    
    //
    // MARK: start
    func start() {
        
        showMainViewController()
//        startServers()
//        mockRemote()
    }
    
    
    
    //
    // MARK: start servers
    func startServers(){
        
        print(DEBUG_TAG+"starting servers...")
        
        
        // create eventloops
        serverEventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
        remoteEventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
        
        // remoteManager is responsible for providing remotes with an eventloop
        remoteManager.remoteEventloopGroup = remoteEventLoopGroup
        
        
        server = Server(eventloopGroup: serverEventLoopGroup!,
                        settingsManager: settingsManager,
                        authenticationManager: authManager,
                        remoteManager: remoteManager,
                        errorDelegate: self)
        
        registrationServer = RegistrationServer(eventloopGroup: remoteEventLoopGroup!,
                                                settingsManager: settingsManager,
                                                remoteManager: remoteManager)
        
        
        
//        do {
            
            // TODO: capture future and pop-up any errors if it fails
        // Note: the optional we care about unwrapping here is the EventLoopFuture<GRPC.Server>? returned
        // by server, not server itself
        guard let serverFuture = server?.start() else {
            print(DEBUG_TAG+"server failed")
            return
        }
        
        
        
        serverFuture.whenFailure { error in
            self.reportError(error, withMessage: "Server future failed")
        }
        
        serverFuture.whenSuccess { server in
            print(self.DEBUG_TAG+"server succeeded")
            // registrationServer is responsible for starting mDNS, so wait until
            // our server is ready before announcing ourselves
            self.registrationServer?.start()
        }
//        } catch let server_error as Server.ServerError {
//
//            switch server_error {
//            case .CREDENTIALS_INVALID, .CREDENTIALS_UNAVAILABLE:
//                print(DEBUG_TAG+"credentials error (\(server_error.localizedDescription))")
//                print(DEBUG_TAG+"\t\t regenerating credentials and restarting")
//
//                authManager.generateNewCertificate()
//
//                /* TODO if problem is not solved by regenerating credentials, this recurses infinitely
//                */
////                startServers()
//
//            default: print(DEBUG_TAG+"Server error: \(server_error)")
//
//            }
//
//        } catch  {
//            print(DEBUG_TAG+"Uknown error starting server: \(error)")
//            reportError(error, withMessage: "Uknown error starting server")
//        }
        
        
    }
    
    
    //
    // MARK: stop servers
    func stopServers(){
        print(DEBUG_TAG+"stopping servers... ")
        
        remoteManager.shutdownAllRemotes()
        
        _ = server?.stop()
        _ = registrationServer?.stop()
        
    }
    
    
    
    //
    // MARK: restart servers
    func restartServers(){
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
    
    
    
    
    // MARK: move to settings
    func showSettings() {
        
        
        // if the previously exists in the stack, rewind
        if let settingsVC = navController.viewControllers.first(where: { controller in
            return controller is SettingsViewController
        }) {
            navController.popToViewController(settingsVC, animated: false)
        } else {
            
            let settingsVC = SettingsViewController(settingsManager: settingsManager)
            
            settingsVC.coordinator = self
            settingsVC.settingsManager = settingsManager
            
            navController.pushViewController(settingsVC, animated: false)
        }
        
    }
    
    
    
    //
    // MARK: return from settings
    func  returnFromSettings(restartRequired restart: Bool) {
        
        if restart {
            restartServers()
        }
        
        showMainViewController()
        
    }
    
    
    
    // MARK: error popup
    func showErrorPop(withTitle title: String, andMessage message: String){
        
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertVC.addAction( UIAlertAction(title: "Okay", style: .default) )
        
        navController.visibleViewController?.present(alertVC, animated: true) {
            print(self.DEBUG_TAG+"continuing...")
        }
        
    }
    
    
    
    //
    // MARK: shutdown
    func beginShutdown() -> EventLoopFuture<(Void, Void)>? {
        
        remoteManager.shutdownAllRemotes()
        
        guard let s1 = server,
              let s2 = registrationServer else {
                  print(DEBUG_TAG+"no servers to shut down")
                  return nil
              }
        
        // TODO: make these receive a future, so we
        // can try to coordinate the eventloopgroup shutdown
        
        let future_1 = s1.stop()
        future_1.whenComplete { result in
            print(self.DEBUG_TAG+"Server has completed shutdown")
            self.server = nil
        }
        
        let future_2 = s2.stop()
        future_2.whenComplete { result in
            print(self.DEBUG_TAG+"Registration Server has completed shutdown")
            self.registrationServer = nil
        }
        
        
        
        serverEventLoopGroup?.shutdownGracefully (queue:  .main) { error in
            print(self.DEBUG_TAG+"Completed serverEventLoopGroup shutdown")
            self.serverEventLoopGroup = nil
        }
        
        
        remoteEventLoopGroup?.shutdownGracefully(queue: .main) { error in
            print(self.DEBUG_TAG+"Completed remoteEventLoopGroup shutdown")
            self.remoteEventLoopGroup = nil
        }
        
        
        return future_1.and(future_2)
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





extension MainCoordinator: ErrorDelegate {
    
    func reportError(_ error: Error, withMessage message: String) {
        
        print(DEBUG_TAG+"error reported: \(error) \n\twith message: \(message)")
        
        // only the main controller has an error screen, for now
        if let vc = navController.visibleViewController as? ViewController {
            vc.showErrorScreen()
        }
        
    }
    
}
