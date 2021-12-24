//
//  FileReader.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-02.
//

//import Foundation




//class FileReader: ReadsFile  {
//
//    lazy var DEBUG_TAG: String = "FileReader \"\(filename).\(fileExtension):\" "
//
//    let filename: String
//    let fileExtension: String
//
//    let fileURL: URL
//    let filepath: String
//    var relativeFilePath: String {
//        return filename + "." + fileExtension
//    }
//
//    var fileBytes: [UInt8] = []
//
//    var sent = 0
//    var readHead = 0
////    var hasNext = false
//
//
////    var observers: [FileSenderViewModel] = []
//
//
//
//    init(for file: FileName){
//
//        filename = file.name
//        fileExtension = file.ext
//
//        filepath = Bundle.main.path(forResource: filename,
//                                    ofType: fileExtension)!
//        fileURL = URL(fileURLWithPath: filepath)
//
//        loadFileData()
////        updateObserversInfo()
//    }
//
//
//    func reset(){
//        sent = 0
//        readHead = 0
//    }
//
//    func loadFileData(){
//
//        let fileData = try! Data(contentsOf: fileURL)
//        fileBytes = Array(fileData)
//
//
//        print(DEBUG_TAG+"File loaded")
//        print(DEBUG_TAG+"\tbytes: \(fileBytes.count)")
//    }
//
//
//    func readNextChunk() -> FileChunk? {
//
//        print(DEBUG_TAG+"\tReading next chunk")
////        print(DEBUG_TAG+"\tsent: \(sent)")
////        print(DEBUG_TAG+"\tread-head: \(readHead)")
////        print(DEBUG_TAG+"\ttotal: \(fileBytes.count)")
//
//        guard sent < fileBytes.count else {
////            updateObserversInfo()
//            print(DEBUG_TAG+"No more data to be read"); return nil
//        }
//
//        let datachunk = arraySubsection(from: fileBytes, startingAt: readHead, size: SendFileOperation.chunk_size)
//
//        let fileChunk: FileChunk = .with {
//            $0.relativePath = relativeFilePath
//            $0.fileType = FileType.FILE.rawValue
//            $0.chunk = Data(bytes: datachunk, count: datachunk.count)
//        }
//
//        sent += datachunk.count
//        readHead += datachunk.count
//
////        updateObserversInfo()
//
//        return fileChunk
//    }
//
//
//    private func arraySubsection(from array: [UInt8], startingAt index: Int, size: Int ) -> [UInt8] {
//
//        var endIndex = index + size
//
//        if ((endIndex) >= array.count){
//            endIndex = array.count - 1
//        }
////        print(DEBUG_TAG+"reading from bytes[\(index)...\(endIndex)]")
//        return  Array( array[index...endIndex] )
//    }
//
//}





////MARK: -
////MARK: - sequence
//
//
//
////MARK: iterator
//extension FileReader: Sequence, IteratorProtocol {
//    typealias Element = FileChunk
//
//    func next() -> FileChunk? {
//        return readNextChunk()
//    }
//}


//MARK observers
//extension FileReader {
//
//    func addObserver(_ model: FileSenderViewModel){
//        observers.append(model)
//    }
//
//    func removeObserver(_ model: FileSenderViewModel){
//
//        for (i, observer) in observers.enumerated() {
//            if observer === model {
//                observers.remove(at: i)
//            }
//        }
//    }
//
//    func updateObserversInfo(){
//        observers.forEach { observer in
//            observer.infoDidUpdate()
//        }
//    }
//}







