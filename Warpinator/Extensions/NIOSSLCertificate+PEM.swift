//
//  NIOSSLCertificate_PEM.swift
//  Warpinator
//
//  Created by William Millington on 2022-03-22.
//

import Foundation
import NIOSSL



extension ExtensionManager where Base == NIOSSLCertificate {
    
    var pemBytes: [UInt8]? {
        
        guard let derData = try? base.toDERBytes() else {
            return nil
        }
        
        let derBytesString = Data(derData).base64EncodedString()
        
        let pemBytesString = "-----BEGIN CERTIFICATE-----\n" + derBytesString + "\n-----END CERTIFICATE-----\n"
        
        return pemBytesString.bytes
    }
    
    var pemData: Data? {
        guard let bytes = base.extended.pemBytes else {  return nil  }
        return Data(bytes)
    }
    
}
