//
//  SendTransferViewController.swift
//  Warpinator
//
//  Created by William Millington on 2021-12-13.
//

import UIKit
import MobileCoreServices



final class SendTransferViewController: UIViewController {
    
    lazy var DEBUG_TAG: String = "SendTransferViewController: "
    
    var coordinator: CreateTransferCoordinator?
    
    @IBOutlet var cancelButton: UIButton!
    
    
    @IBOutlet var transferDescriptionLabel: UILabel!
    
    @IBOutlet var addFilesButton: UIButton!
    @IBOutlet var sendButton: UIButton!
    
    @IBOutlet var filesStack: UIStackView!
    
    var viewmodel: RemoteViewModel?
    
    var selections: [TransferSelection: UIView] = [:]
    var transferLabelString: String {
        
        let filesCount: Int = selections.count
        let filesCountString: String = "\(filesCount) file" + (filesCount == 1 ? "" : "s")
        
        
        let totalBytesCount: Int = selections.keys.map { return $0.bytesCount }.reduce(0, +)
        
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        let sizeString: String = totalBytesCount == 0 ? "" : " (\(formatter.string(fromByteCount: Int64( totalBytesCount ) ))) "
        
        let remoteNameString = viewmodel?.displayName ?? "No_Remote_Name"
        
        
        return "Transfer \(filesCountString)\(sizeString) to \(remoteNameString)"
    }
    
    
    init(withViewModel viewmodel: RemoteViewModel) {
        super.init(nibName: "SendTransferViewController", bundle: Bundle(for: type(of: self)))
        
        self.viewmodel = viewmodel
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    //
    // MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        view.backgroundColor = Utils.backgroundColour
        
        // Clean up from interface builder
        for view in filesStack.arrangedSubviews {   view.removeFromSuperview()  }
        
//        view.backgroundColor = Utils.backgroundColour
    }
    
    
    //
    // MARK: addFile
    func addFile(_ file: TransferSelection ){
        
        print(DEBUG_TAG+"adding file: \(file.name)")
        
        guard selections[file] == nil else {
            print(DEBUG_TAG+"\t\tFile \(file.name) already selected")
            return
        }
        
        sendButton.isUserInteractionEnabled = true
        sendButton.alpha = 1
        
        let vm = ListedFileSelectionViewModel(file)
        let ltview = ListedFileSelectionView(withViewModel: vm) { [weak self] in
            print(self!.DEBUG_TAG+"remove file")
            self?.removeFile(file)
        }
        
        selections[file] = ltview
        
        filesStack.insertArrangedSubview(ltview, at: (filesStack.arrangedSubviews.count))
        
        
        transferDescriptionLabel.text = transferLabelString
    }
    
    
    //
    // MARK: removeFile
    func removeFile(_ file: TransferSelection){
        
        guard let view = selections[file] else {
            print(DEBUG_TAG+"No removable file found")
            return
        }
        
        selections.removeValue(forKey: file)
        filesStack.removeArrangedSubview(view)
        view.removeFromSuperview()
        
        
        sendButton.isUserInteractionEnabled =  (selections.count != 0)
        sendButton.alpha =  selections.count != 0  ?  1 : 0.5
        
        transferDescriptionLabel.text = transferLabelString
        
    }
    
    
    //
    // MARK: select files
    @IBAction @objc func selectFiles(){
        
        print(DEBUG_TAG+"Showing document picker for files")
        let types: [String] = [ String( kUTTypeItem )]
        
        let documentPickerVC = UIDocumentPickerViewController(documentTypes: types, in: .open)
        documentPickerVC.delegate = self
        documentPickerVC.allowsMultipleSelection = true
        
        
        present(documentPickerVC, animated: true)
    }
    
    
    @IBAction  @objc func selectFolder(){
        
        print(DEBUG_TAG+"Showing document picker for folders")
        
        
        let documentPickerVC = UIDocumentPickerViewController(documentTypes: [ kUTTypeFolder as String ], in: .open)
        documentPickerVC.delegate = self
        documentPickerVC.allowsMultipleSelection = true
        
        
        present(documentPickerVC, animated: true)
        
    }
    
    
    
    func updateDisplay(){
        
    }
    
    
    //
    // MARK: send
    @IBAction @objc func send(){
        
        let files = Array(selections.keys)
        coordinator?.sendFiles(files)
        
    }
    
    
    //
    // MARK: cancel
    @IBAction @objc func cancel(){
        coordinator?.back()
    }
    
}










// MARK: UIDocumentPitckerDelegate
enum LoadingError: Error {
    var localizedDescription: String {
        return "Error loading data"
    }
    case ACCESS_ERROR
}



extension SendTransferViewController: UIDocumentPickerDelegate {
     
    // MARK: didPickDocuments
    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        
//        print(DEBUG_TAG+"Documents picked")
        
        for url in urls {
            
//            print(DEBUG_TAG+"\(url)")
//            print(DEBUG_TAG+"\t\(url.relativePath)")
//            print(DEBUG_TAG+"name: \(url.lastPathComponent)")
//            print(DEBUG_TAG+"\textension: \(url.pathExtension)")
//            print(DEBUG_TAG+"\tdirectory: \(url.hasDirectoryPath)")
            
            guard url.startAccessingSecurityScopedResource() else {
                print(DEBUG_TAG+"Could not access scoped url")
                return
            }
            
            let filename = url.lastPathComponent
            
            do {
                
                var fileKeys: Set<URLResourceKey> = [.nameKey, .fileSizeKey, .isDirectoryKey]
                
                
                if #available(iOS 14.0, *) {  fileKeys.insert(.contentTypeKey)  }
                
                
                let values = try url.resourceValues(forKeys: fileKeys)
                let bookmark = try url.bookmarkData(options: .minimalBookmark,
                                                    includingResourceValuesForKeys: nil, relativeTo: nil)
                
                url.stopAccessingSecurityScopedResource()
                
                
                guard let name = values.name else {
                    print(DEBUG_TAG+"ERR: No file name")
                    throw LoadingError.ACCESS_ERROR
                }
                
                
                var type: TransferItemType = .FILE
                if let directory = values.isDirectory, directory {
                    type = .DIRECTORY
                }
                
                
                var size = 0
                if let s = values.fileSize {
                    size = s
                }
                
                
                let selection = TransferSelection(type: type,
                                                  name: name,
                                                  bytesCount: size,
                                                  path: url.path,
                                                  bookmark: bookmark)
                
                addFile(selection)
                
//                print(DEBUG_TAG+"\tfile name is \(String(describing: values.name))")
//                print(DEBUG_TAG+"\tfile size is \(String(describing: values.fileSize))")
//                print(DEBUG_TAG+"\tfile is a directory: \(String(describing: values.isDirectory))")
//
//                if #available(iOS 14.0, *) {
//                    print(DEBUG_TAG+"\tfile is type: \(String(describing: values.contentType))")
//                }
                
            } catch is LoadingError {
                print(DEBUG_TAG+"Error accessing url metadata for \(filename)")
            } catch {
                print(DEBUG_TAG+"Error creating bookmark for \(filename)")
            }
        }
    }
    
    
    //
    // MARK: pickerWasCancelled
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        
        print(DEBUG_TAG+"Document picker cancelled")
        controller.dismiss(animated: true)
    }
    
    
}
