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
        
        print(DEBUG_TAG+"serving locked certificate")
        
        var response = RegResponse()
        
        let boxedCertBytes = Authenticator.shared.getBoxedCertificate()
        
        let boxedCertString = Data(bytes: boxedCertBytes, count: boxedCertBytes.count).base64EncodedString()
        
        response.lockedCert =  boxedCertString  //messageBytesEncoded
        
        return context.eventLoop.makeSucceededFuture( response )
    }
    
}
