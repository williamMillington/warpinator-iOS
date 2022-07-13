//
//  SettingsViewController.swift
//  Warpinator
//
//  Created by William Millington on 2022-01-18.
//

import UIKit
import Sodium


final class SettingsViewController: UIViewController {

    private let DEBUG_TAG: String = "SettingsViewController: "
    
    @IBOutlet var backButton: UIButton!
    @IBOutlet var resetButton: UIButton!
    
    @IBOutlet var displayNameLabel: UITextField!
    @IBOutlet var groupCodeLabel: UITextField!
    @IBOutlet var transferPortNumberLabel: UITextField!
    @IBOutlet var registrationPortNumberLabel: UITextField!
    
    
    var dismissKeyboardRecognizer: UIGestureRecognizer?
    
    
    @IBOutlet var overwriteSwitch: UISwitch!
    @IBOutlet var autoacceptSwitch: UISwitch!
    
    @IBOutlet var refreshCredentialsSwitch: UISwitch!
    
    var coordinator: MainCoordinator?
    var settingsManager: SettingsManager!
    
    
    //
    //
    var restartRequired: Bool  {
        return changes.values.map {   $0.restartRequired   } // returns [Bool]
        .contains(true) // check if [Bool] contains 'true'
    }
    
    
    // MARK: changes
    var changes: [SettingsManager.StorageKey: SettingsChange] = [:] {
        didSet {
            
            let title: String
            if changes.count == 0 {
               title = "< Back"
            } else {
                title = restartRequired ? "Restart" : "Apply"
            }
            
            backButton.setTitle(title, for: .normal)
            resetButton.alpha = changes.count == 0 ? 0 : 1
            resetButton.isUserInteractionEnabled = changes.count == 0 ? false : true
            
        }
    }
    
    
    
    //
    // MARK: init
    init(settingsManager manager: SettingsManager) {
        
        settingsManager = manager
        
        super.init(nibName: "SettingsViewController", bundle: Bundle(for: type(of: self) ))
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
    }
    
    
    //
    //  MARK: viewDidload
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Utils.backgroundColour
        
        implementCurrentSettings()
        
        displayNameLabel.delegate = self
        groupCodeLabel.delegate = self
        transferPortNumberLabel.delegate = self
        registrationPortNumberLabel.delegate = self
        
    }
    
    
    //
    // MARK: implementCurrentSettings
    func implementCurrentSettings(){
        
        
        displayNameLabel.text = settingsManager.displayName
        groupCodeLabel.text = settingsManager.groupCode
        
        registrationPortNumberLabel.text = "\(settingsManager.registrationPortNumber)"
        transferPortNumberLabel.text = "\(settingsManager.transferPortNumber)"
        
        autoacceptSwitch.isOn = settingsManager.automaticAccept
        overwriteSwitch.isOn = settingsManager.overwriteFiles
        
        refreshCredentialsSwitch.isOn = settingsManager.refreshCredentials
    }
    
    
    
    //
    // MARK: display name changed
    @IBAction func displayNameDidChange(_ sender: UITextField){
        
        // get text
        let input = sender.text ?? ""
        print(DEBUG_TAG+"new DisplayName value is \(input)")
        
        // trim whitespace
        let trimmedInput = input.trimmingCharacters(in: [" "])
        
        print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
        
        
        // if the user re-enters the value already being used, no need
        // for a change/restart
        guard trimmedInput != settingsManager.displayName else {
            changes.removeValue(forKey: .displayName)
            return
        }
        
        
        // validation action
        let onValidate = {
            try SettingsManager.validate(trimmedInput,
                                         forKey: .displayName )
        }
        
        // change setting
        let onChange = { [unowned self] in
            self.settingsManager.displayName = trimmedInput
        }
        
        changes[.displayName] = SettingsChange(restart: true,
                                               validate: onValidate,
                                               change: onChange)
        
    }
    
    
    
    
    //
    // MARK: group code changed
    @IBAction func groupCodeDidChange(_ sender: UITextField){
        
        // get text
        let input = sender.text ?? ""
        
        print(DEBUG_TAG+"new groupcode value is \(input)")
        
        
        // trim whitespace
        let trimmedInput = input.trimmingCharacters(in: [" "])
        
        print(DEBUG_TAG+"\t trimmed value is \'\(trimmedInput)\' ")
        
        // if the user re-enters the value already being used, no need
        // for a change/restart
        guard trimmedInput != settingsManager.groupCode else {
            changes.removeValue(forKey: .groupCode)
            return
        }
        
        
        
        // validation action
        let onValidate = {
            try SettingsManager.validate(trimmedInput,
                                         forKey:.groupCode )
        }
        
        // change setting
        let onChange = { [unowned self] in
            self.settingsManager.groupCode = trimmedInput
        }
        
        
        changes[.groupCode] = SettingsChange(restart: true,
                                            validate: onValidate,
                                            change: onChange)
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
        
        // if the user re-enters the value already being used, no need
        // for a change/restart
        if let num = newPortNum, num == settingsManager.transferPortNumber {
            changes.removeValue(forKey: .transferPortNumber)
            return
        }
        
        
        // validation action
        let onValidate = {
            try SettingsManager.validate(newPortNum,
                                         forKey: .transferPortNumber )
        }
        
        // change setting
        let onChange = { [unowned self] in
            self.settingsManager.transferPortNumber = newPortNum!
        }
        
        
        changes[.transferPortNumber] = SettingsChange(restart: true,
                                                      validate: onValidate,
                                                      change: onChange)
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
        
        
        // if the user re-enters the value already being used, no need
        // for a change/restart
        if let num = newPortNum, num == settingsManager.registrationPortNumber {
            changes.removeValue(forKey: .registrationPortNumber)
            return
        }
        
        
        // validation action
        let onValidate = {
            try SettingsManager.validate(newPortNum,
                                         forKey: .registrationPortNumber )
        }
        
        // change setting
        let onChange = { [unowned self] in
            self.settingsManager.registrationPortNumber = newPortNum!
        }
        
        changes[.registrationPortNumber] = SettingsChange(restart: true,
                                                          validate: onValidate,
                                                          change: onChange)
    }
    
    
    
    // MARK: auto-accept changed
    @IBAction func autoAcceptSettingDidChange(_ sender: UISwitch) {
        
        
        // get state
        let switchCheck = sender.isOn
        print(DEBUG_TAG+"incoming transfers \(switchCheck ? "will" : "will NOT") begin automatically (switch is: \(switchCheck ? "ON" : "OFF") )")
        
        // if the user re-enters the value already being used, no need
        // for a change/restart
        guard switchCheck != settingsManager.automaticAccept else {
            changes.removeValue(forKey: .automaticAccept)
            return
        }
        
        // change setting
        let onChange = { [unowned self] in
            self.settingsManager.automaticAccept = switchCheck
        }
        
        
        changes[.automaticAccept] = SettingsChange(restart: false,
                                                   change: onChange)
    }
    
    
    
    //
    // MARK: overwrite changed
    @IBAction func overwriteSettingDidChange(_ sender: UISwitch) {
        
        // get state
        let switchCheck = sender.isOn
        print(DEBUG_TAG+"files will \(switchCheck ? "be" : "NOT be") overwritten (switch is: \(switchCheck ? "ON" : "OFF") )")
        
        
        // if the user re-enters the value already being used, no need
        // for a change/restart
        guard switchCheck != settingsManager.overwriteFiles else {
            changes.removeValue(forKey: .overwriteFiles)
            return
        }
        
        // change setting
        let onChange = { [unowned self] in
            self.settingsManager.overwriteFiles = switchCheck
        }
        
        
        changes[.overwriteFiles] = SettingsChange(restart: true,
                                                  change: onChange)
    }
    
    
    
    //
    // MARK: refresh credentials
    @IBAction func refreshCredentialsDidChange(_ sender: UISwitch){
        
        
        let selected = sender.isOn
        
        print(DEBUG_TAG+"Credentials \(selected ? "WILL be" : "WILL NOT be") refreshed (switch is: \(selected ? "ON" : "OFF") )")
        
        
        // if the user hits the button a second time, remove
        // the existing change
        guard selected != settingsManager.refreshCredentials else {
            changes.removeValue(forKey: .refreshCredentials)
            return
        }
        
        changes[.refreshCredentials] = SettingsChange(restart: true) {
            self.settingsManager.refreshCredentials = selected
        }
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
            
            // exit settings
            coordinator?.returnFromSettings(restartRequired: restartRequired)
            
        } catch let error as ValidationError {
            showPopupError(withTitle: "Validation Error", andMessage: error.localizedDescription )
        } catch {
            showPopupError(withTitle: "System Error", andMessage: error.localizedDescription )
        }
        
    }
    
}








extension SettingsViewController: UITextFieldDelegate {
    
    //
    // MARK:
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        // remove old recognizer
        if let recognizer = dismissKeyboardRecognizer {
            view.removeGestureRecognizer(recognizer)
        }
        
        // add a gesture recognizer that references the correct textfield
        dismissKeyboardRecognizer = TapGestureRecognizerWithClosure() {
            textField.resignFirstResponder()
        }
        view.addGestureRecognizer(dismissKeyboardRecognizer!)
    }
    
    
    //
    // MARK:
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}
