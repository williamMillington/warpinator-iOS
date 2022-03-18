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
    
    
//    var currentSettings: [String: SettingsManager.SettingsType]! {
//        didSet {
//            if settingsChanged {
//
//                let text = restartRequired ? "Restart" : "Apply"
//
//                backButton.setTitle(text, for: .normal)
//                resetButton.alpha = 1.0
//                resetButton.isUserInteractionEnabled = true
//
//            } else {
//                backButton.setTitle("<Back", for: .normal)
//                resetButton.alpha = 0
//                resetButton.isUserInteractionEnabled = false
//            }
//        }
//    }
    
    
    
//    var settingsChanged: Bool {
//        let OGSettings = settingsManager.getSettingsCopy()
//        return currentSettings.map {
//            print("OG: (\($0.key))\(OGSettings[$0.key]!) vs \($0.value)")
//            return OGSettings[$0.key] != $0.value  } // report if they're NOT the same
//            .reduce(false) { result, next in
//                return result || next // returns true if any are true
//            }
//    }
    var restartRequired: Bool  {
        return changes.map { $0.restartRequired }.contains(true)
    }
    var changes: [SettingsChange] = [] {
        didSet {
            
            
            guard changes.count != 0 else {
                
                backButton.setTitle("<Back", for: .normal)
                resetButton.alpha = 0
                resetButton.isUserInteractionEnabled = false
                
                return
            }
            
//            if restartRequired {
                let text = restartRequired ? "Restart" : "Apply"

                backButton.setTitle(text, for: .normal)
                resetButton.alpha = 1.0
                resetButton.isUserInteractionEnabled = true

//            } else {
//                backButton.setTitle("<Back", for: .normal)
//                resetButton.alpha = 0
//                resetButton.isUserInteractionEnabled = false
//            }
        }
    }
    
    
    
    
    init(settingsManager manager: SettingsManager) {
        
        settingsManager = manager
//        currentSettings = settingsManager.getSettingsCopy()
        
        super.init(nibName: "SettingsViewController", bundle: Bundle(for: type(of: self)))
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
    }
    
    
    //  MARK: viewDidload
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Utils.backgroundColour
//        setOriginalSettings()
        implementCurrentSettings()
    }
    
    
//    func setOriginalSettings(){
//
//        if case let .settingsBool(boolval) =  currentSettings[SettingsManager.StorageKeys.automaticAccept] {
//            autoacceptSwitch.isOn = boolval  }
//
//        if case let .settingsBool(boolval) =  currentSettings[SettingsManager.StorageKeys.overwriteFiles] {
//            overwriteSwitch.isOn = boolval  }
//
//    if case let .settingsString(stringVal) =  currentSettings[SettingsManager.StorageKeys.displayName] {
//            displayNameLabel.text = stringVal  }
//
//        if case let .settingsString(stringVal) =  currentSettings[SettingsManager.StorageKeys.groupCode] {
//            groupCodeLabel.text = stringVal  }
//
//        if case let .settingsUInt32(uintval) =  currentSettings[SettingsManager.StorageKeys.transferPortNumber] {
//            transferPortNumberLabel.text = "\(uintval)"  }
//
//        if case let .settingsUInt32(uintval) =  currentSettings[SettingsManager.StorageKeys.registrationPortNumber] {
//            registrationPortNumberLabel.text = "\(uintval)"  }
//
//    }
    
    // MARK: implementCurrentSettings
    func implementCurrentSettings(){
        
        
        displayNameLabel.text = settingsManager.displayName
        groupCodeLabel.text = settingsManager.groupCode
        
        registrationPortNumberLabel.text = "\(settingsManager.registrationPortNumber)"
        transferPortNumberLabel.text = "\(settingsManager.transferPortNumber)"
        
        autoacceptSwitch.isOn = settingsManager.automaticAccept
        overwriteSwitch.isOn = settingsManager.overwriteFiles
        
        
        
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
//            if(trimmedInput.count == 0) {
                
                //restore previous value
//                displayNameLabel.text = trimmedInput
                
//                showPopupError(withTitle: "Error", andMessage: "Display Name Required")
//                return
//            } else if trimmedInput.count > 15 {
                
                //restore previous value
//                groupCodeLabel.text = settingsManager.groupCode
                
//                showPopupError(withTitle: "Error", andMessage: "Group Code needs to be under 15 characters")
//                return
//            }
            
            
            // TODO: sanitize?
            
            
            // write to settings
            // add
//            let settingsChange = SettingsChange({
//                SettingsManager.shared.displayName = trimmedInput
//            })
            
            let change = SettingsChange(restart: true,  validate: {
                try SettingsManager.validate(trimmedInput,
                                             forKey: SettingsManager.StorageKeys.displayName )
            }, change: {
                SettingsManager.shared.displayName = trimmedInput
            })
            
            changes.append(change)
//            restartRequired = true
//            currentSettings[ SettingsManager.StorageKeys.displayName ] =  .settingsString(trimmedInput)
        }
        
        
    }
    
    
    
    
    
    // MARK: group code changed
    @IBAction func groupCodeDidChange(_ sender: UITextField){
        
        // get text
//        if let input = sender.text {
            
        let input = sender.text ?? ""
        
        print(DEBUG_TAG+"new groupcode value is \(input)")
            
            
        // trim whitespace
        let trimmedInput = input.trimmingCharacters(in: [" "])
            
        print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
            
            // if no groupcode value, don't update
//            if(trimmedInput.count == 0) {
//
//                //restore previous value
//        groupCodeLabel.text = trimmedInput
//
//                showPopupError(withTitle: "Error", andMessage: "Group Code Required")
//                return
//            } else if trimmedInput.count > 25 {
//
//                //restore previous value
//                groupCodeLabel.text = settingsManager.groupCode
//
//                showPopupError(withTitle: "Error", andMessage: "Group Code needs to be under 25 characters")
//                return
//            }
            
            
            // TODO: sanitize?
            
            
            // write to settings
            changes.append(SettingsChange(restart: true,  validate: {
                try SettingsManager.validate(trimmedInput,
                                             forKey: SettingsManager.StorageKeys.groupCode )
            }, change:  {
                SettingsManager.shared.groupCode = trimmedInput
            }))
//            settingsManager.groupCode = trimmedInput
//            restartRequired = true
//            currentSettings[SettingsManager.StorageKeys.groupCode ] = .settingsString(trimmedInput)
//        }
        
    }
    
    
    
    
    
    // MARK: transfer port
    @IBAction func transferPortDidChange(_ sender: UITextField){
        
        // get text
//        if let input = sender.text {
            
        
            let input = sender.text ?? ""
            
            print(DEBUG_TAG+"new transfer port value is \(input)")
            
            // trim whitespace
            let trimmedInput = input.trimmingCharacters(in: [" "])
            
            print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
            
            // if no groupcode value, don't update
//            if(trimmedInput.count == 0) {
//
//                //restore previous value
//                transferPortNumberLabel.text = "\(settingsManager.transferPortNumber)"
//
//                showPopupError(withTitle: "Error", andMessage: "Port Number Required")
//                return
//            }
            
            
            // check if number
//            if let newPortNum = UInt32(trimmedInput) {
                
//                print(DEBUG_TAG+"new transfer port num is \(newPortNum)")
                
                
                
                // TODO: sanitize?
        
        let newPortNum = UInt32(trimmedInput)
        print(DEBUG_TAG+"new registration port num is \(String(describing: newPortNum))")
                
        // write to settings
        changes.append(SettingsChange(restart: true,  validate: {
            try SettingsManager.validate(UInt32(trimmedInput),
                                         forKey: SettingsManager.StorageKeys.transferPortNumber )
        }, change: {
            SettingsManager.shared.transferPortNumber = UInt32(trimmedInput)!
        }))
//                settingsManager.transferPortNumber = UInt32(newPortNum)
//                restartRequired = true
//                currentSettings[SettingsManager.StorageKeys.transferPortNumber] = .settingsUInt32( UInt32(newPortNum) )
//
                
//            } else {
//
//                //restore previous value
//                transferPortNumberLabel.text = "\(settingsManager.transferPortNumber)"
//
//                showPopupError(withTitle: "Error", andMessage: "Must be a number")
//                return
//            }
            
//        }
    }
    
    
    
    
    // MARK: registration port
    @IBAction func registrationPortDidChange(_ sender: UITextField) {
        
        // get text
//        if let input = sender.text {
            
        let input = sender.text ?? ""
        
        print(DEBUG_TAG+"new registration port value is \(input)")
            
        // trim whitespace
        let trimmedInput = input.trimmingCharacters(in: [" "])
            
        print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
            
        // if no groupcode value, don't update
//        if(trimmedInput.count == 0) {
//
//                //restore previous value
//            registrationPortNumberLabel.text = "\(settingsManager.registrationPortNumber)"
//
//            showPopupError(withTitle: "Error", andMessage: "Port Number Required")
//                return
//            }
            
        // check if number
        let newPortNum = UInt32(trimmedInput)
        print(DEBUG_TAG+"new registration port num is \(String(describing: newPortNum))")
            
                
        // queue change
        changes.append(SettingsChange(restart: true,  validate: {
            try SettingsManager.validate(newPortNum,
                                         forKey: SettingsManager.StorageKeys.registrationPortNumber )
        }, change:  {
            SettingsManager.shared.registrationPortNumber = newPortNum!
        }))
                
//                settingsManager.registrationPortNumber = UInt32(newPortNum)
//                restartRequired = true
//                currentSettings[SettingsManager.StorageKeys.registrationPortNumber] = .settingsUInt32( UInt32(newPortNum) )
                
                
//            } else {
//
//                //restore previous value
//                registrationPortNumberLabel.text = "\(settingsManager.registrationPortNumber)"
//
//                showPopupError(withTitle: "Error", andMessage: "Must be a number")
//                return
//            }
            
//        }
        
    }
    
    
    
    // MARK: auto-accept changed
    @IBAction func autoAcceptSettingDidChange(_ sender: UISwitch) {
        
        
        // get state
        let switchCheck = sender.isOn
        print(DEBUG_TAG+"incoming transfers \(switchCheck ? "will" : "will NOT") begin automatically (switch is: \(switchCheck ? "ON" : "OFF") )")
        
        // queue change
        changes.append(SettingsChange(restart: true,  validate: {
            try SettingsManager.validate(switchCheck,
                                         forKey: SettingsManager.StorageKeys.automaticAccept )
        }, change:  {
            SettingsManager.shared.automaticAccept = switchCheck
        }))
//        settingsManager.automaticAccept = newValue
//        currentSettings[SettingsManager.StorageKeys.automaticAccept] = .settingsBool(newValue)
        
    }
    
    
    
    // MARK: overwrite changed
    @IBAction func overwriteSettingDidChange(_ sender: UISwitch) {
        
        // get state
        let switchCheck = sender.isOn
        print(DEBUG_TAG+"files will \(switchCheck ? "be" : "NOT be") overwritten (switch is: \(switchCheck ? "ON" : "OFF") )")
        
        // queue change
        changes.append(SettingsChange(restart: true,  validate: {
            try SettingsManager.validate(switchCheck,
                                         forKey: SettingsManager.StorageKeys.overwriteFiles )
        }, change:  {
            SettingsManager.shared.overwriteFiles = switchCheck
        }))
//        settingsManager.overwriteFiles = newValue
//        restartRequired = true
//        currentSettings[SettingsManager.StorageKeys.overwriteFiles] = .settingsBool(newValue)
        
    }
    
    
    
    // MARK: show popup
    @objc func showPopupError(withTitle title: String, andMessage message: String){
        
        
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertVC.addAction(UIAlertAction(title: "Okay", style: .default, handler: { uiAction in
            self.reset()
//            print(self.DEBUG_TAG+"action selected \(uiAction)")
        }))
        
        present(alertVC, animated: true) {
            print(self.DEBUG_TAG+"continuing...")
        }
    }
    
    
    
    
    
    // MARK: reset
    @IBAction func reset(){
//        currentSettings = settingsManager.getSettingsCopy()
//        setOriginalSettings()
        print(self.DEBUG_TAG+"resettings")
        changes = []
        
        implementCurrentSettings()
        
    }
    
    
    // MARK: back
    @IBAction func back(){
        
        
        do {
            try validateChanges()
            
            applyChanges()
            coordinator?.returnFromSettings(restartRequired: restartRequired)
            
        } catch {
            showPopupError(withTitle: "Error", andMessage: error.localizedDescription )
        }
        
        
        
    }
    

}






extension SettingsViewController {
    
    func validateChanges() throws {
        
        try changes.forEach {
            try $0.validate()
        }
        
    }
    
    
    func applyChanges() {
        changes.forEach {
            $0.change()
        }
    }
}



struct SettingsChange {
    
    
    var restartRequired: Bool = true
    var validate: () throws ->()
    var change: ()->()
    
    
    init(restart: Bool,
         validate v: @escaping () throws ->(),
         change c: @escaping ()->()) {
        restartRequired = restart
        change = c
        validate = v
    }
    
}
