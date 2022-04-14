//
//  SettingsManager.swift
//  Warpinator
//
//  Created by William Millington on 2022-01-17.
//

import UIKit


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
        case refreshCredentials = "refreshCredentials"
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
    
    var refreshCredentials: Bool = false   {
        didSet { writeToSettings(refreshCredentials, forKey: StorageKey.refreshCredentials)}
    }
    
    // MARK: connection settings
    var hostname: String  = "WarpinatoriOS"  {
        didSet  {   writeToSettings(hostname,   forKey: StorageKey.hostname) } }
    var uuid: String { // generated on first start
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
        
        
        // generate random UUID
        func randomUUID() -> String {
            
            var uuidStr = "WarpinatoriOS"
            
            // stick 5 random digits after "WarpinatoriOS"
            for _ in 0...4 {
                uuidStr += "\(Int.random(in: 0...9))"
            }
            
            return uuidStr
        }
        
        uuid = UserDefaults.standard.string(forKey: StorageKey.uuid.rawValue) ?? randomUUID()
        
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
        refreshCredentials = defaults.bool(forKey: StorageKey.refreshCredentials.rawValue)
        
        hostname = defaults.string(forKey: StorageKey.hostname.rawValue) ?? hostname
        
        
        uuid = defaults.string(forKey: StorageKey.uuid.rawValue)  ?? uuid
        print(DEBUG_TAG+"uuid is \(uuid)")
        
        groupCode = defaults.string(forKey: StorageKey.groupCode.rawValue)  ?? groupCode
        
        
        // defaults.integer returns 0 instead of nil when there's no entry
        let tport = defaults.integer(forKey: StorageKey.transferPortNumber.rawValue)
        transferPortNumber = tport == 0 ? transferPortNumber : UInt32(tport)
        
        let rport = defaults.integer(forKey: StorageKey.registrationPortNumber.rawValue)
        registrationPortNumber = rport == 0 ? registrationPortNumber : UInt32(rport)
        
    }
    
    
    
    //
    // MARK: write setting
    func writeToSettings(_ value: Any?, forKey key: StorageKey) {
        
        UserDefaults.standard.setValue(value, forKey:  key.rawValue   )
    }
    
    
    //
    /* MARK: validate change
     - verifies that the proposed change to setting is acceptable
     (  i.e. port numbers must be non-negative, strings must be non-empty, etc ) */
    static func validate(_ value: Any?, forKey key: StorageKey) throws {
        
        
        // - switch: checks what we're trying to store
        // - guard let: verifies that the value is of the correct type
        // - misc, settings-specific checks
        switch key {
            
            //
            // All UInt32 settings
        case StorageKey.registrationPortNumber, StorageKey.transferPortNumber:
            
            // cast down (up?) from Any
            guard let value = value as? UInt32 else {
                throw ValidationError.INVALID_VALUE_TYPE("(\(key))Invalid value type. Expected UInt32")
            }
            
            /* This will never be triggered, as the previous 'guard' statement
             will catch any non-negative numbers as it attempts to stuff them into a UInt32.
             Including it for clarity. */
            guard value > 0 else {
                throw ValidationError.INVALID_VALUE("(\(key)) Port value must be positive")
            }
            
            
            // Must fit in UInt32
            // 2^31 = 2147483648
            guard value < 2147483648 else {
                throw ValidationError.INVALID_VALUE("(\(key)) port value must be less than 2147483648 because computers")
            }
            
            
             //
             // All String settings
        case StorageKey.displayName, StorageKey.groupCode:
            
            // cast down from Any
            guard let value = value as? String else {
                throw ValidationError.INVALID_VALUE_TYPE("(\(key)) Invalid value type. Expected String")
            }
            
            
            guard value.count > 0 else {
                throw ValidationError.INVALID_VALUE("(\(key)) \(key) required")
            }
            
            
            guard value.count < 100 else {
                throw ValidationError.INVALID_VALUE("(\(key)) Must be under 100 characters")
            }
                    
                    
            
        default: throw ValidationError.INVALID_VALUE_TYPE("(\(key)/\(String(describing: value))) Unexpected Key or Value Type")
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
        defaults.setValue(refreshCredentials, forKey: StorageKey.refreshCredentials.rawValue)
        
        defaults.setValue(hostname, forKey: StorageKey.hostname.rawValue)
        defaults.setValue(uuid, forKey: StorageKey.uuid.rawValue)
        
        defaults.setValue(groupCode, forKey: StorageKey.groupCode.rawValue)
        defaults.setValue(transferPortNumber, forKey: StorageKey.transferPortNumber.rawValue)
        defaults.setValue(registrationPortNumber, forKey: StorageKey.registrationPortNumber.rawValue)
        
    }
    
    
}







// MARK: SettingsChange
struct SettingsChange {
    
    var restartRequired: Bool
    var validate: () throws -> ()
    var change: ()->()
    
    
    init(restart: Bool,
         validate v: @escaping () throws ->() = {},
         change c: @escaping ()->()) {
        restartRequired = restart
        change = c
        validate = v
    }
    
}
