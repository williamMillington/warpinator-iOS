//
//  SettingsManager.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2022-01-17.
//

import UIKit



class SettingsManager {
    
    
    enum SettingsType: Equatable {
        case Int(Int)
        case UInt32(UInt32)
        case String(String)
        case Bool(Bool)
        static func ==(lhs: SettingsType, rhs:SettingsType) -> Bool {
            
            switch (lhs,rhs){
            case (.Int(let num1), .Int(let num2)): return num1 == num2
            case (.UInt32(let num1), .UInt32(let num2)): return num1 == num2
            case (.String(let str1), .String(let str2)): return str1 == str2
            case (.Bool(let bool1), .Bool(let bool2)): return bool1 == bool2
            case (.Int(_),_),
                 (.UInt32(_),_),
                 (.String(_),_),
                 (.Bool(_),_): return false
            }
            
        }
    }
    
    
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
    let defaultValues: [String : SettingsType] = [ StorageKeys.displayName : .String("iOS Device"),
                                                   StorageKeys.userName : .String("iosdevice"),
                                          
                                                   StorageKeys.overwriteFiles : .Bool(false),
                                                   StorageKeys.automaticAccept : .Bool(false),
                                          
                                                   StorageKeys.hostname : .String("WarpinatoriOS"),
                                                   StorageKeys.uuid : .String("WarpinatoriOS\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))"), // TODO: make gooder
                                          
                                                   StorageKeys.groupCode : .String("Warpinator"),
                                                   StorageKeys.transferPortNumber : .Int(42_000),
                                                   StorageKeys.registrationPortNumber : .Int(42_001)
    ]
    
    
    // remembered remotes
    var rememberedRemotes : [String : Remote] = [:]
    
    
    // user settings
    var displayName: String       {   didSet { writeSettings() } }
    var userName: String            {   didSet { writeSettings() } }
    var avatarImage: UIImage? = nil {   didSet { writeSettings() } }
    
    var overwriteFiles: Bool    {   didSet { writeSettings() } }
    var automaticAccept: Bool   {   didSet { writeSettings() } }
    
    // connectionSettings
    var hostname: String  {   didSet { writeSettings() } }
    var uuid: String      {   didSet { writeSettings() } }
    
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
        
        
        hostname = defaults.string(forKey: StorageKeys.hostname)!
        uuid = defaults.string(forKey: StorageKeys.uuid)!
        
        
        groupCode = defaults.string(forKey: StorageKeys.groupCode)!
        transferPortNumber = UInt32( defaults.integer(forKey: StorageKeys.transferPortNumber) )
        registrationPortNumber = UInt32( defaults.integer(forKey: StorageKeys.registrationPortNumber) )
        
        // uuid is generated on first opening, so write settings here to
        // make sure we're not creating a brand new uuid every time
        // (won't be remembered by remotes)
        writeSettings()
    }
    
    
    
    
    //
    // copy of current settings values
    // MARK: getSettingsCopy
    func getSettingsCopy() -> [String : SettingsType] {
        
        return [ StorageKeys.displayName : .String(displayName),
                 StorageKeys.userName : .String(userName),
                 
                 StorageKeys.overwriteFiles : .Bool(overwriteFiles),
                 StorageKeys.automaticAccept : .Bool(automaticAccept),
                 
                 StorageKeys.hostname : .String(hostname),
                 StorageKeys.uuid : .String(uuid), // TODO: make gooder
                 
                 StorageKeys.groupCode : .String(groupCode),
                 StorageKeys.transferPortNumber : .UInt32(transferPortNumber),
                 StorageKeys.registrationPortNumber : .UInt32(registrationPortNumber)
        ]
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
    
    
//    func settings
    
    
}
