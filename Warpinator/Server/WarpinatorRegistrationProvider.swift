//
//  WarpinatorRegistrationProvider.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-07.
//

import Foundation
import GRPC
import NIO

final class WarpinatorRegistrationProvider: WarpRegistrationProvider {
    
    private let DEBUG_TAG: String = "WarpinatorRegistrationProvider: "
    
    var interceptors: WarpRegistrationServerInterceptorFactoryProtocol?
    
    public func requestCertificate(request: RegRequest, context: StatusOnlyCallContext) -> EventLoopFuture<RegResponse> {
        
        print(DEBUG_TAG+"serving locked certificate to \(request.hostname)")
        
        var response = RegResponse()
        response.lockedCert = Authenticator.shared.getCertificateDataForSending()
        
        return context.eventLoop.makeSucceededFuture( response )
    }
    
}
