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
    
    
    // used when a method needs to return a future, but server/remote eventloops are in shutdown
    var errorEventLoop = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1)
    
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
        
        // Try-catch handles errors thrown by me, related to authentication credentials.
        // Errors from the GRPC server itself are captured in the serverFuture.whenFailure
        do {
            
            let serverFuture = try server?.start()
            
            
            // Test server failure
//            let promise = serverEventLoopGroup?.next().makePromise(of: GRPC.Server.self)
//            let serverFuture = promise?.futureResult
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                promise?.fail(Server.ServerError.SERVER_FAILURE)
//            }
            
            serverFuture?.whenFailure { error in
                self.reportError(error, withMessage: "Server future failed")
            }
            
            serverFuture?.whenSuccess { server in
                print(self.DEBUG_TAG+"server succeeded")
                // registrationServer is responsible for starting mDNS, so wait until
                // our server is ready before announcing ourselves
                self.registrationServer?.start()
            }
            
        } catch {
            reportError(error, withMessage: "Server future failed")
        }
        
    }
    
    
    func shutdownConnections() -> EventLoopFuture<Void> {
        
//        do {
            return remoteManager.shutdownAllRemotes() ?? errorEventLoop.next().makeSucceededVoidFuture()
//        } catch {
//            print(DEBUG_TAG+"shutdownConnection failed: \(error)")
//            return errorEventLoop.next().makeSucceededVoidFuture()
//        }
        
        
    }
    
    
    
    //
    // MARK: stop servers
//    func stopServers() -> EventLoopFuture<(Void, Void)> {
    func stopServers() -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+"stopping servers... ")
        
//        var futures = remoteManager.shutdownAllRemotes()
        let remoteFuture = shutdownConnections()
        
        guard let server = server,
              let registrationServer = registrationServer else {
                  return errorEventLoop.next().makeSucceededVoidFuture()
              }
        
        
        
        // I thiink is how you chain futures together
        return remoteFuture.flatMap {
            return server.stop()
        }.flatMap {
            return registrationServer.stop()
        }
        
//        let server_future = server.stop()
//        let registration_future = registrationServer.stop()
        
        
//        let future
        
//        return combinedFuture
//        serverEventLoopGroup.next().submit {
//
//            do { try remoteFuture.wait() }
//            catch { print(self.DEBUG_TAG+"registration server failed to stop: \(error)")  }
//
//            do { try registration_future.wait() }
//            catch { print(self.DEBUG_TAG+"registration server failed to stop: \(error)")  }
//
//            do { try server_future.wait() }
//            catch { print(self.DEBUG_TAG+"server failed to stop: \(error)")  }
//        }
        
    }
    
    
    //
    // MARK: restart servers
    func restartServers(){
        
        let stopFuture = stopServers()
        
        
        
        stopFuture.whenFailure { error in
            print(self.DEBUG_TAG+"servers failed to stop: \(error)")
        }
        
        // wait until servers have stopped, then start them
        stopFuture.whenSuccess { _ in
            self.startServers()
        }
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
    func beginShutdown() -> EventLoopFuture<Void> {
        
//        remoteManager.shutdownAllRemotes()
//
//        guard let server = server,
//              let registrationServer = registrationServer else {
//                  let future_1 = errorEventLoop.next().makeSucceededVoidFuture()
//                  let future_2 = errorEventLoop.next().makeSucceededVoidFuture()
//                  return future_1.and(future_2)
//              }
//
//
//        let future_1 = server.stop()
//        future_1.whenComplete { result in
//            print(self.DEBUG_TAG+"Server has completed shutdown")
//            self.server = nil
//        }
//
//        let future_2 = registrationServer.stop()
//        future_2.whenComplete { result in
//            print(self.DEBUG_TAG+"Registration Server has completed shutdown")
//            self.registrationServer = nil
//        }
        
        let future = stopServers()
        
        
        
        
        return future
    }
    
    
    func shutdownEventLoops(){
        print(self.DEBUG_TAG+"shutting down eventloop")
        // TODO: find a way to sync these
        serverEventLoopGroup?.shutdownGracefully (queue:  .main) { error in
            print(self.DEBUG_TAG+"Completed serverEventLoopGroup shutdown")
            self.serverEventLoopGroup = nil
        }
        
        
        remoteEventLoopGroup?.shutdownGracefully(queue: .main) { error in
            print(self.DEBUG_TAG+"Completed remoteEventLoopGroup shutdown")
            self.remoteEventLoopGroup = nil
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





extension MainCoordinator: ErrorDelegate {
    
    func reportError(_ error: Error, withMessage message: String) {
        
        print(self.DEBUG_TAG+"error reported: \(error) \twith message: \(message)")
        
        
        // Error reporting that updates UI --MUST-- be done on Main thread
        DispatchQueue.main.async {
            
            // only the main controller has an error screen, for now
            if let vc = self.navController.visibleViewController as? ViewController {
                vc.showErrorScreen()
            }
        }
        
    }
    
}
