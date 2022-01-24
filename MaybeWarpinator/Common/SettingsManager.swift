//
//  SettingsManager.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2022-01-17.
//

import UIKit



class SettingsManager {
    
    
    struct keys {
        static let name = "name"
        static let avatarImage = "avatarImage"
        static let overwriteFiles = "overwriteFiles"
        static let automaticAccept = "automaticAccept"
        static let groupCode = "groupCode"
        static let transferPortNumber = "transferPortNumber"
        static let registrationPortNumber = "registrationPortNumber"
    }
    
    
    
    
    // remembered remotes
    var rememberedRemotes : [String : Remote] = [:]
    
    
    // user settings
    var name: String
    var avatarImage: UIImage? = nil
    
    var overwriteFiles: Bool = false {
        didSet { writeSettings() }
    }
    
    var automaticAccept: Bool = false {
        didSet { writeSettings() }
    }
    
    // connectionSettings
    var groupCode: String = "Warpinator" {
        didSet { writeSettings() }
    }
    
    var transferPortNumber: UInt32 = 42_000 {
        didSet { writeSettings() }
    }
    
    var registrationPortNumber: UInt32 = 42_001 {
        didSet { writeSettings() }
    }
    
    static let shared = SettingsManager()
    private init(){
        
        let defaults = UserDefaults.standard
        
        
        let defaultValues: [String : Any] = [ keys.name : "Default Name",
                                              keys.overwriteFiles : false,
                                              keys.automaticAccept : false,
                                              keys.groupCode : "Warpinator",
                                              keys.transferPortNumber : 42_000,
                                              keys.registrationPortNumber : 42_001
        ]
        
        defaults.register(defaults: defaultValues)
        
        // load saved defaults
        name = defaults.string(forKey: keys.name) ?? (defaultValues[keys.name] as! String)
        
        overwriteFiles = defaults.bool(forKey: keys.overwriteFiles)
        automaticAccept = defaults.bool(forKey: keys.automaticAccept)
        
        groupCode = defaults.string(forKey: keys.groupCode) ?? (defaultValues[keys.groupCode] as! String)
        transferPortNumber = UInt32( defaults.integer(forKey: keys.transferPortNumber) )
        
    }
    
    
    
    
    func writeSettings(){
        
        let defaults = UserDefaults.standard
        
        // write to defaults
        defaults.setValue(name, forKey: keys.name)
        defaults.setValue(overwriteFiles, forKey: keys.overwriteFiles)
        defaults.setValue(automaticAccept, forKey: keys.automaticAccept)
        defaults.setValue(groupCode, forKey: keys.groupCode)
        defaults.setValue(transferPortNumber, forKey: keys.transferPortNumber)
        
    }
    
    
    
    
}
