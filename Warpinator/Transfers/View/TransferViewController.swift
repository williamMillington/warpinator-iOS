//
//  TransferViewController.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-24.
//

import UIKit


//MARK: View Controller
final class TransferViewController: UIViewController {
    
    lazy var DEBUG_TAG: String = "TransferViewController:"
    
    var coordinator: RemoteCoordinator?
    
    @IBOutlet var transferDescriptionLabel: UILabel!
    
    @IBOutlet var transferProgressLabel: UILabel!
    @IBOutlet var transferStatusLabel: UILabel!
    
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var retryButton: UIButton!
    
    @IBOutlet var backButton: UIButton!
    
    @IBOutlet var operationsStack: UIStackView!
    
    
    
    var remoteViewModel: RemoteViewModel?
    var transferViewModel: TransferOperationViewModel?
    
    
    init(withTransfer t_viewModel: TransferOperationViewModel,
         andRemote r_viewModel: RemoteViewModel) {
        super.init(nibName: "TransferViewController", bundle: Bundle(for: type(of: self)))
        
        transferViewModel = t_viewModel
        remoteViewModel = r_viewModel
        
        
        transferViewModel?.onInfoUpdated = { [weak self] in
            self?.updateDisplay()
        }
        
        transferViewModel?.onFileAdded = {
            
        }
        
        remoteViewModel?.onInfoUpdated = { [weak self] in
            self?.updateDisplay()
        }
        
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    // MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Utils.backgroundColour
        
        for view in operationsStack.arrangedSubviews {   view.removeFromSuperview()  }
        
        // load intial info
        
        updateDisplay()
        
    }
    
    
    // MARK: add fileView
    private func addFileViewToStack(withViewModel viewmodel: ListedFileViewModel){
        
        let ltview = ListedFileOperationView(withViewModel: viewmodel)
        
        operationsStack.insertArrangedSubview(ltview, at: (operationsStack.arrangedSubviews.count))
        
    }
    
    
    
    // MARK: udpateDisplay
    func updateDisplay(){
        
//        print(DEBUG_TAG+"updating info")
        
        guard let remoteViewModel = remoteViewModel else { return }
        guard let transferViewModel = transferViewModel else { return }
        
        
        transferStatusLabel.text = "\(transferViewModel.status)"
        
        transferDescriptionLabel.text = transferViewModel.transferDescription + " \(remoteViewModel.displayName)"
//
        
        transferProgressLabel.text = transferViewModel.progressString
        
        // TODO: I don't like this, there's got to be a better way than
        // flicking everything off->on every update
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

        operationsStack.arrangedSubviews.forEach { subview in
            subview.removeFromSuperview()
        }
        
        for viewmodel in transferViewModel.files {
            addFileViewToStack(withViewModel: viewmodel)
        }
        
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





//
//MARK:  - ViewModel
class TransferOperationViewModel: NSObject, ObservesTransferOperation {
    
    private var operation: TransferOperation
    
    var onInfoUpdated: ()->Void = {}
    var onFileAdded: ()->Void = {}
    
    var UUID: UInt64 {
        return operation.UUID
    }
    
    var fileCount: String {
        return "\(operation.fileCount)"
    }

    var transferDescription: String {
        
        let filesCount: Int = operation.fileCount
        let filesCountString: String = "\(filesCount) file" + (filesCount == 1 ? "" : "s")
        
        
        let directionString = operation.direction == .RECEIVING ? "from" : "to"
        
        return "Transferring \(filesCountString) \(directionString)"
    }
    
    
    var progressString: String {
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        return "\(formatter.string(fromByteCount: Int64(operation.bytesTransferred) ) )/\(formatter.string(fromByteCount: Int64(operation.totalSize) ))"
    }
    
    var status: TransferStatus {
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
                let vm: ListedFileViewModel
                if let fileReader = reader as? FileReader {
                    vm = ListedFileReaderViewModel(fileReader)
                } else {
                    let folderReader = reader as! FolderReader
                    vm = ListedFolderReaderViewModel(folderReader)
                }
                
                viewModels.append(vm)
            }
            
        } else {
            
            let transfer = operation as! ReceiveFileOperation
            
            for writer in transfer.fileWriters {
                
                
                let vm: ListedFileViewModel
                if let fileWriter = writer as? FileWriter {
                    vm = ListedFileWriterViewModel(fileWriter)
                } else {
                    let folderWriter = writer as! FolderWriter
                    vm = ListedFolderWriterViewModel(folderWriter)
                }
                
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
        DispatchQueue.main.async { // update UI on main thread
            self.onInfoUpdated()
        }
    }
    
    
    func fileAdded() {
        DispatchQueue.main.async { // update UI on main thread
            self.onFileAdded()
        }
    }
    
    
    deinit {
        operation.removeObserver(self)
    }
}
