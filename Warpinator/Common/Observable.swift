//
//  Observable.swift
//  Warpinator
//
//  Created by William Millington on 2021-12-20.
//

import Foundation


// MARK: Observes Remote
protocol ObservesRemote: NSObject {
    func infoDidUpdate()
    func operationAdded(_ operation: TransferOperation)
}



// MARK: Observes Transfer
protocol ObservesTransferOperation: NSObject {
    func infoDidUpdate()
    func fileAdded(_ vm: ListedFileViewModel)
}


// MARK: Observes File
protocol ObservesFileOperation: NSObject {
    func infoDidUpdate()
}
