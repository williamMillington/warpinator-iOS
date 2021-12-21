//
//  TransferViewModels.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-24.
//

//import Foundation



//class TransferOperationViewModel: NSObject, ObservesTransferOperation {
//
//    private var operation: TransferOperation
//
//    var onInfoUpdated: ()->Void = {}
//
//    var UUID: UInt64 {
//        return operation.UUID
//    }
//
//    var fileCount: Int {
//        return operation.fileCount
//    }
//
//    var progress: Double {
//        return operation.progress
//    }
//
//    var status: TransferStatus {
//        return operation.status
//    }
//
//    var direction: TransferDirection {
//        return operation.direction
//    }
//
//    var files: [FileViewModel] {
//
//        var viewModels: [FileViewModel] = []
//
//        // TODO: this is not ideal. There must be a more gooder way
//        // to arrange this.
//        if operation.direction == .SENDING {
//
//            let transfer = operation as! SendFileOperation
//
//            for file in transfer.fileReaders {
//
////                let vm = FileSenderViewModel(operation: file)
//                let vm = ListedFileSelectionReaderViewModel(file)
//                viewModels.append(vm)
//            }
//
//        } else {
//
//            let transfer = operation as! ReceiveFileOperation
//
//            for filewriter in transfer.files {
//                let vm = FileReceiverViewModel(operation: filewriter)
//                viewModels.append(vm)
//            }
//
//        }
//
//        return viewModels
//    }
//
//
//    init(for operation: TransferOperation) {
//        self.operation = operation
//        super.init()
//        operation.addObserver(self)
//    }
//
//
//    func infoDidUpdate(){
//        DispatchQueue.main.async { // execute UI on main thread
//            self.onInfoUpdated()
//        }
//    }
//
//    deinit {
//        operation.removeObserver(self)
//    }
//}
