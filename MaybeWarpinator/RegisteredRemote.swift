//
//  Remote.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-03.
//

import UIKit


import NIO
import NIOSSL
import Network

import GRPC
import SwiftProtobuf


import CryptoKit
import Sodium


import Logging


//MARK: Remote Details
public struct RemoteDetails {
    public enum ConnectionStatus {
        case Canceled
        case OpeningConnection, FetchingCredentials, AquiringDuplex, DuplexAquired
        case Error
        case Connected, Disconnected
    }
    
    lazy var DEBUG_TAG: String = "RemoteDetails (hostname: \"\(hostname)\"): "
    
    var endpoint: NWEndpoint
    
    var displayName: String = "No_DisplayName"
    var username: String = "No_Username"
    
    
    var serviceName: String = "No_ServiceName"
    var hostname: String = "No_Hostname"
    var port: Int = 0 //"No_Port"
    var authPort: Int = 0 //"No_Auth_Port"
    
    var uuid: String = "NO_UUID"
    var api: String = "1"
    
    var status: ConnectionStatus = .Disconnected
    
    var serviceAvailable: Bool = false
    
}





// MARK: - Registered Remote
public class Remote {
    
    lazy var DEBUG_TAG: String = "REMOTE (hostname: \"\(details.hostname)\"): "
    
    var details: RemoteDetails
    
    public var displayName: String = "No_Display_Name"
    public var picture: UIImage?
    
    var transferOperations: [TransferOperation] = []
    
    var channel: ClientConnection?
    var warpClient: WarpClientProtocol?
    
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 5) //GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    var authenticationCertificate: NIOSSLCertificate?
    
    var duplexAttempts: Int = 0
    
    
    var logger = Logger(label: "warpinator.Remote", factory: StreamLogHandler.standardOutput)
    
    
    var lookupName: LookupName {
        return LookupName.with {
            $0.id =  Server.SERVER_UUID
            $0.readableName = "Warpinator iOS"
        }
    }
    
    
    init(details: RemoteDetails, certificate: NIOSSLCertificate){
        self.details = details
        authenticationCertificate = certificate
    }
    
    
    //MARK: connect
    func connect(){
        
        details.status = .OpeningConnection
        
        if warpClient == nil {
            
            logger.logLevel = .debug
            
            let channelBuilder = ClientConnection.usingTLSBackedByNIOSSL(on: group)
                .withTLS(trustRoots: .certificates([authenticationCertificate!]) )
                .withConnectivityStateDelegate(self)
//                .withBackgroundActivityLogger(logger)
                
                
            
            let hostname = details.hostname
//            let hostname = "192.168.2.18"
//            let hostname = "192.168.2.14"
            let port = details.port
            
            channel = channelBuilder.connect(host: hostname, port: port)
            
            if let channel = channel {
                print(self.DEBUG_TAG+"channel created")
                warpClient = WarpClient(channel: channel)
                
//                details.status = .VerifyingDuplex
//                ping()
                verifyDuplex() //.Connected
            } else {
                details.status = .Error
            }
            
        }
    }
    
    
    
    // MARK: veryifyDuplex
    private func verifyDuplex(onComplete: @escaping ()->Void = {} ){
        
        duplexAttempts += 1
        
        print(DEBUG_TAG+"verifying duplex, attempt: \(duplexAttempts)")
        
        details.status = .AquiringDuplex
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        var duplex: UnaryCall<LookupName, HaveDuplex> // = client.waitingForDuplex(lookupname)
        if details.api == "1" {
            print(DEBUG_TAG+"checkDuplexConnection")
            duplex = client.checkDuplexConnection(lookupName)
        } else {
            print(DEBUG_TAG+"waitingForDuplex")
            duplex = client.waitingForDuplex(lookupName)
        }
        
        
        duplex.response.whenSuccess { haveDuplex in
            
            if haveDuplex.response {
                    self.onDuplexAquired()
                } else {
                    print(self.DEBUG_TAG+"could not verify duplex")
                    
                    // 5 tries
                    guard self.duplexAttempts < 10 else {
                        print(self.DEBUG_TAG+"Duplex has failed.")
                        self.details.status = .Error
                        return }
                    print(self.DEBUG_TAG+"\ttrying again...")
                    
                    // try again in 1 second
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.verifyDuplex()
                    }
                }
        }
        
        duplex.response.whenFailure { error in
            print(self.DEBUG_TAG+"Duplex failed: \(error)")
            
            // 5 tries
            guard self.duplexAttempts < 10 else {
                print(self.DEBUG_TAG+"Duplex has failed.")
                self.details.status = .Error
                return }
            print(self.DEBUG_TAG+"\ttrying again...")
            
            // try again in 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.verifyDuplex()
            }
        }
    }
    
    
    
    // MARK: onDuplexVerified
    private func onDuplexAquired(){
        
        print(self.DEBUG_TAG+"duplex verified after \(duplexAttempts) attempts")
        
        details.status = .DuplexAquired
        
        updateRemoteInfo()
        
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5){
//            self.ping()
//        }
//        ping()
        
    }
    
    
    
    
}







//MARK: Warpinator RPC calls
extension Remote {
    
    
    // MARK: -Ping
    public func ping(){
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        // if we're currently transferring something, no need to ping.
        if transferOperations.count == 0 {
            
            print(self.DEBUG_TAG+"pinging")
            
            let pingResponse = client.ping(self.lookupName) //, callOptions: calloptions)
            
            pingResponse.response.whenFailure { _ in
                print(self.DEBUG_TAG+"ping failed")
//                self.details.status = .Disconnected
            }
        }
        
        // ping again in 10 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.details.status == .Connected {
                self.ping()
            }
        }
    }
    
    
    //MARK: -updateRemoteInfo
    func updateRemoteInfo(){
        
        print(DEBUG_TAG+"Retrieving information from \(details.hostname)")
        
        guard let client = warpClient else { return }
        
        let info = client.getRemoteMachineInfo(lookupName)
        
        info.response.whenSuccess { info in
            self.details.displayName = info.displayName
            self.details.username = info.userName
            self.details.status = .Connected
            
            print(self.DEBUG_TAG+"Remote display name: \(self.details.displayName)")
            print(self.DEBUG_TAG+"Remote username: \(self.details.username)")
        }
        info.response.whenFailure { error in
            print(self.DEBUG_TAG+"failed to retrieve machine info")
        }
        
        
    }
    
    
    
    // MARK: addTransfer
    func addTransferOperation(_ operation: TransferOperation){
        
        transferOperations.append(operation)
        operation.status = .WAITING_FOR_PERMISSION
    }
    
    
    
    // MARK: findTransfer
    func findTransferFor(startTime time: UInt64 ) -> TransferOperation? {
        for operation in transferOperations {
            if operation.startTime == time {
                return operation
            }
        }
        
        return nil
    }
    
    
    
    
    func beginReceiving(for operation: TransferOperation){
        
        print(DEBUG_TAG+"initiating transfer operation")
        
        let operationInfo = OpInfo.with {
            $0.ident = Server.SERVER_UUID
            $0.timestamp = operation.startTime
            $0.readableName = Server.SERVER_UUID
            $0.useCompression = false
        }
        
        guard let client = warpClient else { return }
        
        
        let dataStream = client.startTransfer(operationInfo) { (chunk) in
            operation.readChunk(chunk)
        }
        
        
        dataStream.status.whenSuccess{ status in
            operation.finishReceive()
            print(self.DEBUG_TAG+"transfer finished")
        }
        
        dataStream.status.whenFailure{ error in
            print(self.DEBUG_TAG+"transfer failed: \(error)")
        }
        
        
        
        
        
    }
    
    
    
    
}











extension Remote: ConnectivityStateDelegate {
    
    //MARK: connectivityStateDidChange
    public func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
        print(DEBUG_TAG+"channel state has moved from \(oldState) to \(newState)".uppercased())
        switch newState {
//        case .connecting: ping()
        case .ready: print(DEBUG_TAG+"channel ready")
//            verifyDuplex()
        default: break
        }
        
    }
}


extension Remote: ClientErrorDelegate {
    //MARK: didCatchError
    public func didCatchError(_ error: Error, logger: Logger, file: StaticString, line: Int) {
        print(DEBUG_TAG+"ERROR: Error caught: \(error)")
        print(DEBUG_TAG+"ERROR: file: \(file)")
        print(DEBUG_TAG+"ERROR: line: \(line)")
    }
    
    
    
    
}
