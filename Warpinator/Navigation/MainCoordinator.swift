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
    
    
    
    var serverEventLoopGroup: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1,
                                                                                       networkPreference: .best)
    var remoteEventLoopGroup: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1,
                                                                                       networkPreference: .best)
    
    
    lazy var networkMonitor: NetworkMonitor = NetworkMonitor(withEventloopGroup: serverEventLoopGroup,
                                                             delegate: self)
    
    lazy var remoteManager: RemoteManager = RemoteManager(withEventloopGroup: remoteEventLoopGroup)
    
    lazy var warpinatorServiceProvider: WarpinatorServiceProvider = {
        let provider = WarpinatorServiceProvider()
        provider.remoteManager = remoteManager
        return provider
    }()
    
    
    lazy var server: Server = Server(eventloopGroup: serverEventLoopGroup,
                                     provider: warpinatorServiceProvider)
    lazy var registrationServer: RegistrationServer = RegistrationServer(eventloopGroup: remoteEventLoopGroup)
    
    
    
    lazy var mDNSBrowser:   MDNSBrowser  = MDNSBrowser(withEventloopGroup: serverEventLoopGroup)
    lazy var mDNSListener:  MDNSListener = MDNSListener(withEventloopGroup: serverEventLoopGroup)
    
    
    init(withNavigationController controller: UINavigationController){
        navController = controller
        
        navController.setNavigationBarHidden(true, animated: false)

        Utils.lockOrientation(.portrait)
        
        
        super.init()
        
        mDNSBrowser.delegate = remoteManager
        mDNSListener.delegate = self
        
//        mockRemote()
    }
    
    
    
    
    //
    // MARK: start
    func start() {
        
        showMainViewController()
        
    }
    
    
    //
    // MARK: waitForNetwork
    func waitForNetwork() -> EventLoopFuture<Void> {
        
        return networkMonitor.waitForWifiAvailable()
            .flatMap {
                self.networkMonitor.waitForMDNSPermission()
            }
    }
    
    
    
    //
    // MARK: startupMdns
    func startupMdns() -> EventLoopFuture<Void> {
        let futures = [ mDNSListener.start(), mDNSBrowser.start() ]
        return EventLoopFuture.andAllComplete( futures, on: serverEventLoopGroup.next() )
    }
    
    
    //
    // MARK: shutdownMdns
    func shutdownMdns() -> EventLoopFuture<Void> {
        let futures = [ mDNSListener.stop(), mDNSBrowser.stop() ]
        return EventLoopFuture.andAllComplete( futures, on: serverEventLoopGroup.next() )
    }
    
    
    
    //
    // MARK: publishMdns
    func publishMdns(){
        print(DEBUG_TAG+"publishing mDNS...")
        mDNSListener.startListening()
        mDNSListener.flushPublish()
        mDNSBrowser.startBrowsing()
    }
    
    
    
    //
    // MARK: removeMdns
    func removeMdns(){
        print(DEBUG_TAG+"removing mDNS...")
        mDNSListener.removeService()
        mDNSListener.stopListening()
        mDNSBrowser.stopBrowsing()
    }
    
    
    
    
    //
    // MARK: start servers
    func startServers() -> EventLoopFuture<Void> {

        print(DEBUG_TAG+"starting servers...")
        
        DispatchQueue.main.async {
            (self.navController.visibleViewController as? MainViewController)?.removeErrorScreen()
        }
        
        
        guard !server.isRunning else {
            print(DEBUG_TAG+"Server is already running")
            return serverEventLoopGroup.next().makeSucceededVoidFuture()
        }
        
        
        DispatchQueue.main.async {
            (self.navController.visibleViewController as? MainViewController)?.showLoadingScreen()
        }
        
        
        //
        if SettingsManager.shared.refreshCredentials {
            print(DEBUG_TAG+"\t\t refreshing credentials...")
            Authenticator.shared.deleteCredentials()
        }
        
        
        
        //
        // Test server failure
//        let promise = serverEventLoopGroup.next().makePromise(of: GRPC.Server.self)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            promise.fail(Server.ServerError.SERVER_FAILURE)
//        }
//
//        return promise?.futureResult
        
        // start server
        return server.start()
            .flatMap {  // then -> start registrationServer
                return self.registrationServer.start()
            }
            .map { _ in // when complete -> remove loading screen
                DispatchQueue.main.async {
                    (self.navController.visibleViewController as? MainViewController)?.removeLoadingScreen()
                }
            }
    }
    
    
    //
    // MARK: stop servers
    func stopServers() -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+"stopping servers... ")
        
        removeMdns()
        
        return remoteManager.shutdownAllRemotes()
            .flatMap { _ -> EventLoopFuture<Void> in // when remotes have finished shutting down -> shutdown servers
            print(self.DEBUG_TAG+"stopping registration server")
            return self.registrationServer.stop() // registrationServer first, to stop accepting new connections
        }
        .flatMap {
            print(self.DEBUG_TAG+"stopping server")
            return self.server.stop() // main server second
        }
    }
    
    
    //
    // MARK: restart servers
    func restartServers(){
        
        DispatchQueue.main.async {
            (self.navController.visibleViewController as? MainViewController)?.showLoadingScreen()
        }
        
        // unregister ourselves from mDNS
        removeMdns()
        
        // shutdown mDNS
        shutdownMdns()
        // then -> shutdown servers
            .flatMap { _ in
                return self.stopServers()
            }
        // then -> check network connection
            .flatMap{ Void in
                return self.waitForNetwork()
            }
        // then -> start up  servers
            .flatMap { _ in
                return self.startServers()
            }
        // then -> start up mDNS again
            .flatMap { _ in
                return self.startupMdns()
            }
            .whenComplete { result in
                
                print(self.DEBUG_TAG+" restart result is \(result)")
                
                switch result {
                case .success(_): break
                case .failure(let error):
                    
                    switch error {
                    
                    case NetworkMonitor.ServiceError.LOCAL_NETWORK_PERMISSION_DENIED:
                        print(self.DEBUG_TAG+"We DO NOT have access to the local network!")
                        self.reportError(error,
                                         withMessage: "Please enable local network access in your system settings (Settings App -> Privacy -> Local Network)")
                    case Server.ServerError.NO_INTERNET:
                        self.reportError(error,
                                         withMessage: "Please make sure wifi is turned on before restarting")
                        
                    default:
                        print(self.DEBUG_TAG+"Warpinator encountered an error starting up: \(error)")
                        self.reportError(error,
                                         withMessage: "Warpinator encountered an error starting up:\n\(error)")
                        return
                    }
                }
                
                self.publishMdns()
            }
    }
    
    
    // MARK: main viewcontroller
    func showMainViewController(){
        
        // if the previously exists in the stack, rewind
        if let mainMenuVC = navController.viewControllers.first(where: { controller in
            return controller is MainViewController
        }) {
            navController.popToViewController(mainMenuVC, animated: false)
        } else {
            
            let bundle = Bundle(for: type(of: self))
            let mainMenuVC = MainViewController(nibName: "MainViewController", bundle: bundle)
            
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
            if let vc = self.navController.visibleViewController as? MainViewController {
                vc.showErrorScreen(error, withMessage: message)
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




extension MainCoordinator: NetworkDelegate {
    
    
    //
    //
    func didLoseLocalNetworkConnectivity() {
        print(self.DEBUG_TAG+" lost wifi connectivity")
        
        
        DispatchQueue.main.async {
            // cast .visibleVC as? MainVC, anything else and .updateInfo() fizzles
            (self.navController.visibleViewController as? MainViewController)?.updateInfo()
        }
    }
    
    
    //
    //
    func didGainLocalNetworkConnectivity() {
        print(self.DEBUG_TAG+" gained wifi connectivity")
        
        DispatchQueue.main.async {
            // cast .visibleVC as? MainVC, anything else and .updateInfo() fizzles
            (self.navController.visibleViewController as? MainViewController)?.updateInfo()
        }
    }
}
