//
//  Document.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-12-13.
//

import UIKit


protocol DocumentDelegate: class {
    func didPickDocuments(documents: [Document]?)
}


public enum SourceType: Int {
    case files
    case folder
}


class Document: UIDocument {
    
    var data: Data?
    
    override func contents(forType typename:  String) throws -> Any {
        guard let data = data else {
            return Data()
        }
        
        return try NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
    }
    
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents  as? Data else { return }
        self.data = data
    }
    
}
