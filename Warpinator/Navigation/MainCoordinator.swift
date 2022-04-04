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
    
    var mDNSBrowser: MDNSBrowser
    var mDNSListener: MDNSListener
    
    
    var settingsManager: SettingsManager = SettingsManager.shared
    var authManager: Authenticator = Authenticator.shared
    var remoteManager: RemoteManager = RemoteManager()
    
    
    var serverEventLoopGroup: EventLoopGroup?
    var remoteEventLoopGroup: EventLoopGroup?
    
    var server: Server?
    var registrationServer: RegistrationServer?
    
    init(withNavigationController controller: UINavigationController){
        navController = controller
        
        navController.setNavigationBarHidden(true, animated: false)

        Utils.lockOrientation(.portrait)
        
        
        mDNSBrowser = MDNSBrowser()
        mDNSListener = MDNSListener(settingsManager: settingsManager)
        
        
        super.init()
        
        mDNSBrowser.delegate = remoteManager
        mDNSListener.delegate = self
        
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
    func publishMDNS(){
        mDNSListener.start()
    }
    
    //
    func stopMDNS(){
        mDNSListener.stop()
        mDNSBrowser.stop()
    }
    
    //
    // MARK: start servers
    func startServers(){
        
        print(DEBUG_TAG+"starting servers...")
        
        // servers need to be stopped before starting
        guard server == nil, registrationServer == nil else {
            print(DEBUG_TAG+"Servers are already running")
            publishMDNS()
            return
        }
        
        // reuse existing eventloop ?? create new one
        serverEventLoopGroup = serverEventLoopGroup ?? GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
        remoteEventLoopGroup = remoteEventLoopGroup ?? GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
        
        // remoteManager is responsible for providing remotes with their eventloop
        remoteManager.remoteEventloopGroup = remoteEventLoopGroup
        
        
        server = Server(eventloopGroup: serverEventLoopGroup!,
                        settingsManager: settingsManager,
                        authenticationManager: authManager,
                        remoteManager: remoteManager,
                        errorDelegate: self)
        
        registrationServer = RegistrationServer(eventloopGroup: remoteEventLoopGroup!,
                                                settingsManager: settingsManager)
        
        //
        // Test server failure
//        let promise = serverEventLoopGroup?.next().makePromise(of: GRPC.Server.self)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            promise?.fail(Server.ServerError.SERVER_FAILURE)
//        }
//
//        promise?.futureResult
        
        server?.start()
        // what to do if server fails to start
            .flatMapError { error in
                self.server = nil
                self.stopMDNS()
                
                return self.serverEventLoopGroup!.next().makeFailedFuture(error)
            }
        
        // return future that completes when registrationServer starts up
            .flatMap { server in
                return self.registrationServer!.start()
            }
        
        // on registrationServer startup completion
            .whenComplete { result in
                
                do {  _ = try result.get()   }
                catch {
                    
                    // error outcome, something failed
                    self.registrationServer = nil
                    self.reportError(error, withMessage: "Server future failed")
                    return
                }
                
                
                // success outcome, continue with starting up
                // TODO: make a way to return a promise that succeeds when the listener/browser are ready
                self.publishMDNS()
            }
        
    }
    
    
    func shutdownConnections() -> EventLoopFuture<Void>? {
            return remoteManager.shutdownAllRemotes()
    }
    
    
    
    //
    // MARK: stop servers
    func stopServers() -> EventLoopFuture<Void>? {
        
        print(DEBUG_TAG+"stopping servers... ")
        
        let remoteFuture = shutdownConnections()
        
        
        remoteFuture?.whenComplete { response in
            
            print(self.DEBUG_TAG+"remotes completed disconnecting: ")
            
            do {
                try response.get()
                print(self.DEBUG_TAG+"remotes finished: ")
            } catch {
                print(self.DEBUG_TAG+"error: \(error)")
            }
        }
        
        guard let server = server,
              let registrationServer = registrationServer else {
                  return remoteFuture
              }
        
        
        
        // I thiink is how you chain futures together
        return remoteFuture?.flatMap {
            print(self.DEBUG_TAG+"stopping registration server")
            return registrationServer.stop()
        }.map {
            print(self.DEBUG_TAG+"deleting registration server")
            self.registrationServer = nil
        }.flatMap {
            print(self.DEBUG_TAG+"stopping server")
            return server.stop()
        }.map {
            print(self.DEBUG_TAG+"deleting server")
            self.server = nil
        }
        
    }
    
    
    //
    // MARK: restart servers
    func restartServers(){
        
        stopMDNS()
        
        let stopFuture = stopServers()
        stopFuture?.whenFailure { error in
            print(self.DEBUG_TAG+"servers failed to stop: \(error)")
        }
        
        // wait until servers have stopped, then start them
        stopFuture?.whenSuccess { _ in
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
    // MARK shutdown
    
//    func shutdownEventLoops(){
//        print(self.DEBUG_TAG+"shutting down eventloop")
//        // TODO: find a way to sync these
//        serverEventLoopGroup?.shutdownGracefully (queue:  .main) { error in
//            print(self.DEBUG_TAG+"Completed serverEventLoopGroup shutdown")
//            self.serverEventLoopGroup = nil
//        }
//
//
//        remoteEventLoopGroup?.shutdownGracefully(queue: .main) { error in
//            print(self.DEBUG_TAG+"Completed remoteEventLoopGroup shutdown")
//            self.remoteEventLoopGroup = nil
//        }
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




// MARK: ErrorDelegate
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



//
// MARK: - MDNSListenerDelegate
extension MainCoordinator: MDNSListenerDelegate {
    func mDNSListenerIsReady() {
        mDNSBrowser.start()
    }
}











//extension MainCoordinator {
//
//    func mockRemote(){
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//
//            for i in 0..<2 {
//
//                var mockDetails = RemoteDetails.MOCK_DETAILS
//                mockDetails.uuid = mockDetails.uuid + "__\(i)\(i+1)"
//
//                let mockRemote = Remote(details: mockDetails)
//
//                self.remoteManager.addRemote(mockRemote)
//            }
//
//        }
//    }
//}
