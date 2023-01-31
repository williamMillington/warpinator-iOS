//
//  Errors.swift
//  Warpinator
//
//  Created by William Millington on 2023-01-01.
//

import UIKit




enum MDNSError: Error {
    case ALREADY_RUNNING
    case UNKNOWN_SERVICE
    case CANCELLED
}


enum NetworkError: Error {
    
    case NO_INTERNET
    case ADDRESS_UNAVAILABLE
    case UNKNOWN_ERROR
    
    var localizedDescription: String {
        switch self {
        case .NO_INTERNET: return "No Internet, could not secure IP address"
        case .ADDRESS_UNAVAILABLE: return "IP address is unavailable."
        case .UNKNOWN_ERROR: return "Server has encountered an unknown error"
            
        }
    }
}


enum AuthenticationError: Error {
    
    case TIMED_OUT
    case AUTHENTICATION_FAILED
    case CREDENTIALS_INVALID
    case CREDENTIALS_UNAVAILABLE
    case CREDENTIALS_GENERATION_ERROR
    case UNKNOWN_ERROR
    
    var localizedDescription: String {
        switch self {
        case .TIMED_OUT: return "Authentication timed out"
        case .AUTHENTICATION_FAILED: return "Authentication failed"
        case .CREDENTIALS_INVALID: return "Server certificate and/or private key are invalid"
        case .CREDENTIALS_UNAVAILABLE: return "Server certificate and/or private key could not be found"
        case .CREDENTIALS_GENERATION_ERROR: return "Server credentials could not be created"
        case .UNKNOWN_ERROR: return "Server has encountered an unknown error"
            
        }
    }
}



extension Remote {
    
    enum Error: Swift.Error {
        case REMOTE_PROCESSING_ERROR
        case DISCONNECTED
        case UNAVAILABLE
        case SSL_ERROR
        case UNKNOWN_ERROR
    }

}


extension Server {
    
    enum Error: Swift.Error {
        case SERVER_FAILURE
        case UKNOWN_ERROR
        
        var localizedDescription: String {
            switch self {
            case .SERVER_FAILURE: return "Server failed to start"
            case .UKNOWN_ERROR: return "Server has encountered an unknown error"
            }
        }
    }
}

