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
    
    var remoteManager: RemoteManager = RemoteManager()
    
    var serverEventLoopGroup: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    var remoteEventLoopGroup: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    lazy var server: Server = Server(eventloopGroup: serverEventLoopGroup,
                                remoteManager: remoteManager,
                                errorDelegate: self)
    lazy var registrationServer: RegistrationServer = RegistrationServer(eventloopGroup: remoteEventLoopGroup)
    
    init(withNavigationController controller: UINavigationController){
        navController = controller
        
        navController.setNavigationBarHidden(true, animated: false)

        Utils.lockOrientation(.portrait)
        
        
        mDNSBrowser = MDNSBrowser()
        mDNSListener = MDNSListener()
        
        
        super.init()
        
        mDNSBrowser.delegate = remoteManager
        mDNSListener.delegate = self
        
        remoteManager.remoteEventloopGroup = remoteEventLoopGroup
//        mockRemote()
    }
    
    
    
    
    //
    // MARK: start
    func start() {
        showMainViewController()
    }
    
    
    //
    func startMDNS(){
        mDNSListener.startListening()   //beginAcceptingConnections()
        mDNSBrowser.startBrowsing()
//
//        mDNSBrowser.currentResults.forEach { result in
//
//        }
    }
    
    //
    func stopMDNS(){
//        mDNSListener.stop()
//        mDNSListener.pauseAcceptingConnections()
        mDNSListener.stopListening()
        mDNSBrowser.stopBrowsing()
    }
    
    
    //
    // MARK: start servers
    func startServers(){

        print(DEBUG_TAG+"starting servers...")
        
        guard !server.isRunning else {
            print(DEBUG_TAG+"Server is already running")
            startMDNS()
            return
        }
        
        DispatchQueue.main.async {
            if let vc = self.navController.visibleViewController as? ViewController {
                vc.showLoadingScreen()
            }
        }
        
        
        
        //
        // Test server failure
//        let promise = serverEventLoopGroup.next().makePromise(of: GRPC.Server.self)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            promise.fail(Server.ServerError.SERVER_FAILURE)
//        }
//
//        promise?.futureResult

        server.start()
        // what to do if server fails to start
            .flatMapError { error in
//                self.mDNSListener.pauseAcceptingConnections()
                return self.serverEventLoopGroup.next().makeFailedFuture(error)
            }

        // return future that completes when registrationServer starts up
            .flatMap { server in
                return self.registrationServer.start()
            }

        // on registrationServer startup completion
            .whenComplete { result in

                do {  _ = try result.get()   }
                catch {
//                    self.mDNSListener.pauseAcceptingConnections()
//                    self.mDNSListener.stopListening()
                    self.stopMDNS()
                    // error outcome, something failed
                    self.reportError(error, withMessage: "Server future failed")
                    return
                }


                // success outcome, continue with starting up
                // TODO: make a way to return a promise that succeeds when the listener/browser are ready
//                self.startMDNS()
                self.mDNSListener.flushPublish()
                self.startMDNS()
                DispatchQueue.main.async {
                    (self.navController.visibleViewController as? ViewController)?.removeLoadingScreen()
                }
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
        
        // I thiink is how you chain futures together
        return remoteFuture?.flatMap {
            print(self.DEBUG_TAG+"stopping registration server")
            
            self.stopMDNS()
            
            return self.registrationServer.stop()
        }
        .flatMap {
            print(self.DEBUG_TAG+"stopping server")
            return self.server.stop()
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
        stopFuture?.whenSuccess {
            print(self.DEBUG_TAG+"servers stopped.")
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
            mainMenuVC.settingsManager = SettingsManager.shared
            
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
            
            let settingsVC = SettingsViewController(settingsManager: SettingsManager.shared)
            
            settingsVC.coordinator = self
            
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
        mDNSBrowser.startBrowsing()
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
