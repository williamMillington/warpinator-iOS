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
    
//    let port: NWEndpoint.Port
//    let listener: NWListener
    
    
    var connections: [NWEndpoint: NWConnection] = [:]
    
    
    func serveCertificate(to conn: NWConnection, onComplete: @escaping () -> Void = {} ){
        
        print(DEBUG_TAG+"\tattempting to serve certificate to: ")
        
        
        // check if we're already tracking this connection.
        // But my intention is to remove connections upon success, so...this shouldn't
        // happen?
        if !connections.keys.contains(conn.endpoint) {
//            print("added connection")
            connections[conn.endpoint] = conn
        }
        
        let connection = connections[conn.endpoint]!
        connection.parameters.allowLocalEndpointReuse = true
        
        
//        print("\t\(connection.endpoint)")
//        print("\t\(String(describing: connection.currentPath))")
//        print("\t\(connection.parameters)")
        
        
        
        let keyCode = "Warpinator"
        let keyCodeBytes = Array(keyCode.utf8)
        
        let encryptedKey = SHA256.hash(data: keyCodeBytes )
        let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })
        
        let sKey = SecretBox.Key(encryptedKeyBytes)
        
        
//        print("\tsending request...")
        // SENDING
        
        
        connection.receiveMessage { (data, context, isComplete, error) in
            
//            print("received something...")
            
            if isComplete {
                guard data != nil else {
                    print("Received data is nil"); return
                }
                
                
//                guard let certificate = Authenticator.shared.getServerCertificate() else { return }
//                let certificateBytes = try! certificate.toDERBytes()
                
                guard let bytes = Authenticator.shared.getServerCertificateBytes() else { return }
                let certificateBytes = Array(bytes)
//                let certificateBytes = try! certificate.toDERBytes()
                
                let sodium = Sodium()
//                let sNonce = sodium.secretBox.nonce()
                let sealedBox: (Bytes, SecretBox.Nonce)? = sodium.secretBox.seal(message: certificateBytes,
                                                                                secretKey: sKey)
                
                let nonce = sealedBox!.1
                let encryptedText = sealedBox!.0
                var messageBytes: [UInt8] = []
                
                for byte in nonce {
//                    print("NONCE: byte appended")
                    messageBytes.append(byte)
                }
                for byte in encryptedText {
//                    print("MSG_TEXT: byte appended")
                    messageBytes.append(byte)
                }
                
                
//                print("MESSAGEBYTES: \(messageBytes)")
                
                let messageBytesEncoded = Data(messageBytes).base64EncodedString()
                
                print("MESSAGEBYTESEncoded: \(messageBytesEncoded)")
                
                connection.send(content: Data(bytes: messageBytesEncoded.bytes, count: messageBytesEncoded.bytes.count),
                                completion: NWConnection.SendCompletion.contentProcessed { (error) in
                                    if error != nil {
                                        print("Error sending cert is: \(String(describing: error))")
                                    } else {
                                        print("Cert sent successfully")
                                    }
                                    // release the connection here when transfer completed or failed
                                    self.connections.removeValue(forKey: connection.endpoint)
                })
                
            }
            
        }
        
    }
    
}
