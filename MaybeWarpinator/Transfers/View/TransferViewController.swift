//
//  TransferViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-24.
//

import UIKit


//MARK: View
class TransferViewController: UIViewController {
    
    lazy var DEBUG_TAG: String = "TransferViewController:"
    
    var coordinator: RemoteCoordinator?
    
    // MARK: labels
    @IBOutlet var transferDescriptionLabel: UILabel!
//    let transferDescriptionLabel: UILabel = {
//        let label = UILabel()
//        label.text = "Transfer"
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        return label
//    }()
    
//    @IBOutlet var deviceNameLabel: UILabel!
//    let deviceNameLabel: UILabel = {
//        let label = UILabel()
//        label.text = "DeviceName"
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        return label
//    }()
    
//    @IBOutlet var deviceStatusLabel: UILabel!
//    let deviceStatusLabel: UILabel = {
//        let label = UILabel()
//        label.text = "(--device status--)"
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        return label
//    }()
    
    @IBOutlet var transferProgressLabel: UILabel!
    @IBOutlet var transferStatusLabel: UILabel!
//    let transferStatusLabel: UILabel = {
//        let label = UILabel()
//        label.text = "--transfer status--"
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        return label
//    }()
    
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var retryButton: UIButton!
    // MARK: transfer button
//    let transferButton: UIButton = {
//        let button = UIButton()
//        button.setTitle("Cancel", for: .normal)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.backgroundColor = .blue
//        button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
////        button.alpha = 0.5 // 'grayed' out while disabled
////        button.isUserInteractionEnabled = false // disabled for inital setup
//        return button
//    }()
    
    
    // MARK: files stack
    @IBOutlet var operationsStack: UIStackView!
//    var operationsStack: UIStackView = {
//        let stack = UIStackView()
//        stack.translatesAutoresizingMaskIntoConstraints = false
//        stack.alignment = .fill
//        stack.distribution = .fillProportionally
//        stack.spacing = 5
//        stack.axis = .vertical
//        stack.backgroundColor = UIColor.blue.withAlphaComponent(0.2)
//
//        let expanderView = UIView()
//        expanderView.translatesAutoresizingMaskIntoConstraints = false
//        expanderView.backgroundColor = UIColor.blue.withAlphaComponent(0.2)
//
//        // without this, height is constrained to 0 for some dumb reason,
//        // and breaks stackview's attempts to resize it
//        expanderView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
//
//        stack.addArrangedSubview(expanderView)
//
//        return stack
//    }()
    
    // MARK: back button
    @IBOutlet var backButton: UIButton!
//    let backButton: UIButton = {
//        let button = UIButton()
//        button.setTitle("back", for: .normal)
//        button.setTitleColor( .blue, for: .normal)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.backgroundColor = .white
//        button.addTarget(self, action: #selector(back), for: .touchUpInside)
//        return button
//    }()
    
//    var transferDescriptionString: String {
//
//        let filesCount: Int = selections.count
//        let filesCountString: String = "\(filesCount) file" + (filesCount == 1 ? "" : "s")
//
//
//        let totalBytesCount: Int = selections.keys.map {
//            return $0.bytesCount
//        }.reduce(0, +)
//
//
//        let formatter = ByteCountFormatter()
//        formatter.countStyle = .file
//
//        let sizeString: String = totalBytesCount == 0 ? "" : " (\(formatter.string(fromByteCount: Int64( totalBytesCount ) ))) "
//
//        let remoteNameString = viewmodel?.displayName ?? "No_Remote_Name"
//
//
//        return "Transfer \(filesCountString)\(sizeString) to \(remoteNameString)"
//    }
    
    var remoteViewModel: RemoteViewModel?
    var transferViewModel: TransferOperationViewModel?
    
    
    init(withTransfer t_viewModel: TransferOperationViewModel, andRemote r_viewModel: RemoteViewModel) {
        super.init(nibName: "TransferViewController", bundle: Bundle(for: type(of: self)))
        
        transferViewModel = t_viewModel
        remoteViewModel = r_viewModel
        
//        transferDescriptionLabel.text = "Transfer \(transferViewModel?.direction)"
        
        transferViewModel?.onInfoUpdated = {
            self.updateDisplay()
        }
        
        remoteViewModel?.onInfoUpdated = {
            self.updateDisplay()
        }
        
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    // MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        for view in operationsStack.arrangedSubviews {   view.removeFromSuperview()  }
        
//        view.addSubview(backButton)
//        view.addSubview(transferDescriptionLabel)
//
//        view.addSubview(deviceNameLabel)
//        view.addSubview(deviceStatusLabel)
//
//        view.addSubview(transferStatusLabel)
//
//        view.addSubview(operationsStack)
//
//        view.addSubview(transferButton)
        
//        var viewConstraints: [NSLayoutConstraint] = []
//
//        let topAnchor = view.safeAreaLayoutGuide.topAnchor
//        let sideMargin: CGFloat = 10
//
//        viewConstraints +=  [
//
//            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//            backButton.topAnchor.constraint(equalTo: topAnchor, constant: 20),
//
//            transferDescriptionLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor),
//            transferDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//
//            deviceNameLabel.topAnchor.constraint(equalTo: transferDescriptionLabel.bottomAnchor, constant: 5),
//            deviceNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//
//            deviceStatusLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor),
//            deviceStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//
////            operationsStack.topAnchor.constraint(equalTo: displayNameLabel.bottomAnchor, constant: 25),
//            operationsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//            operationsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
//            operationsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            operationsStack.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
//            operationsStack.bottomAnchor.constraint(equalTo: transferButton.topAnchor, constant: -10),
//
//
//            transferStatusLabel.bottomAnchor.constraint(equalTo: operationsStack.topAnchor, constant: -5),
//            transferStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//
//            transferButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//            transferButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
//            transferButton.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.1),
//            transferButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
//
//        ]
//
//        NSLayoutConstraint.activate(viewConstraints)
        
        /* If this is not called, Autolayout will think that the stackview is height 0,
         and will set all subsequent subviews to height == 0.
         Then it will complain that some idiot set all the subview heights to 0. */
//        view.layoutIfNeeded()
        
        
        // load intial info
        
        updateDisplay()
        
        for viewmodel in transferViewModel!.files {
            addFileViewToStack(withViewModel: viewmodel)
        }
        
        
    }
    
    
    // MARK: add fileView
    private func addFileViewToStack(withViewModel viewmodel: ListedFileViewModel){
        
//        print(DEBUG_TAG+"here be reached!")
        
        let ltview = ListedFileOperationView(withViewModel: viewmodel)
        
        operationsStack.insertArrangedSubview(ltview, at: (operationsStack.arrangedSubviews.count))
        
//        print(DEBUG_TAG+"here be reached! 2222")
    }
    
    
    
    // MARK: udpateDisplay
    func updateDisplay(){
        
//        print(DEBUG_TAG+"updating info")
        
        guard let remoteViewModel = remoteViewModel else { return }
        guard let transferViewModel = transferViewModel else { return }
        
//        print(DEBUG_TAG+"\tview models available")
        
//        deviceNameLabel.text = remoteViewModel.userName
//        deviceStatusLabel.text = "(\(remoteViewModel.status))"
        
        transferStatusLabel.text = "\(transferViewModel.status)"
        
        transferDescriptionLabel.text = transferViewModel.transferDescription + " \(remoteViewModel.displayName)"
//
        
        transferProgressLabel.text = transferViewModel.progressString
        
//        transferButton.removeTarget(nil, action: nil, for: .allEvents)

        
        // TODO: I don't like this. To much flicking shit on/off every update.
        // Make it gooder.
        cancelButton.alpha = 0
        cancelButton.isUserInteractionEnabled = false
        retryButton.alpha = 0
        retryButton.isUserInteractionEnabled = false
        
        let buttonStatus = transferViewModel.buttonStatus()
        
        if buttonStatus.pressable {
            
            if buttonStatus.text == "Retry" {
                retryButton.alpha = 1
                retryButton.isUserInteractionEnabled = true
            } else {
                cancelButton.alpha = 1
                cancelButton.isUserInteractionEnabled = true
            }
            
        }
//
//        transferButton.isUserInteractionEnabled = buttonStatus.pressable
//        transferButton.alpha = buttonStatus.pressable ? 1 : 0.5
//
//        transferButton.setTitle(buttonStatus.text, for: .normal)
//
//        let selector = buttonStatus.text == "Cancel" ? #selector(cancel) : #selector(retry)
//        transferButton.addTarget(self, action: selector, for: .touchUpInside)
//
    }
    
    
    // MARK: cancel
    @IBAction @objc func cancel(){
        coordinator?.cancelTransfer(forTransferUUID: transferViewModel!.UUID)
    }
    
    
    // MARK: retry
    @IBAction @objc func retry(){
        coordinator?.retryTransfer(forTransferUUID: transferViewModel!.UUID)
    }
    
    
    // MARK: back
    @IBAction @objc func back(){
        coordinator?.showRemote()
    }
}





//MARK:  -
//MARK:  - ViewModel
class TransferOperationViewModel: NSObject, ObservesTransferOperation {
    
    private var operation: TransferOperation
    
    var onInfoUpdated: ()->Void = {}
    
    var UUID: UInt64 {
        return operation.UUID
    }
    
    var fileCount: String {
        return "\(operation.fileCount)"
    }

    var transferDescription: String {
        
        let filesCount: Int = operation.fileCount
        let filesCountString: String = "\(filesCount) file" + (filesCount == 1 ? "" : "s")
        
        
//        let totalBytesCount: Int = selections.keys.map {
//            return $0.bytesCount
//        }.reduce(0, +)
//
        
//        let formatter = ByteCountFormatter()
//        formatter.countStyle = .file
//
//        let sizeString: String = totalBytesCount == 0 ? "" : " (\(formatter.string(fromByteCount: Int64( totalBytesCount ) ))) "
        
//        let remoteNameString = viewmodel?.displayName ?? "No_Remote_Name"
        let directionString = operation.direction == .RECEIVING ? "from" : "to"
        
        return "Transferring \(filesCountString) \(directionString)"
    }
//    var status: String {
//        switch operation.status {
//        case .FAILED(_): return "Failed"
//        default: return "\(operation.status)"
//        }
//    }
    
    
    var progressString: String {
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        return "\(formatter.string(fromByteCount: Int64(operation.bytesTransferred) ) )/\(formatter.string(fromByteCount: Int64(operation.totalSize) ))"
    }
    
    var status: TransferStatus {
//        switch operation.status {
//        case .FAILED(_): return "Failed"
//        default: return "\(operation.status)"
//        }
        return operation.status
    }
    
    var direction: String {
        return "\(operation.direction)"
    }
    
    var files: [ListedFileViewModel] {
        
        var viewModels: [ListedFileViewModel] = []
        
        // TODO: this is not ideal. There must be a more gooder way
        // to arrange this.
        if let transfer = operation as? SendFileOperation {
            
            for reader in transfer.fileReaders {
                
                // If not a file reader, must be a folderReader.
                // Right?
                // RIgHT?????
                // TODO: messy. MESSY MESSY MESSY.
                let vm: ListedFileViewModel
                if let fileReader = reader as? FileReader {
                    vm = ListedFileReaderViewModel(fileReader)
                } else {
                    let folderReader = reader as! FolderReader
                    vm = ListedFolderReaderViewModel(folderReader)
                }
                
                viewModels.append(vm)
//                switch file {
//                case is FileReader :
//                    let vm = ListedFileReaderViewModel(file)
//                    viewModels.append(vm)
//                case is FolderReader:
//                    let vm = ListedFolderReaderViewModel(file)
//                    viewModels.append(vm)
//                }
                
                
//                let vm = ListedFileReaderViewModel(file)
//                viewModels.append(vm)
            }
            
        } else {
            
            let transfer = operation as! ReceiveFileOperation
            
            for filewriter in transfer.files {
                let vm = ListedFileWriterViewModel(operation: filewriter)
                viewModels.append(vm)
            }
            
        }
        
        return viewModels
    }
    
    var progress: Double {
        return operation.progress
    }
    
    
    init(for operation: TransferOperation) {
        self.operation = operation
        super.init()
        operation.addObserver(self)
    }
    
    
    func buttonStatus() -> (pressable: Bool, text: String) {
        
        var pressable: Bool = false
        var text: String = "Finished"
        
        switch operation.status {
        case .TRANSFERRING, .WAITING_FOR_PERMISSION:
            
            pressable = true
            text = "Cancel"
            
        case .CANCELLED, .FAILED(_):
            
            // Only allow retry if sending. Otherwise, disable button
            guard operation.direction == .SENDING else {
                text = "Failed"
                fallthrough
            }
            
            pressable = true
            text = "Retry"
        default: break
        }
        
        
        return (pressable, text)
    }
    
    
    func infoDidUpdate(){
        DispatchQueue.main.async { // execute UI on main thread
            self.onInfoUpdated()
        }
    }
    
    
    func fileAdded() {
        
    }
    
    
    deinit {
        operation.removeObserver(self)
    }
}
