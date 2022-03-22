//
//  SettingsManager.swift
//  Warpinator
//
//  Created by William Millington on 2022-01-17.
//

import UIKit
//import CNIOBoringSSL



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
    
    
    enum StorageKey: String {
        case displayName = "displayName"
        case userName = "userName"
        case avatarImage = "avatarImage"
        case overwriteFiles = "overwriteFiles"
        case automaticAccept = "automaticAccept"
        case hostname = "hostname"
        case uuid = "uuid"
        case groupCode = "groupCode"
        case transferPortNumber = "transferPortNumber"
        case registrationPortNumber = "registrationPortNumber"
    }
    
    // remembered remotes
    var rememberedRemotes : [String : Remote] = [:]
    
    
    // MARK: user settings
    var displayName: String = "iOS Device"  {
        didSet { writeToSettings(displayName, forKey: StorageKey.displayName) }
    }
    
    var userName: String = "iosdevice"  {
        didSet { writeToSettings(userName, forKey: StorageKey.userName) }
    }
    
    var avatarImage: UIImage? = nil     {
        didSet { writeToSettings(avatarImage, forKey: StorageKey.avatarImage) }
    }
    
    
    var overwriteFiles: Bool  = false   {
        didSet { writeToSettings(overwriteFiles, forKey: StorageKey.overwriteFiles)}
    }
    
    var automaticAccept: Bool = false   {
        didSet { writeToSettings(automaticAccept, forKey: StorageKey.automaticAccept)}
    }
    
    
    
    // MARK: connection settings
    var hostname: String  = "WarpinatoriOS"  {
        didSet  {   writeToSettings(hostname,   forKey: StorageKey.hostname) } }
    var uuid: String {
        didSet  {   writeToSettings(uuid,       forKey: StorageKey.uuid) } }
    
    
    var groupCode: String = "Warpinator"  {
        didSet {    writeToSettings(groupCode,     forKey: StorageKey.groupCode) } }
    
    var transferPortNumber: UInt32  = 42_000  {
        didSet {    writeToSettings(transferPortNumber,     forKey: StorageKey.transferPortNumber) } }
    var registrationPortNumber: UInt32 = 42_001  {
        didSet {    writeToSettings(registrationPortNumber, forKey: StorageKey.registrationPortNumber) } }
    
    
    //
    // MARK: singleton init
    static var shared: SettingsManager = {
        let manager = SettingsManager()
        manager.loadSettings()
        return manager }()
    
    private init(){
        print(DEBUG_TAG+"creating settings manager...")
        uuid = UserDefaults.standard.string(forKey: StorageKey.uuid.rawValue) ?? "WarpinatoriOS\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))"
        writeToSettings(uuid, forKey: StorageKey.uuid)
    }
    
    
    
    //
    // MARK: loadSettings
    func loadSettings(){
        
        let defaults = UserDefaults.standard
        
        displayName = defaults.string(forKey: StorageKey.displayName.rawValue) ?? displayName
        userName = defaults.string(forKey: StorageKey.userName.rawValue) ?? userName
        
        
        overwriteFiles = defaults.bool(forKey: StorageKey.overwriteFiles.rawValue) // default to false
        automaticAccept = defaults.bool(forKey: StorageKey.automaticAccept.rawValue)
        
        hostname = defaults.string(forKey: StorageKey.hostname.rawValue) ?? hostname
        uuid = defaults.string(forKey: StorageKey.uuid.rawValue)  ?? uuid
        
        groupCode = defaults.string(forKey: StorageKey.groupCode.rawValue)  ?? groupCode
        
        
        transferPortNumber = UInt32(defaults.integer(forKey: StorageKey.transferPortNumber.rawValue))
        registrationPortNumber = UInt32(defaults.integer(forKey: StorageKey.registrationPortNumber.rawValue))
        
    }
    
    
    
    //
    // MARK: write setting
    func writeToSettings(_ value: Any?, forKey key: StorageKey) {
        
        UserDefaults.standard.setValue(value, forKey:
                                        key.rawValue)
        
    }
    
    
    //
    /* MARK: validate change
     - verifies that the proposed change is acceptable
     (  ex. port numbers must be non-negative, strings must be non-empty ) */
    static func validate(_ value: Any?, forKey key: StorageKey) throws {
        
        
        // switch: check what we're trying to store
        // guard let: verify that the value is of the correct type
        switch key {
        case StorageKey.registrationPortNumber, StorageKey.transferPortNumber:
            
            guard let value = value as? UInt32 else {
                throw ValidationError.INVALID_VALUE_TYPE("(\(key))Invalid value type. Expected UInt32")
            }
            
            // I suppose it's a bug that this will never be triggered, as the previous 'guard' statement
            // will catch any non-negative numbers as it attempts to stuff them into a UInt32
            // port must be positive. Including it for clarity.
            if !(value > 0) {
                throw ValidationError.INVALID_VALUE("(\(key))Port value must be positive")
            }
            
            
            
            
        case StorageKey.overwriteFiles, StorageKey.automaticAccept:
            guard (value as? Bool) != nil else {
                throw ValidationError.INVALID_VALUE_TYPE("(\(key))Invalid value type. Expected Bool")
            }
            
            
        case StorageKey.displayName, StorageKey.groupCode:
            guard let value = value as? String else {
                throw ValidationError.INVALID_VALUE_TYPE("(\(key))Invalid value type. Expected String")
            }
            
            
            if !(value.count > 0) {
                throw ValidationError.INVALID_VALUE("(\(key)) \(key) required")
            }
            
            
        default: throw ValidationError.INVALID_VALUE_TYPE("(\(key))Value Type Unexpected")
        }
        
        
    }
    
    
    
    func writeAllSettings(){
        
        let defaults = UserDefaults.standard
        
        print(DEBUG_TAG+" writing settings...")
        
        // write to defaults
        defaults.setValue(displayName, forKey: StorageKey.displayName.rawValue)
        defaults.setValue(userName, forKey: StorageKey.userName.rawValue)
        
        defaults.setValue(overwriteFiles, forKey: StorageKey.overwriteFiles.rawValue)
        defaults.setValue(automaticAccept, forKey: StorageKey.automaticAccept.rawValue)
        
        defaults.setValue(hostname, forKey: StorageKey.hostname.rawValue)
        defaults.setValue(uuid, forKey: StorageKey.uuid.rawValue)
        
        defaults.setValue(groupCode, forKey: StorageKey.groupCode.rawValue)
        defaults.setValue(transferPortNumber, forKey: StorageKey.transferPortNumber.rawValue)
        defaults.setValue(registrationPortNumber, forKey: StorageKey.registrationPortNumber.rawValue)
        
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
