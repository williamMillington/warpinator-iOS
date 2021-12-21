//
//  CertificateServer.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-13.
//

import Foundation
import Network

import NIOSSL
import CryptoKit
import Sodium

class CertificateServer {
    
    private var DEBUG_TAG = "CertificateServer: "
    
    public static let REQUEST: String = "REQUEST"
    
    
    func serveCertificate(to connection: NWConnection, onComplete: @escaping () -> Void = {} ){
        
        
        print(DEBUG_TAG+"\tattempting to serve certificate to: \(connection.endpoint)")
        
        connection.receiveMessage { (data, context, isComplete, error) in
            
            if let error = error {
                print(self.DEBUG_TAG+"ERROR: \(error)")
            }
            
            if isComplete {
                guard data != nil else {
                    print("Received data is nil"); return
                }
                
                
                let messageBytesEncoded = Authenticator.shared.getCertificateDataForSending()
                
                connection.send(content: Data(bytes: messageBytesEncoded.bytes, count: messageBytesEncoded.bytes.count),
                                completion: NWConnection.SendCompletion.contentProcessed { (error) in
                                    if error != nil {
                                        print("Error sending cert is: \(String(describing: error))")
                                    } else {
                                        print("Cert sent successfully")
                                    }
                                    print("releasing connection")
                                    // release the connection here when transfer completed or failed
                                    onComplete()
                })
                
            }
        }
    }
}
