//
//  SettingsViewController.swift
//  Warpinator
//
//  Created by William Millington on 2022-01-18.
//

import UIKit
import Sodium


//TODO: this class


final class SettingsViewController: UIViewController {

    private let DEBUG_TAG: String = "SettingsViewController: "
    
    @IBOutlet var backButton: UIButton!
    @IBOutlet var resetButton: UIButton!
    
    @IBOutlet var displayNameLabel: UITextField!
    @IBOutlet var groupCodeLabel: UITextField!
    @IBOutlet var transferPortNumberLabel: UITextField!
    @IBOutlet var registrationPortNumberLabel: UITextField!
    
    @IBOutlet var overwriteSwitch: UISwitch!
    @IBOutlet var autoacceptSwitch: UISwitch!
    
    
    var coordinator: MainCoordinator?
    var settingsManager: SettingsManager!
    
    var currentSettings: [String: SettingsManager.SettingsType]! {
        didSet {
            if settingsChanged {
                
                let text = restartRequired ? "Restart" : "Apply"
                
                backButton.setTitle(text, for: .normal)
                resetButton.alpha = 1.0
                resetButton.isUserInteractionEnabled = true
                
            } else {
                backButton.setTitle("<Back", for: .normal)
                resetButton.alpha = 0
                resetButton.isUserInteractionEnabled = false
            }
        }
    }
    
    var settingsChanged: Bool {
        let OGSettings = settingsManager.getSettingsCopy()
        return currentSettings.map {
            print("OG: (\($0.key))\(OGSettings[$0.key]!) vs \($0.value)")
            return OGSettings[$0.key] != $0.value  } // report if they're NOT the same
            .reduce(false) { result, next in
                return result || next // returns true if any are true
            }
    }
    var restartRequired: Bool = false
    
    
    
    init(settingsManager manager: SettingsManager) {
        
        settingsManager = manager
        currentSettings = settingsManager.getSettingsCopy()
        
        super.init(nibName: "SettingsViewController", bundle: Bundle(for: type(of: self)))
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Utils.backgroundColour
        setOriginalSettings()
    }
    
    
    func setOriginalSettings(){
        
        if case let .settingsBool(boolval) =  currentSettings[SettingsManager.StorageKeys.automaticAccept] {
            autoacceptSwitch.isOn = boolval  }
        
        if case let .settingsBool(boolval) =  currentSettings[SettingsManager.StorageKeys.overwriteFiles] {
            overwriteSwitch.isOn = boolval  }
        
        if case let .settingsString(stringVal) =  currentSettings[SettingsManager.StorageKeys.overwriteFiles] {
            displayNameLabel.text = stringVal  }
        
        if case let .settingsString(stringVal) =  currentSettings[SettingsManager.StorageKeys.groupCode] {
            groupCodeLabel.text = stringVal  }
        
        if case let .settingsUInt32(uintval) =  currentSettings[SettingsManager.StorageKeys.transferPortNumber] {
            transferPortNumberLabel.text = "\(uintval)"  }
        
        if case let .settingsUInt32(uintval) =  currentSettings[SettingsManager.StorageKeys.registrationPortNumber] {
            registrationPortNumberLabel.text = "\(uintval)"  }
        
    }
    
    
    // MARK: display name changed
    @IBAction func displayNameDidChange(_ sender: UITextField){
        
        // get text
        if let input = sender.text {
            print(DEBUG_TAG+"new DisplayName value is \(input)")
            
            // trim whitespace
            let trimmedInput = input.trimmingCharacters(in: [" "])
            
            print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
            
            // if no groupcode value, don't update
            if(trimmedInput.count == 0) {
                
                //restore previous value
                displayNameLabel.text = settingsManager.displayName
                
                showPopupError(withTitle: "Error", andMessage: "Display Name Required")
                return
            } else if trimmedInput.count > 15 {
                
                //restore previous value
                groupCodeLabel.text = settingsManager.groupCode
                
                showPopupError(withTitle: "Error", andMessage: "Group Code needs to be under 15 characters")
                return
            }
            
            
            // TODO: sanitize?
            
            
            // write to settings
            restartRequired = true
            currentSettings[ SettingsManager.StorageKeys.displayName ] =  .settingsString(trimmedInput)
        }
        
        
    }
    
    
    
    
    
    // MARK: group code changed
    @IBAction func groupCodeDidChange(_ sender: UITextField){
        
        // get text
        if let input = sender.text {
            print(DEBUG_TAG+"new groupcode value is \(input)")
            
            
            // trim whitespace
            let trimmedInput = input.trimmingCharacters(in: [" "])
            
            print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
            
            // if no groupcode value, don't update
            if(trimmedInput.count == 0) {
                
                //restore previous value
                groupCodeLabel.text = settingsManager.groupCode
                
                showPopupError(withTitle: "Error", andMessage: "Group Code Required")
                return
            } else if trimmedInput.count > 25 {
                
                //restore previous value
                groupCodeLabel.text = settingsManager.groupCode
                
                showPopupError(withTitle: "Error", andMessage: "Group Code needs to be under 25 characters")
                return
            }
            
            
            // TODO: sanitize?
            
            
            // write to settings
//            settingsManager.groupCode = trimmedInput
            restartRequired = true
            currentSettings[SettingsManager.StorageKeys.groupCode ] = .settingsString(trimmedInput)
        }
        
    }
    
    
    
    
    
    // MARK: transfer port
    @IBAction func transferPortDidChange(_ sender: UITextField){
        
        // get text
        if let input = sender.text {
            print(DEBUG_TAG+"new transfer port value is \(input)")
            
            // trim whitespace
            let trimmedInput = input.trimmingCharacters(in: [" "])
            
            print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
            
            // if no groupcode value, don't update
            if(trimmedInput.count == 0) {
                
                //restore previous value
                transferPortNumberLabel.text = "\(settingsManager.transferPortNumber)"
                
                showPopupError(withTitle: "Error", andMessage: "Port Number Required")
                return
            }
            
            
            // check if number
            if let newPortNum = Int(trimmedInput) {
                
                print(DEBUG_TAG+"new transfer port num is \(newPortNum)")
                
                
                
                // TODO: sanitize?
                // possibly prevent taking over system ports or something...? If that's a thing
                // oooo make sure it fits in a UInt32
                
                
                // write to settings
//                settingsManager.transferPortNumber = UInt32(newPortNum)
                restartRequired = true
                currentSettings[SettingsManager.StorageKeys.transferPortNumber] = .settingsUInt32( UInt32(newPortNum) )
                
                
            } else {
                
                //restore previous value
                transferPortNumberLabel.text = "\(settingsManager.transferPortNumber)"
                
                showPopupError(withTitle: "Error", andMessage: "Must be a number")
                return
            }
            
        }
    }
    
    
    
    
    // MARK: registration port
    @IBAction func registrationPortDidChange(_ sender: UITextField){
        
        // get text
        if let input = sender.text {
            print(DEBUG_TAG+"new registration port value is \(input)")
            
            // trim whitespace
            let trimmedInput = input.trimmingCharacters(in: [" "])
            
            print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
            
            // if no groupcode value, don't update
            if(trimmedInput.count == 0) {
                
                //restore previous value
                registrationPortNumberLabel.text = "\(settingsManager.registrationPortNumber)"
                
                showPopupError(withTitle: "Error", andMessage: "Port Number Required")
                return
            }
            
            // check if number
            if let newPortNum = Int(trimmedInput) {
                
                print(DEBUG_TAG+"new registration port num is \(newPortNum)")
                
                
                
                // TODO: sanitize?
                //  make sure it fits in a UInt32
                
                
                // write to settings
//                settingsManager.registrationPortNumber = UInt32(newPortNum)
                restartRequired = true
                currentSettings[SettingsManager.StorageKeys.registrationPortNumber] = .settingsUInt32( UInt32(newPortNum) )
                
                
            } else {
                
                //restore previous value
                registrationPortNumberLabel.text = "\(settingsManager.registrationPortNumber)"
                
                showPopupError(withTitle: "Error", andMessage: "Must be a number")
                return
            }
            
        }
        
    }
    
    
    
    // MARK: auto-accept changed
    @IBAction func autoAcceptSettingDidChange(_ sender: UISwitch) {
        
        
        // get state
        let newValue = sender.isOn
        print(DEBUG_TAG+" autoaccept switch is on: \(newValue)")
        
        // write to settings
//        settingsManager.automaticAccept = newValue
        currentSettings[SettingsManager.StorageKeys.automaticAccept] = .settingsBool(newValue)
        
    }
    
    
    
    // MARK: overwrite changed
    @IBAction func overwriteSettingDidChange(_ sender: UISwitch) {
        
        // get state
        let newValue = sender.isOn
        print(DEBUG_TAG+"overwrite switch is on: \(newValue)")
        
        // write to settings
//        settingsManager.overwriteFiles = newValue
        restartRequired = true
        currentSettings[SettingsManager.StorageKeys.overwriteFiles] = .settingsBool(newValue)
        
    }
    
    
    
    // MARK: show popup
    @objc func showPopupError(withTitle title: String, andMessage message: String){
        
        
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertVC.addAction(UIAlertAction(title: "Continue", style: .default, handler: { uiAction in
            print(self.DEBUG_TAG+"action selected \(uiAction)")
        }))
        
        
        present(alertVC, animated: true) {
            print(self.DEBUG_TAG+"continuing...")
        }
    }
    
    
    // MARK: reset
    @IBAction func reset(){
        currentSettings = settingsManager.getSettingsCopy()
        setOriginalSettings()
    }
    
    
    // MARK: back
    @IBAction func back(){
        
        coordinator?.returnFromSettings(restartRequired: restartRequired)
    }
    

}
