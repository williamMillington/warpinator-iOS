//
//  AppDelegate.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-09-30.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return self.orientationLock
    }
    
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    
    
    
    
    
    // TODO:
    func applicationWillResignActive(_ application: UIApplication) {
        // About to enter inactive, do some saving
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // just started back up from background, do some updating
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // just entered background, do some stuff?
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // coming back from background; would I update here, or applicationDidBecomeActive?
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // about to quit. do some saving.
    }
    
}

