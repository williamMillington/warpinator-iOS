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
    
    
    var restartRequired: Bool  {
        return changes.values.map { $0.restartRequired }.contains(true)
    }
    
    var changes: [String: SettingsChange] = [:] { // [SettingsManager.StorageKeys : SettingsChange]
        didSet {
            
            
            guard changes.count != 0 else {
                
                backButton.setTitle("< Back", for: .normal)
                resetButton.alpha = 0
                resetButton.isUserInteractionEnabled = false
                
                return
            }
            
            
            
            let text = restartRequired ? "Restart" : "Apply"
            
            backButton.setTitle(text, for: .normal)
            resetButton.alpha = 1.0
            resetButton.isUserInteractionEnabled = true

        }
    }
    
    
    
    // MARK: init
    init(settingsManager manager: SettingsManager) {
        
        settingsManager = manager
        
        super.init(nibName: "SettingsViewController", bundle: Bundle(for: type(of: self)))
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
    }
    
    
    //  MARK: viewDidload
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Utils.backgroundColour
        
        implementCurrentSettings()
    }
    
    
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
            
            
            // if the user re-enters the value that we're already using, no need
            // for a change/restart
            guard trimmedInput != settingsManager.displayName else {
                changes.removeValue(forKey: SettingsManager.StorageKeys.displayName)
                return
            }
            
            
            let change = SettingsChange(restart: true, validate: {
                try SettingsManager.validate(trimmedInput,
                                             forKey: SettingsManager.StorageKeys.displayName )
            },
                                        change: { [unowned self] in
                self.settingsManager.displayName = trimmedInput
            })
            
            
            changes[SettingsManager.StorageKeys.displayName] = change
        }
        
        
    }
    
    
    
    
    
    // MARK: group code changed
    @IBAction func groupCodeDidChange(_ sender: UITextField){
        
        // get text
        let input = sender.text ?? ""
        
        print(DEBUG_TAG+"new groupcode value is \(input)")
        
        
        // trim whitespace
        let trimmedInput = input.trimmingCharacters(in: [" "])
        
        print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
        
        // if the user re-enters the value that we're already using, no need
        // for a change/restart
        guard trimmedInput != settingsManager.groupCode else {
            changes.removeValue(forKey: SettingsManager.StorageKeys.groupCode)
            return
        }
        
        
        
        let change = SettingsChange(restart: true,  validate: {
            try SettingsManager.validate(trimmedInput,
                                         forKey: SettingsManager.StorageKeys.groupCode )
        }, change:  { [unowned self] in
            self.settingsManager.groupCode = trimmedInput
        })
        
        changes[SettingsManager.StorageKeys.groupCode] = change
    }
    
    
    
    
    
    // MARK: transfer port
    @IBAction func transferPortDidChange(_ sender: UITextField){
        
        // get text
        let input = sender.text ?? ""
        
        print(DEBUG_TAG+"new transfer port value is \(input)")
        
        // trim whitespace
        let trimmedInput = input.trimmingCharacters(in: [" "])
        print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
        
        
        let newPortNum = UInt32(trimmedInput)
        print(DEBUG_TAG+"new registration port num is \(String(describing: newPortNum))")
        
        // if the user re-enters the value that we're already using, no need
        // for a change/restart
        if let num = newPortNum, num == settingsManager.transferPortNumber {
            changes.removeValue(forKey: SettingsManager.StorageKeys.transferPortNumber)
            return
        }
        
        
        let change = SettingsChange(restart: true,  validate: {
            try SettingsManager.validate(newPortNum,
                                         forKey: SettingsManager.StorageKeys.transferPortNumber )
        }, change: { [unowned self] in
            self.settingsManager.transferPortNumber = newPortNum!
        })
        
        
        changes[SettingsManager.StorageKeys.transferPortNumber] = change
    }
    
    
    
    //
    // MARK: registration port
    @IBAction func registrationPortDidChange(_ sender: UITextField) {
        
        // get text
        let input = sender.text ?? ""
        print(DEBUG_TAG+"new registration port value is \(input)")
        
        
        // trim whitespace
        let trimmedInput = input.trimmingCharacters(in: [" "])
        
        print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
        
        
        let newPortNum = UInt32(trimmedInput)
        print(DEBUG_TAG+"new registration port num is \(String(describing: newPortNum))")
        
        
        // if the user re-enters the value that we're already using, no need
        // for a change/restart
        if let num = newPortNum, num == settingsManager.registrationPortNumber {
            changes.removeValue(forKey: SettingsManager.StorageKeys.registrationPortNumber)
            return
        }
        
        // queue change
        let change = SettingsChange(restart: true,  validate: {
            try SettingsManager.validate(newPortNum,
                                         forKey: SettingsManager.StorageKeys.registrationPortNumber )
        }, change:  { [unowned self] in
            self.settingsManager.registrationPortNumber = newPortNum!
        })
        
        
        changes[SettingsManager.StorageKeys.registrationPortNumber] = change
    }
    
    
    
    // MARK: auto-accept changed
    @IBAction func autoAcceptSettingDidChange(_ sender: UISwitch) {
        
        
        // get state
        let switchCheck = sender.isOn
        print(DEBUG_TAG+"incoming transfers \(switchCheck ? "will" : "will NOT") begin automatically (switch is: \(switchCheck ? "ON" : "OFF") )")
        
        // if the user re-enters the value that we're already using, no need
        // for a change/restart
        guard switchCheck != settingsManager.automaticAccept else {
            changes.removeValue(forKey: SettingsManager.StorageKeys.automaticAccept)
            return
        }
        
        
        // queue change
        let change = SettingsChange(restart: false,  validate: {
            try SettingsManager.validate(switchCheck,
                                         forKey: SettingsManager.StorageKeys.automaticAccept )
        }, change:  { [unowned self] in
            self.settingsManager.automaticAccept = switchCheck
        })
        
        changes[SettingsManager.StorageKeys.automaticAccept] = change
        
    }
    
    
    
    // MARK: overwrite changed
    @IBAction func overwriteSettingDidChange(_ sender: UISwitch) {
        
        // get state
        let switchCheck = sender.isOn
        print(DEBUG_TAG+"files will \(switchCheck ? "be" : "NOT be") overwritten (switch is: \(switchCheck ? "ON" : "OFF") )")
        
        
        // if the user re-enters the value that we're already using, no need
        // for a change/restart
        guard switchCheck != settingsManager.overwriteFiles else {
            changes.removeValue(forKey: SettingsManager.StorageKeys.overwriteFiles)
            return
        }
        
        
        // queue change
        let change = SettingsChange(restart: true,  validate: {
            try SettingsManager.validate(switchCheck,
                                         forKey: SettingsManager.StorageKeys.overwriteFiles )
        }, change:  { [unowned self] in
            self.settingsManager.overwriteFiles = switchCheck
        })
        
        changes[SettingsManager.StorageKeys.overwriteFiles] = change
    }
    
    
    
    // MARK: show error popup
    @objc func showPopupError(withTitle title: String, andMessage message: String){
        
        
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertVC.addAction(UIAlertAction(title: "Okay", style: .default, handler: { uiAction in
            self.reset()
        }))
        
        present(alertVC, animated: true) {
            print(self.DEBUG_TAG+"continuing...")
        }
    }
    
    
    // MARK: reset
    @IBAction func reset(){
        
        print(self.DEBUG_TAG+"reset settings")
        changes.removeAll()
        
        implementCurrentSettings()
    }
    
    
    // MARK: back
    @IBAction func back(){
        
        do {
            
            // validate changes
            try changes.values.forEach {
                try $0.validate()
            }
            
            // apply changes
            changes.values.forEach {
                $0.change()
            }
            // move back to settings
            coordinator?.returnFromSettings(restartRequired: restartRequired)
            
        } catch let error as ValidationError {
            showPopupError(withTitle: "Validation Error", andMessage: error.localizedDescription )
        } catch {
            showPopupError(withTitle: "System Error", andMessage: error.localizedDescription )
        }
        
    }
    
}









class SettingsViewModel: NSObject {
    
    
    
    
    
    
    
    
    
    
    
    
    
}
