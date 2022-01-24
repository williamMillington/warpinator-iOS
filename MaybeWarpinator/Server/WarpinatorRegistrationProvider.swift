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
    var settingsManager:SettingsManager?
    
    
    public func requestCertificate(request: RegRequest, context: StatusOnlyCallContext) -> EventLoopFuture<RegResponse> {
        
        //TODO: stop doing this.
        let ip = "192.168.2.18"
//        print(DEBUG_TAG+"serving locked certificate to \(request.hostname)(\(request.ip))")
        print(DEBUG_TAG+"serving locked certificate to \(request.hostname)(\(ip))")
        
        var response = RegResponse()
        
        response.lockedCert = Authenticator.shared.getCertificateDataForSending()
        
        remoteManager?.storeIPAddress(ip, forHostname: request.hostname)
        
        return context.eventLoop.makeSucceededFuture( response )
    }
    
}
