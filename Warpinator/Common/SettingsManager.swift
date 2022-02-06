//
//  SettingsManager.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2022-01-17.
//

import UIKit



class SettingsManager {
    
    private let DEBUG_TAG: String = "SettingsManager: "
    
    
    enum SettingsType: Equatable {
//                       , Codable {
        case settingsInt(Int)
        case settingsUInt32(UInt32)
        case settingsString(String)
        case settingsBool(Bool)
        
        
        var dataDictionary: [String: Any] {
            switch self {
            case .settingsInt(let int): return ["settingsInt": int]
            case .settingsUInt32(let uint): return ["settingsUInt32": uint]
            case .settingsString(let string): return  ["settingsString": string]
            case .settingsBool(let boolean): return ["settingsBool": boolean]
            }
        }
        
        
        init?(fromDictionary dictionary: [String: Any]) {
            switch dictionary.keys.first! {
            case "settingsInt": self = .settingsInt(dictionary.values.first as! Int)
            case "settingsUInt32": self = .settingsUInt32(dictionary.values.first as! UInt32)
            case "settingsString": self = .settingsString(dictionary.values.first as! String)
            case "settingsBool": self = .settingsBool(dictionary.values.first as! Bool)
            default: return nil
            }
        }
        
        
        
        
        static func ==(lhs: SettingsType, rhs: SettingsType) -> Bool {
            
            switch (lhs,rhs){
            case (.settingsInt(let num1), .settingsInt(let num2)): return num1 == num2
            case (.settingsUInt32(let num1), .settingsUInt32(let num2)): return num1 == num2
            case (.settingsString(let str1), .settingsString(let str2)): return str1 == str2
            case (.settingsBool(let bool1), .settingsBool(let bool2)): return bool1 == bool2
            case (.settingsInt(_),_),
                 (.settingsUInt32(_),_),
                 (.settingsString(_),_),
                 (.settingsBool(_),_): return false
            }
            
        }
        
        
        //
        //Codable
//        init(from decoder:Decoder) throws {
//
//        }
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
//    let defaultValues: [String : Any] = [ StorageKeys.displayName : "iOS Device",
//                                                   StorageKeys.userName : "iosdevice",
//
//                                                   StorageKeys.overwriteFiles : false,
//                                                   StorageKeys.automaticAccept : false,
//
//                                                   StorageKeys.hostname : "WarpinatoriOS",
//                                                   StorageKeys.uuid : "WarpinatoriOS\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))", // TODO: make gooder
//
//                                                   StorageKeys.groupCode : "Warpinator",
//                                                   StorageKeys.transferPortNumber : 42_000,
//                                                   StorageKeys.registrationPortNumber : 42_001
//    ]
    
    
    // remembered remotes
    var rememberedRemotes : [String : Remote] = [:]
    
    
    // user settings
    var displayName: String = "iOS Device"      {
        didSet { writeToSettings(displayName, forKey: StorageKeys.displayName) } }
    var userName: String = "iosdevice"           {
        didSet { writeToSettings(userName, forKey: StorageKeys.userName) } }
    var avatarImage: UIImage? = nil {
        didSet { writeToSettings(avatarImage, forKey: StorageKeys.avatarImage) } }
    
    
    var overwriteFiles: Bool  = false  {
        didSet { writeToSettings(overwriteFiles, forKey: StorageKeys.overwriteFiles)} }
    var automaticAccept: Bool = false  {
        didSet { writeToSettings(automaticAccept, forKey: StorageKeys.automaticAccept)} }
    
    
    
    // connectionSettings
    var hostname: String  = "WarpinatoriOS" {
        didSet { writeToSettings(hostname, forKey: StorageKeys.hostname) } }
    var uuid: String
//    = "WarpinatoriOS\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))"
    {
        didSet { writeToSettings(uuid, forKey: StorageKeys.uuid) } }
    
    
    var groupCode: String = "Warpinator" {
        didSet { writeToSettings(groupCode, forKey: StorageKeys.groupCode) } }
    
    var transferPortNumber: UInt32  = 42_000 {
        didSet { writeToSettings(transferPortNumber, forKey: StorageKeys.transferPortNumber) } }
    var registrationPortNumber: UInt32 = 42_001{
        didSet { writeToSettings(registrationPortNumber, forKey: StorageKeys.registrationPortNumber) } }
    
    
    // MARK: singleton
    static var shared: SettingsManager = {
        let manager = SettingsManager()
        manager.loadSettings()
//        manager.uuid = manager.uuid
        return manager }()
    
    private init(){
        print(DEBUG_TAG+"creating settings manager...")
        uuid = UserDefaults.standard.string(forKey: StorageKeys.uuid) ?? "WarpinatoriOS\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))\(Int.random(in: 0...9))"
        writeToSettings(uuid, forKey: StorageKeys.uuid)
    }
    
    
    //
    // copy of current settings values
    // MARK: getSettingsCopy
    func getSettingsCopy() -> [String : SettingsType] {
//        print("getting copy")
        return [ StorageKeys.displayName :  .settingsString(displayName),
                 StorageKeys.userName :     .settingsString(userName),
                 
                 StorageKeys.overwriteFiles :  .settingsBool(overwriteFiles),
                 StorageKeys.automaticAccept : .settingsBool(automaticAccept),
                 
                 StorageKeys.hostname : .settingsString(hostname),
                 StorageKeys.uuid :     .settingsString(uuid),
                 
                 StorageKeys.groupCode : .settingsString(groupCode),
                 StorageKeys.transferPortNumber :       .settingsUInt32(transferPortNumber),
                 StorageKeys.registrationPortNumber :   .settingsUInt32(registrationPortNumber)
        ]
    }
    
    
    
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
    
    
    
    func applySettings(){
        
        
        
        
        
    }
    
    
    // MARK: write settings
    func writeToSettings(_ value: Any?, forKey key: String) {
        UserDefaults.standard.setValue(value, forKey: key)
    }
    
    func writeSettings(){
        
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
