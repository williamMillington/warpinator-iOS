//
//  WarpinatorRegistrationProvider.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-07.
//

import Foundation
import GRPC
import NIO

//import Sodium
//import CryptoKit

class WarpinatorRegistrationProvider: WarpRegistrationProvider {
    
    let DEBUG_TAG: String = "WarpinatorRegistrationProvider: "
    
    var interceptors: WarpRegistrationServerInterceptorFactoryProtocol?
    
    var remoteManager: RemoteManager? 
    
    
    public func requestCertificate(request: RegRequest, context: StatusOnlyCallContext) -> EventLoopFuture<RegResponse> {
        
        print(DEBUG_TAG+"serving locked certificate to \(request.hostname)(\(request.ip))")
        
        var response = RegResponse()
        
        response.lockedCert = Authenticator.shared.getCertificateDataForSending()
        
        remoteManager?.storeIPAddress(request.ip, forHostname: request.hostname)
        
        return context.eventLoop.makeSucceededFuture( response )
    }
    
}
