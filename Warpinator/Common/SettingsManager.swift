//
//  SettingsManager.swift
//  Warpinator
//
//  Created by William Millington on 2022-01-17.
//

import UIKit
import CNIOBoringSSL



// MARK: - ValidationError
enum ValidationError: Error {
    case VALUE_UNCHANGED
    case INVALID_VALUE(String)
    case INVALID_VALUE_TYPE(String)
    
    var localizedDescription: String {
        switch self {
        case .VALUE_UNCHANGED: return "No difference between entered value and recorded value"
        case .INVALID_VALUE(let description): return description
        case .INVALID_VALUE_TYPE(let description): return description
        }
    }
}



// MARK: - SettingsManager
class SettingsManager {
    
    private let DEBUG_TAG: String = "SettingsManager: "
    
    
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
     
    
    // remembered remotes
    var rememberedRemotes : [String : Remote] = [:]
    
    
    // MARK: user settings
    var displayName: String = "iOS Device"  {
        didSet { writeToSettings(displayName, forKey: StorageKeys.displayName) }
    }
    
    var userName: String = "iosdevice"  {
        didSet { writeToSettings(userName, forKey: StorageKeys.userName) }
    }
    
    var avatarImage: UIImage? = nil     {
        didSet { writeToSettings(avatarImage, forKey: StorageKeys.avatarImage) }
    }
    
    
    var overwriteFiles: Bool  = false   {
        didSet { writeToSettings(overwriteFiles, forKey: StorageKeys.overwriteFiles)}
    }
    
    var automaticAccept: Bool = false   {
        didSet { writeToSettings(automaticAccept, forKey: StorageKeys.automaticAccept)}
    }
    
    
    
    // MARK: connection settings
    var hostname: String  = "WarpinatoriOS"  {
        didSet  {   writeToSettings(hostname,   forKey: StorageKeys.hostname) } }
    var uuid: String {
        didSet  {   writeToSettings(uuid,       forKey: StorageKeys.uuid) } }
    
    
    var groupCode: String = "Warpinator"  {
        didSet {    writeToSettings(groupCode,     forKey: StorageKeys.groupCode) } }
    
    var transferPortNumber: UInt32  = 42_000  {
        didSet {    writeToSettings(transferPortNumber,     forKey: StorageKeys.transferPortNumber) } }
    var registrationPortNumber: UInt32 = 42_001  {
        didSet {    writeToSettings(registrationPortNumber, forKey: StorageKeys.registrationPortNumber) } }
    
    
    //
    // MARK: singleton init
    static var shared: SettingsManager = {
        let manager = SettingsManager()
        manager.loadSettings()
        return manager }()
    
    private init(){
        print(DEBUG_TAG+"creating settings manager...")
        uuid = UserDefaults.standard.string(forKey: StorageKeys.uuid) ?? "WarpinatoriOS\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))"
        writeToSettings(uuid, forKey: StorageKeys.uuid)
    }
    
    
    
    //
    // MARK: loadSettings
    func loadSettings(){
        
        let defaults = UserDefaults.standard
        
        if let value = defaults.string(forKey: StorageKeys.displayName) {
            displayName = value }
        
        if let value = defaults.string(forKey: StorageKeys.userName) {
            userName = value }
        
        
        overwriteFiles = defaults.bool(forKey: StorageKeys.overwriteFiles) // default to false
        automaticAccept = defaults.bool(forKey: StorageKeys.automaticAccept)
        

        if let value = defaults.string(forKey: StorageKeys.hostname) {
            hostname = value }
        
        if let value = defaults.string(forKey: StorageKeys.uuid) {
            uuid = value }
        
        
        if let value = defaults.string(forKey: StorageKeys.groupCode) {
            groupCode = value }
        
        var num = defaults.integer(forKey: StorageKeys.transferPortNumber)
        if num != 0 {
            transferPortNumber = UInt32(num)  }
        
        num = defaults.integer(forKey: StorageKeys.registrationPortNumber)
        if num != 0 {
            registrationPortNumber = UInt32(num)  }
        
    }
    
    
    
    //
    // MARK: write setting
    func writeToSettings(_ value: Any?, forKey key: String) {
        
        UserDefaults.standard.setValue(value, forKey: key)
        
    }
    
    
    //
    /* MARK: validate change
     - verifies that the proposed change is acceptable
     (  ex. port numbers must be non-negative, strings must be non-empty ) */
    static func validate(_ value: Any?, forKey key: String) throws {
        
        
        // switch: check what we're trying to store
        // guard let: verify that the value is of the correct type
        switch key {
        case StorageKeys.registrationPortNumber, StorageKeys.transferPortNumber:
            
            guard let value = value as? UInt32 else {
                throw ValidationError.INVALID_VALUE_TYPE("Invalid value type. Expected UInt32")
            }
            
            // I suppose it's a bug that this will never be triggered, as the previous 'guard' statement
            // will catch any non-negative numbers as it attempts to stuff them into a UInt32
            // port must be positive
            if !(value > 0) {
                throw ValidationError.INVALID_VALUE("Port value must be positive")
            }
            
            
            
            
        case StorageKeys.overwriteFiles, StorageKeys.automaticAccept:
            guard (value as? Bool) != nil else {
                throw ValidationError.INVALID_VALUE_TYPE("Invalid value type. Expected Bool")
            }
            
            
        case StorageKeys.displayName, StorageKeys.groupCode:
            guard let value = value as? String else {
                throw ValidationError.INVALID_VALUE_TYPE("Invalid value type. Expected String")
            }
            
            
            if !(value.count > 0) {
                throw ValidationError.INVALID_VALUE("\(key) required")
            }
            
            
        default: throw ValidationError.INVALID_VALUE_TYPE("Value Type Unexpected")
        }
        
        
    }
    
    
    
    func writeAllSettings(){
        
        let defaults = UserDefaults.standard
        
        print(DEBUG_TAG+" writing settings...")
        
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







// MARK: SettingsChange
struct SettingsChange {
    
    var restartRequired: Bool = true
    var validate: () throws -> ()
    var change: ()->()
    
    
    init(restart: Bool,
         validate v: @escaping () throws ->(),
         change c: @escaping ()->()) {
        restartRequired = restart
        change = c
        validate = v
    }
    
}
