//
//  WarpinatorRegistrationProvider.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-07.
//

import Foundation
import GRPC
import NIO

import Sodium
import CryptoKit

class WarpinatorRegistrationProvider: WarpRegistrationProvider {
    
    let DEBUG_TAG: String = "WarpinatorRegistrationProvider: "
    
    var interceptors: WarpRegistrationServerInterceptorFactoryProtocol?
    
    var remoteManager: RemoteManager? 
    
    
    public func requestCertificate(request: RegRequest, context: StatusOnlyCallContext) -> EventLoopFuture<RegResponse> {
        
        print(DEBUG_TAG+"serving locked certificate to \(request.hostname)(\(request.ip))")
        
        var response = RegResponse()
        
//        let boxedCertBytes = Authenticator.shared.getBoxedCertificate()
        
//        let boxedCertString = Data(bytes: boxedCertBytes, count: boxedCertBytes.count).base64EncodedString()
        
//        response.lockedCert =  boxedCertString  //messageBytesEncoded
        
        
        let keyCode = "Warpinator"
        let keyCodeBytes = Array(keyCode.utf8)
        
        let encryptedKey = SHA256.hash(data: keyCodeBytes )
        let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })
        
        let sKey = SecretBox.Key(encryptedKeyBytes)
        
        let filename = "root"
        let ext = "pem"
        
        let filepath = Bundle.main.path(forResource: filename,
                                        ofType: ext)!
        
//        print(self.DEBUG_TAG+"loading certificate from \(filename).\(ext)")
        
        let certURL = URL(fileURLWithPath: filepath)
        let certBytes = try! Data(contentsOf: certURL)
        
//                let certstring = String(bytes: Array(certBytes), encoding: .utf8)!
        
        let certificateBytes = Array(certBytes) // certstring.bytes
        
        let sodium = Sodium()
        let sealedBox: (Bytes, SecretBox.Nonce)? = sodium.secretBox.seal(message: certificateBytes,
                                                                        secretKey: sKey)
        
        let nonce = sealedBox!.1
        let encryptedText = sealedBox!.0
        var messageBytes: [UInt8] = []
        
        for byte in nonce {
            messageBytes.append(byte)
        }
        for byte in encryptedText {
            messageBytes.append(byte)
        }
        
        
        let messageBytesEncoded = Data(messageBytes).base64EncodedString()
        
        
        
        response.lockedCert = messageBytesEncoded
        
        
        
        
        
        return context.eventLoop.makeSucceededFuture( response )
    }
    
}
