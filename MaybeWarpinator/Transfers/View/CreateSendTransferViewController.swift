//
//  CreateSendTransferViewController.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-13.
//

import UIKit
import MobileCoreServices


class CreateSendTransferViewController: UIViewController {
    
    lazy var DEBUG_TAG: String = "CreateSendTransferViewController:"
    
    var coordinator: CreateTransferCoordinator?
    
    
    let cancelButton: UIButton = {
        let button = UIButton()
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor( .blue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        return button
    }()
    
    
    let transferDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Transfer to"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let remoteDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "----------"
        label.backgroundColor = UIColor.green.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()
    
    
    let addFilesButton: UIButton = {
        let button = UIButton()
        button.setTitle("Add Files", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .blue
        button.addTarget(self, action: #selector(selectFiles), for: .touchUpInside)
        return button
    }()
    
    
    let sendButton: UIButton = {
        let button = UIButton()
        button.setTitle("Send", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .blue
        button.addTarget(self, action: #selector(send), for: .touchUpInside)
        button.isUserInteractionEnabled = false
        button.alpha = 0.5
        return button
    }()
    
    
    
    
    var filesStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.alignment = .fill
        stack.distribution = .fillProportionally
        stack.spacing = 5
        stack.axis = .vertical
        stack.backgroundColor = UIColor.blue.withAlphaComponent(0.2)
        
        let expanderView = UIView()
        expanderView.translatesAutoresizingMaskIntoConstraints = false
        expanderView.backgroundColor = UIColor.blue.withAlphaComponent(0.2)
        
        // without this, height is constrained to 0 for some dumb reason,
        // and breaks stackview's attempts to resize it
        expanderView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
        
        stack.addArrangedSubview(expanderView)
        
        return stack
    }()
    
    
    
    var viewmodel: RemoteViewModel?
    
    
    var selections: [FileSelection] = []
    
    
    
    init(withViewModel viewmodel: RemoteViewModel) {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
        
        self.viewmodel = viewmodel
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        view.backgroundColor = .white
        
        var viewConstraints: [NSLayoutConstraint] = []
        
        view.addSubview(cancelButton)
        view.addSubview(transferDescriptionLabel)
        view.addSubview(remoteDescriptionLabel)
        
        view.addSubview(filesStack)
        view.addSubview(addFilesButton)
        
        view.addSubview(sendButton)
        
        let sideMargin: CGFloat = 10
        
        viewConstraints +=  [
            
            cancelButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 25),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            
            transferDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            transferDescriptionLabel.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 10),
            
            remoteDescriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            remoteDescriptionLabel.topAnchor.constraint(equalTo: transferDescriptionLabel.bottomAnchor, constant: 10),
            
            
            filesStack.topAnchor.constraint(equalTo: remoteDescriptionLabel.bottomAnchor, constant: 10),
            filesStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            filesStack.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
            filesStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            filesStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
            
            
            addFilesButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addFilesButton.widthAnchor.constraint(equalTo: sendButton.widthAnchor, constant: -sideMargin),
            addFilesButton.heightAnchor.constraint(equalTo: addFilesButton.widthAnchor, multiplier: 0.2),
            addFilesButton.bottomAnchor.constraint(equalTo: sendButton.topAnchor, constant: -5),
            
            sendButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
            sendButton.heightAnchor.constraint(equalTo: sendButton.widthAnchor, multiplier: 0.2),
            sendButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5)
            
            
        ]
        
        NSLayoutConstraint.activate(viewConstraints)
        
        
        remoteDescriptionLabel.text = viewmodel?.displayName ??  "No Device Name"
        
    }
    
    
    func addFile(_ file: FileSelection){
        
        guard !selections.contains(file) else {
            print(DEBUG_TAG+"File \(file.name) already selected")
            return
        }
        
        selections.append(file)
        
        sendButton.isUserInteractionEnabled = true
        sendButton.alpha = 1
        
        let vm = ListedFileSelectionViewModel(file)
        let ltview = ListedFileSelectionView(withViewModel: vm)
        
        filesStack.insertArrangedSubview(ltview, at: (filesStack.arrangedSubviews.count - 1))
        
    }
    
    
    func removeFile(_ file: FileSelection){
        
        selections.removeAll(where: { item in
            return item == file
        })
        
        
        if filesStack.arrangedSubviews.count == 0 {
            sendButton.isUserInteractionEnabled = true
            sendButton.alpha = 1
        }
        
    }
    
    
    @objc func selectFiles(){
        
//        print(DEBUG_TAG+"Showing document picker")
        
        let types: [String] = [ String( kUTTypeItem )]//, String( kUTTypeJPEG )  ]
        
        let documentPickerVC = UIDocumentPickerViewController(documentTypes: types, in: .open)
        documentPickerVC.delegate = self
        documentPickerVC.allowsMultipleSelection = true
//        documentPickerVC.shouldShowFileExtensions = true
        
        
//        navController.pushViewController(documentPickerVC, animated: false)
        present(documentPickerVC, animated: true)
        
    }
    
    
    @objc func send(){
        
        coordinator?.sendFiles(selections)
        
    }
    
    
    @objc func cancel(){
//        coordinator?.start()
        coordinator?.cancel()
    }
    
}



enum LoadingError: Error {
    var localizedDescription: String {
        return "Error loading data"
    }
    case ACCESS_ERROR
}


extension CreateSendTransferViewController: UIDocumentPickerDelegate {
     
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
