//
//  TransferViewController.swift
//  Warpinator
//
//  Created by William Millington on 2021-11-24.
//

import UIKit


//MARK: View Controller
final class TransferViewController: UIViewController {
    
    enum ButtonOptions {
        case Cancel
        case Resend
        
    }
    
    
    lazy var DEBUG_TAG: String = "TransferViewController: "
    
    var coordinator: RemoteCoordinator?
    
    @IBOutlet var transferDescriptionLabel: UILabel!
    
    @IBOutlet var transferProgressLabel: UILabel!
    @IBOutlet var transferStatusLabel: UILabel?
    
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var retryButton: UIButton!
    
    
    
    
    @IBOutlet var backButton: UIButton!
    
    @IBOutlet var operationsStack: UIStackView!
    
    
    var remoteViewModel: RemoteViewModel!
    var transferViewModel: TransferOperationViewModel!
    
    
    init(withTransfer t_viewModel: TransferOperationViewModel,
         andRemote r_viewModel: RemoteViewModel) {
        super.init(nibName: "TransferViewController", bundle: Bundle(for: type(of: self)))
        
        transferViewModel = t_viewModel
        remoteViewModel = r_viewModel
        
        
        transferViewModel.onInfoUpdated = {
            self.updateDisplay()
        }
        
        transferViewModel?.onFileAdded = { vm in
            self.addFileViewToStack(withViewModel: vm)
        }
        
        remoteViewModel.onInfoUpdated = {
            self.updateDisplay()
        }
        
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    
    // MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Utils.backgroundColour
        
        // load intial info
        
        operationsStack.arrangedSubviews.forEach { subview in
            subview.removeFromSuperview()
        }
        
        for viewmodel in transferViewModel.files {
            addFileViewToStack(withViewModel: viewmodel)
        }
        
        updateDisplay()
        
    }
    
    
    // MARK: add fileView
    private func addFileViewToStack(withViewModel viewmodel: ListedFileViewModel){
        
//        print(self.DEBUG_TAG+"adding file view to stack")
        let ltview = ListedFileOperationView(withViewModel: viewmodel)
        
        operationsStack.insertArrangedSubview(ltview, at: (operationsStack.arrangedSubviews.count))
    }
    
    
    
    // MARK: udpateDisplay
    func updateDisplay(){
        
        transferStatusLabel?.text = "\(transferViewModel.statusDescription)"
        transferDescriptionLabel?.text = transferViewModel.transferDescription + " \(remoteViewModel.displayName)"
        transferProgressLabel?.text = transferViewModel.progressDescription
        
        var pressable: Bool = false
        
        cancelButton?.allTargets.forEach { target in
            cancelButton?.removeTarget(target, action: nil, for: .allEvents)
        }
        
        switch transferViewModel.status {
        case .TRANSFERRING, .WAITING_FOR_PERMISSION:
            
            pressable = true
            cancelButton?.addTarget(self, action: #selector(cancel), for: .touchUpInside)
            cancelButton?.backgroundColor = #colorLiteral(red: 0.7831932107, green: 0.1171585075, blue: 0.006766619796, alpha: 1)
            
        case .FINISHED:
            
            if transferViewModel.direction == "SENDING" {
                pressable = true
                cancelButton?.addTarget(self, action: #selector(retry), for: .touchUpInside)
                cancelButton?.backgroundColor = #colorLiteral(red: 0.1902806013, green: 0.6370570039, blue: 0.2034104697, alpha: 1)
            }
        case .CANCELLED, .FAILED(_):
            
            // Only allow retry if sending. Otherwise, disable button
            if transferViewModel.direction == "SENDING" {
                print(DEBUG_TAG+"\t\t\t button pressable")
                pressable = true
                cancelButton?.addTarget(self, action: #selector(retry), for: .touchUpInside)
                cancelButton?.backgroundColor = #colorLiteral(red: 0.1902806013, green: 0.6370570039, blue: 0.2034104697, alpha: 1)

            }
        default:
            break
        }
        
        
        
        
        cancelButton?.setTitle(transferViewModel.buttonTitle, for: .normal)
        cancelButton?.alpha = pressable ? 1 : 0.4
        cancelButton?.isUserInteractionEnabled = pressable

    }
    
    
    // MARK: cancel
    @IBAction @objc func cancel(){
        coordinator?.cancelTransfer(forTransferUUID: transferViewModel!.UUID)
        updateDisplay()
    }
    
    
    // MARK: retry
    @IBAction @objc func retry(){
        coordinator?.retryTransfer(forTransferUUID: transferViewModel!.UUID)
        updateDisplay()
    }
    
    
    // MARK: back
    @IBAction @objc func back(){
        coordinator?.showRemote()
    }
}




extension TransferViewController {
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        
        addFileViewToStack(withViewModel: MockListedFileReaderViewModel() )
        
    }
}






//
//MARK:  - ViewModel
class TransferOperationViewModel: NSObject, ObservesTransferOperation {
    
    private var operation: TransferOperation
    
    var onInfoUpdated: ()->Void = {}
    var onFileAdded: (ListedFileViewModel)->Void = { vm in }
    
    
    //
    var UUID: UInt64 {
        return operation.UUID
    }
    
    
    //
    var fileCount: String {
        return "\(operation.fileCount)"
    }

    var buttonTitle: String {
        
        switch operation.status {
        case .TRANSFERRING, .WAITING_FOR_PERMISSION:
            return "Cancel"
        case .FINISHED:
            
            if operation.direction == .SENDING {
                return "Re-send"
            }
        case .CANCELLED, .FAILED(_):
            
            // Only allow retry if sending. Otherwise, disable button
            if operation.direction == .SENDING {
                return "Retry"
            } else {
                return "Cancelled"
            }
        default: break
        }
        return ""
    }
    
    
    var buttonStatus: Bool {
        
        switch operation.status {
        case .TRANSFERRING, .WAITING_FOR_PERMISSION:
            return true
        case .FINISHED:
            
            if operation.direction == .SENDING {
                return true
            }
            
            // "else" returns false after exiting switch
            
        case .CANCELLED, .FAILED(_):
            
            // Only allow retry if sending. Otherwise, disable button
            if operation.direction == .SENDING {
                return true
            }
        default: break
        }
        return false
    }
    
    //
    var transferDescription: String {
        
        let filesCount: Int = operation.fileCount
        let filesCountString: String = "\(filesCount) file" + (filesCount == 1 ? "" : "s")
        
        let directionString = operation.direction == .RECEIVING ? "from" : "to"
        
        return "Transferring \(filesCountString) \(directionString)"
    }
    
    //
    var progressDescription: String {
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        return "\(formatter.string(fromByteCount: Int64(operation.bytesTransferred) ) )/\(formatter.string(fromByteCount: Int64(operation.totalSize) ))"
    }
    
    //
    var status: TransferStatus {
        return operation.status
    }
    
    //
    var statusDescription: String {
        
        switch operation.status {
        case .TRANSFERRING, .WAITING_FOR_PERMISSION:
            return "Waiting"
        case .FINISHED:
                return "Finished"
        case .CANCELLED: return "Cancelled"
        case .FAILED(let error):
            print("TransferviewController:\t\t Failed with \(error)")
                return "Failed"
        default: return "Error"
            
        }
    }
    
    
    //
    var direction: String {
        return "\(operation.direction)"
    }
    
    //
    var files: [ListedFileViewModel] {
        
        var viewModels: [ListedFileViewModel] = []
        
        (operation as? SendFileOperation)?.fileReaders.forEach {  reader in
            
            // If not a file reader, must be a folderReader.
            let vm: ListedFileViewModel
            if let fileReader = reader as? FileReader {
                vm = ListedFileReaderViewModel(fileReader)
            } else {
                vm = ListedFolderReaderViewModel( reader as! FolderReader )
            }
            
            viewModels.append(vm)
        }
        
        
        (operation as? ReceiveFileOperation)?.fileWriters.forEach { writer in
            
            // If not a file writer, must be a folderWriter.
            let vm: ListedFileViewModel
            if let fileWriter = writer as? FileWriter {
                vm = ListedFileWriterViewModel(fileWriter)
            } else {
                let folderWriter = writer as! FolderWriter
                vm = ListedFolderWriterViewModel(folderWriter)
            }
            
            viewModels.append(vm)
        }
        
        return viewModels
    }
    
    
    //
    var progress: Double {
        return operation.progress
    }
    
    
    //
    //
    init(for operation: TransferOperation) {
        self.operation = operation
        super.init()
        operation.addObserver(self)
    }
    
    
    //
    //
    func infoDidUpdate(){
        DispatchQueue.main.async { // update UI on main thread
            self.onInfoUpdated()
        }
    }
    
    
    //
    //
    func fileAdded(_ vm: ListedFileViewModel) {
//        print("TRANSFERVIEWCONTROLLLER: FILE ADDED")
        DispatchQueue.main.async { // update UI on main thread
            self.onFileAdded(vm)
        }
    }
    
    
    deinit {
        operation.removeObserver(self)
    }
}
