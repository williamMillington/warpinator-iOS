//
//  SendTransferViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-13.
//

import UIKit
import MobileCoreServices



class SendTransferViewController: UIViewController {
    
    lazy var DEBUG_TAG: String = "SendTransferViewController: "
    
    var coordinator: CreateTransferCoordinator?
    
    // MARK: cancel button
    @IBOutlet var cancelButton: UIButton!
    
    
    @IBOutlet var transferDescriptionLabel: UILabel!
//    let cancelButton: UIButton = {
//        let button = UIButton()
//        button.setTitle("Cancel", for: .normal)
//        button.setTitleColor( .blue, for: .normal)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.backgroundColor = .white
//        button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
//        return button
//    }()
    
    // MARK: labels
//    let transferDescriptionLabel: UILabel = {
//        let label = UILabel()
//        label.text = "Transfer to"
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        return label
//    }()
    
    
//    let remoteDescriptionLabel: UILabel = {
//        let label = UILabel()
//        label.text = "----------"
//        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isUserInteractionEnabled = false
//        return label
//    }()
    
    // MARK: add files button
    @IBOutlet var addFilesButton: UIButton!
//    let addFilesButton: UIButton = {
//        let button = UIButton()
//        button.setTitle("Add Files", for: .normal)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.backgroundColor = .blue
//        button.addTarget(self, action: #selector(selectFiles), for: .touchUpInside)
//        return button
//    }()
    
    // MARK: send button
    // starts disabled. Enabled when file are added
    @IBOutlet var sendButton: UIButton!
//    let sendButton: UIButton = {
//        let button = UIButton()
//        button.setTitle("Send", for: .normal)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.backgroundColor = .blue
//        button.addTarget(self, action: #selector(send), for: .touchUpInside)
//        button.isUserInteractionEnabled = false
//        button.alpha = 0.5
//        return button
//    }()
    
    
    
    // MARK: files stack
    @IBOutlet var filesStack: UIStackView!
//    var filesStack: UIStackView = {
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
    
    
    
    var viewmodel: RemoteViewModel?
    
    var selections: [FileSelection: UIView] = [:]
    var transferLabelString: String {
        
        let filesCount: Int = selections.count
        let filesCountString: String = "\(filesCount) file" + (filesCount == 1 ? "" : "s")
        
        
        let totalBytesCount: Int = selections.keys.map {
            return $0.bytesCount
        }.reduce(0, +)
        
        
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
    
    // MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        view.backgroundColor = .white
        
        for view in filesStack.arrangedSubviews {   view.removeFromSuperview()  }
        
//        var viewConstraints: [NSLayoutConstraint] = []
        
//        view.addSubview(cancelButton)
//        view.addSubview(transferDescriptionLabel)
//        view.addSubview(remoteDescriptionLabel)
        
//        view.addSubview(filesStack)
//        view.addSubview(addFilesButton)
//
//        view.addSubview(sendButton)
        
//        let sideMargin: CGFloat = 10
        
//        viewConstraints +=  [
//
//            cancelButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 25),
//            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//
//            transferDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            transferDescriptionLabel.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 10),
//
//            remoteDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            remoteDescriptionLabel.topAnchor.constraint(equalTo: transferDescriptionLabel.bottomAnchor, constant: 10),
//
//
//            filesStack.topAnchor.constraint(equalTo: remoteDescriptionLabel.bottomAnchor, constant: 10),
//            filesStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            filesStack.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
//            filesStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//            filesStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
//
//
//            addFilesButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            addFilesButton.widthAnchor.constraint(equalTo: sendButton.widthAnchor, constant: -sideMargin),
//            addFilesButton.heightAnchor.constraint(equalTo: addFilesButton.widthAnchor, multiplier: 0.2),
//            addFilesButton.bottomAnchor.constraint(equalTo: sendButton.topAnchor, constant: -5),
//
//            sendButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            sendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
//            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
//            sendButton.heightAnchor.constraint(equalTo: sendButton.widthAnchor, multiplier: 0.2),
//            sendButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5)
//
//
//        ]
        
//        NSLayoutConstraint.activate(viewConstraints)
        
        
//        remoteDescriptionLabel.text = viewmodel?.displayName ??  "No Device Name"
        view.backgroundColor = Utils.backgroundColour
    }
    
    // MARK: addFile
    func addFile(_ file: FileSelection ){
        
        print(DEBUG_TAG+"adding file: \(file)")
        print(DEBUG_TAG+"\tstack frame: \(filesStack.frame)")
        
        guard selections[file] == nil else {
            print(DEBUG_TAG+"File \(file.name) already selected")
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
    
    // MARK: removeFile
    func removeFile(_ file: FileSelection){
        
        guard let view = selections[file] else {
            print(DEBUG_TAG+"No removable file found")
            return
        }
        
        selections.removeValue(forKey: file)
        filesStack.removeArrangedSubview(view)
        view.removeFromSuperview()
        
//        if filesStack.arrangedSubviews.count == 0 {
//            sendButton.isUserInteractionEnabled = true
//            sendButton.alpha = 1
//        }
        
        sendButton.isUserInteractionEnabled = selections.count != 0
        sendButton.alpha = selections.count != 0 ? 1 : 0.5
        
        transferDescriptionLabel.text = transferLabelString
        
    }
    
    
    // MARK: select files
    @IBAction  @objc func selectFiles(){
        
//        print(DEBUG_TAG+"Showing document picker")
        
        let types: [String] = [ String( kUTTypeItem )]
        
        let documentPickerVC = UIDocumentPickerViewController(documentTypes: types, in: .open)
        documentPickerVC.delegate = self
        documentPickerVC.allowsMultipleSelection = true
//        documentPickerVC.shouldShowFileExtensions = true
        
        
        present(documentPickerVC, animated: true)
        
    }
    
    
    func updateDisplay(){
        
        
        
    }
    
    
    // MARK: send
    @IBAction @objc func send(){
        
        let files = Array(selections.keys)
        coordinator?.sendFiles(files)
        
    }
    
    // MARK: cancel
    @IBAction @objc func cancel(){
        coordinator?.back()
    }
    
}



enum LoadingError: Error {
    var localizedDescription: String {
        return "Error loading data"
    }
    case ACCESS_ERROR
}




// MARK: - ext.



// MARK: UIDocumentPitckerDelegate

extension SendTransferViewController: UIDocumentPickerDelegate {
     
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
//        print(DEBUG_TAG+"Documents picked")
        
        for url in urls {
            
//            print(DEBUG_TAG+"\(url)")
//            print(DEBUG_TAG+"\t\(url.relativePath)")
            print(DEBUG_TAG+"\(url.lastPathComponent)")
            print(DEBUG_TAG+"\t\(url.pathExtension)")
            print(DEBUG_TAG+"\t\(url.hasDirectoryPath)")
            
            guard url.startAccessingSecurityScopedResource() else {
                print(DEBUG_TAG+"Could not access scoped url")
                return
            }
            
            let filename = url.lastPathComponent
            
            do {
                
                var keys: Set<URLResourceKey> = [.nameKey, .fileSizeKey, .isDirectoryKey]
                
                if #available(iOS 14.0, *) {  keys.insert(.contentTypeKey)  }
                
                
                let values = try url.resourceValues(forKeys: keys)
                let bookmark = try url.bookmarkData(options: .minimalBookmark,
                                                    includingResourceValuesForKeys: nil, relativeTo: nil)
                
                url.stopAccessingSecurityScopedResource()
                
                guard let name = values.name,
                      let size = values.fileSize else {
                    throw LoadingError.ACCESS_ERROR
                }
                
                
                let selection = FileSelection(name: name, bytesCount: size, path: url.path, bookmark: bookmark)
                
                addFile(selection)
                
                print(DEBUG_TAG+"\tfile name is \(String(describing: values.name))")
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
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        
        print(DEBUG_TAG+"Document picker cancelled")
        controller.dismiss(animated: true)
//        showSendingScreen()
    }
    
    
}
