//
//  CertificateServer.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-13.
//

import Foundation
import Network

import NIOSSL
import CryptoKit
import Sodium

final class CertificateServer {
    
    private var DEBUG_TAG = "CertificateServer: "
    
    
    //
    // MARK: serveCertificate
    func serveCertificate(to connection: NWConnection,
                          onComplete: @escaping () -> Void = {} ) {
        
        
        print(DEBUG_TAG+"\tserving certificate to: \(connection.endpoint)")
        
        
        // TODO: refactor into receiving/sending, and verify "REQUEST" string
        
        connection.receiveMessage { (data, context, isComplete, error) in
            
            guard error == nil else {
                print(self.DEBUG_TAG+"Error: \(String(describing: error))"); return
            }
            
            
            if isComplete {
                
                let messageBytesEncoded = Authenticator.shared.getCertificateDataForSending()
                
                connection.send(content: Data(bytes: messageBytesEncoded.bytes,
                                              count: messageBytesEncoded.bytes.count),
                                completion: .contentProcessed { (error) in
                    
                    if error != nil {
                        print(self.DEBUG_TAG+"Error sending cert is: \(String(describing: error))")
                    } else {
                        print(self.DEBUG_TAG+"Cert sent successfully")
                    }
                    print(self.DEBUG_TAG+"releasing connection")
                    
                    // release the connection here when transfer completed or failed
                    onComplete()
                })
                
            }
        }
    }
}
