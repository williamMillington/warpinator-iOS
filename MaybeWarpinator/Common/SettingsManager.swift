//
//  SettingsManager.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2022-01-17.
//

import UIKit



class SettingsManager {
    
    
    struct StorageKeys {
        
        static let displayName = "displayName"
        static let userName = "userName"
        
        static let avatarImage = "avatarImage"
        
        static let overwriteFiles = "overwriteFiles"
        static let automaticAccept = "automaticAccept"
        
        static let hostname = "hostname"
        static let uuid = "uuid"
        
        static let groupCode = "groupCode"
        static let transferPortNumber = "transferPortNumber"
        static let registrationPortNumber = "registrationPortNumber"
    }
    
    
    // MARK: default values
    let defaultValues: [String : Any] = [ StorageKeys.displayName : "iOS Device",
                                          StorageKeys.userName : "iosdevice",
                                          
                                          StorageKeys.overwriteFiles : false,
                                          StorageKeys.automaticAccept : false,
                                          
                                          StorageKeys.hostname : "WarpinatoriOS",
                                          StorageKeys.uuid : "WarpinatoriOS\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))", // TODO: make gooder
                                          
                                          StorageKeys.groupCode : "Warpinator",
                                          StorageKeys.transferPortNumber : 42_000,
                                          StorageKeys.registrationPortNumber : 42_001
    ]
    
    
    // remembered remotes
    var rememberedRemotes : [String : Remote] = [:]
    
    
    // user settings
    var displayName: String         {   didSet { writeSettings() } }
    var userName: String            {   didSet { writeSettings() } }
    var avatarImage: UIImage? = nil {   didSet { writeSettings() } }
    
    var overwriteFiles: Bool = false    {   didSet { writeSettings() } }
    var automaticAccept: Bool = false   {   didSet { writeSettings() } }
    
    // connectionSettings
    var hostname: String = "WarpinatoriOS"  {   didSet { writeSettings() } }
    var uuid: String = "WarpinatoriOS"      {   didSet { writeSettings() } }
    
    var groupCode: String = "Warpinator"    {   didSet { writeSettings() } }
    
    var transferPortNumber: UInt32 = 42_000     { didSet { writeSettings() } }
    var registrationPortNumber: UInt32 = 42_001 { didSet { writeSettings() } }
    
    
    // MARK: private init
    static let shared = SettingsManager()
    private init(){
        
        let defaults = UserDefaults.standard
        
        defaults.register(defaults: defaultValues)
        
        // load saved defaults
        displayName = defaults.string(forKey: StorageKeys.displayName)!
        userName = defaults.string(forKey: StorageKeys.userName)!
        
        overwriteFiles = defaults.bool(forKey: StorageKeys.overwriteFiles)
        automaticAccept = defaults.bool(forKey: StorageKeys.automaticAccept)
        
        
        hostname = defaults.string(forKey: StorageKeys.hostname) ?? (defaultValues[StorageKeys.hostname] as! String)
        uuid = defaults.string(forKey: StorageKeys.uuid) ?? (defaultValues[StorageKeys.uuid] as! String)
        
        
        groupCode = defaults.string(forKey: StorageKeys.groupCode) ?? (defaultValues[StorageKeys.groupCode] as! String)
        transferPortNumber = UInt32( defaults.integer(forKey: StorageKeys.transferPortNumber) )
        registrationPortNumber = UInt32( defaults.integer(forKey: StorageKeys.registrationPortNumber) )
        
    }
    
    
    
    
    func writeSettings(){
        
        let defaults = UserDefaults.standard
        
        // write to defaults
        defaults.setValue(displayName, forKey: StorageKeys.displayName)
        defaults.setValue(userName, forKey: StorageKeys.userName)
        
        defaults.setValue(overwriteFiles, forKey: StorageKeys.overwriteFiles)
        defaults.setValue(automaticAccept, forKey: StorageKeys.automaticAccept)
        
        defaults.setValue(hostname, forKey: StorageKeys.hostname)
        defaults.setValue(uuid, forKey: StorageKeys.uuid)
        
        defaults.setValue(groupCode, forKey: StorageKeys.groupCode)
        defaults.setValue(transferPortNumber, forKey: StorageKeys.transferPortNumber)
        defaults.setValue(registrationPortNumber, forKey: StorageKeys.registrationPortNumber)
        
    }
    
    
    
    
}
