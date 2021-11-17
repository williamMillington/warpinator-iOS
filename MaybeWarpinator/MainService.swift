//
//  MainService.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-06.
//

import Foundation



class MainService {
    
    
    public static var shared: MainService!
    
    var server: Server = Server()
    var registrationServer = RegistrationServer()
    
    var remoteManager: RemoteManager = RemoteManager()
    
    
    init(){
        
        MainService.shared = self
        
    }
    
    func start(){

        server.start()
        server.remoteManager = remoteManager
        
        registrationServer.start()
        registrationServer.remoteManager = remoteManager
        
        
    }
    
    
    
    
    
}
