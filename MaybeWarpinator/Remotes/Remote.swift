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
struct RemoteDetails {
    enum ConnectionStatus: String {
        case OpeningConnection, FetchingCredentials, AquiringDuplex, DuplexAquired
        case Error
        case Connected, Disconnected
    }
    
    static var MOCK_DETAILS: RemoteDetails = {
        let mockEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("So.me.Ho.st") ,
                                               port: NWEndpoint.Port(integerLiteral: 8080))
        let mock = RemoteDetails(DEBUG_TAG: "MoCkReMoTe",
                                 endpoint: mockEndpoint,
                                 displayName: "mOcK ReMoTe",   username: "mOcK uSeR",
                                 serviceName: "MoCk SeRvIcE",  hostname: "mOcK hOsT",  ipAddress: "Som.eAd.dre.ss",
                                 port: 8080,   authPort: 8081,
                                 uuid: "mOcK uUiD",  api: "2",
                                 status: .Disconnected,  serviceAvailable: false)
        return mock
    }()
    
    
    lazy var DEBUG_TAG: String = "RemoteDetails (hostname: \"\(hostname)\"): "
    
    var endpoint: NWEndpoint
    
    var displayName: String = "No_DisplayName"
    var username: String = "No_Username"
    
    
    var serviceName: String = "No_ServiceName"
    var hostname: String = "No_Hostname"
    var ipAddress: String = "No_IPAddress"
    var port: Int = 0 //"No_Port"
    var authPort: Int = 0 //"No_Auth_Port"
    
    var uuid: String = "NO_UUID"
    var api: String = "1"
    
    var status: ConnectionStatus = .Disconnected
    
    var serviceAvailable: Bool = false
    
}






// MARK: - Remote
public class Remote {
    
    lazy var DEBUG_TAG: String = "REMOTE (hostname: \"\(details.hostname)\"): "
    
    var details: RemoteDetails {
        didSet {
            self.informObserversInfoDidChange()
        }
    }
    
    public var picture: UIImage?
    
    var sendingOperations: [SendFileOperation] = []
    var receivingOperations: [ReceiveFileOperation] = []
    
    var channel: ClientConnection?
    var warpClient: WarpClientProtocol?
    
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 5) //GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    
    var authenticationConnection: AuthenticationConnection?
    var authenticationCertificate: NIOSSLCertificate?
    
    
    var observers: [RemoteViewModel] = []
    
    var transientFailureCount: Int = 0
    var duplexAttempts: Int = 0
    
    
    var logger: Logger {
        var logger = Logger(label: "warpinator.Remote", factory: StreamLogHandler.standardOutput)
        logger.logLevel = .debug
        return logger }
    
    
    var lookupName: LookupName {
        return LookupName.with {
            $0.id =  Server.SERVER_UUID
            $0.readableName = "Warpinator iOS"
        }
    }
    
    
    lazy var duplexQueueLabel = "Duplex_\(details.uuid)"
    lazy var duplexQueue = DispatchQueue(label: duplexQueueLabel, qos: .userInitiated)
    
    
    init(details: RemoteDetails){
        self.details = details
        
    }
    
    init(details: RemoteDetails, certificate: NIOSSLCertificate){
        self.details = details
        authenticationCertificate = certificate
    }
    
    
    func startConnection(){
        
        duplexAttempts = 0
        transientFailureCount = 0
        
        if let certificate = authenticationCertificate {
            connect(withCertificate: certificate)
        } else {
            obtainCertificate()
        }
    }
    
    
    //MARK: connect
    func connect(withCertificate certificate: NIOSSLCertificate){
        
        details.status = .OpeningConnection
        
        var keepalive = ClientConnectionKeepalive()
        keepalive.permitWithoutCalls = true
        
        let channelBuilder = ClientConnection.usingTLSBackedByNIOSSL(on: group)
            .withTLS(trustRoots: .certificates([certificate]) )
            .withKeepalive(keepalive)
            .withConnectivityStateDelegate(self)
            .withErrorDelegate(self)
//            .withBackgroundActivityLogger(logger)
        
        
        // primitive check for android app, which will not accept hostname connections
        let hostname: String
        if details.api == "1" {
            hostname = details.ipAddress
        } else {
            hostname = details.hostname
        }
        
        let port = details.port
        
        print(self.DEBUG_TAG+"creating channel for \(hostname):\(port)")
        channel = channelBuilder.connect(host: hostname, port: port)
            
        warpClient = WarpClient(channel: channel!)
        
        details.status = .AquiringDuplex
        aquireDuplex()
    }
    
    
    
    
    
    // MARK: onDisconnect
    func channelDidDisconnect(_ error: Error? = nil){
        print(self.DEBUG_TAG+"channel disconnected")
        
        // stop all transfers
        for operation in sendingOperations {
            let cancelStates: [TransferStatus] = [.TRANSFERRING, .INITIALIZING, .WAITING_FOR_PERMISSION]
            if cancelStates.contains(operation.status) {
                operation.orderStop(TransferError.ConnectionInterrupted)
            }
        }
        for operation in receivingOperations {
            let cancelStates: [TransferStatus] = [.TRANSFERRING, .INITIALIZING]
            if cancelStates.contains(operation.status) {
                operation.orderStop( TransferError.ConnectionInterrupted )
            }
        }
        
        warpClient = nil
        let _ = channel?.close()
        
        if let error = error {
            print(DEBUG_TAG+"with error: \(error)")
        } else {
            details.status = .Disconnected
        }
    }
    
}







//MARK: - Duplex
extension Remote {
    
    
    // MARK: acquireDuplex
    private func aquireDuplex(){
        
        duplexAttempts += 1
        
        print(DEBUG_TAG+"acquiring duplex, attempt: \(duplexAttempts)")
        
        var duplex: UnaryCall<LookupName, HaveDuplex>?
        if details.api == "1" {
            duplex = warpClient?.checkDuplexConnection(lookupName)
        } else {
            duplex = warpClient?.waitingForDuplex(lookupName)
        }
        
        
        duplex?.response.whenComplete { result in
            
            do {
                let haveDuplex = try result.get()
                
                if haveDuplex.response {
                    self.onDuplexAquired();  return
                }
                print(self.DEBUG_TAG+"duplex not acquired")
                
            } catch  {
                self.onDuplexFail(error)
            }
            
            
            // 10 tries
            guard self.duplexAttempts < 10 else {
                self.onDuplexFail( DuplexError.DuplexNotEstablished )
                return
            }
            
            print(self.DEBUG_TAG+"\ttrying again...")
            // try again in 2 seconds
            self.duplexQueue.asyncAfter(deadline: .now() + 2) {
                self.aquireDuplex()
            }
            
        }
    }
    
    
    // MARK: onDuplexAquired
    private func onDuplexAquired(){
        
        print(self.DEBUG_TAG+"duplex verified after \(duplexAttempts) attempts")
        
        details.status = .DuplexAquired
        
        retrieveRemoteInfo()
    }
    
    
    //MARK: onDuplexFail
    func onDuplexFail(_ error: Error ){
        print(DEBUG_TAG+"unable to establish duplex")
        channelDidDisconnect(error)
    }
    
}





//MARK: -
extension Remote {
    
    // MARK: Ping
    public func ping(){
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        // if we're currently transferring something, no need to ping.
        if sendingOperations.count == 0 {
            
            print(self.DEBUG_TAG+"pinging")
            
            let pingResponse = client.ping(self.lookupName) //, callOptions: calloptions)
            
            pingResponse.response.whenFailure { _ in
                print(self.DEBUG_TAG+"ping failed")
//                self.details.status = .Disconnected
            }
        }
        
        // ping again in 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.details.status == .Connected {
                self.ping()
            }
        }
    }
    
    
    //MARK: retrieveRemoteInfo
    func retrieveRemoteInfo(){
        
        print(DEBUG_TAG+"Retrieving information from \(details.hostname)")
        
        let info = warpClient?.getRemoteMachineInfo(lookupName)
        
        info?.response.whenSuccess { info in
            self.details.displayName = info.displayName
            self.details.username = info.userName
            self.details.status = .Connected
            
            print(self.DEBUG_TAG+"Remote display name: \(self.details.displayName)")
            print(self.DEBUG_TAG+"Remote username: \(self.details.username)")
        }
        info?.response.whenFailure { error in
            print(self.DEBUG_TAG+"failed to retrieve machine info")
        }
        
    }
}






//MARK: - Transfers Common
extension Remote {
    
    
    
    //MARK: find transfer operation
    func findTransferOperation(for uuid: UInt64) -> TransferOperation? {
        
        if let operation = findReceiveOperation(withStartTime: uuid) {
            return operation
        }
        
        if let operation = findSendOperation(withStartTime: uuid){
            return operation
        }
        
        return nil
    }
    
    // MARK: Stop Transfer
    func callClientStopTransfer(_ operation: TransferOperation, error: Error?) {
        
        if let op = findTransferOperation(for: operation.UUID) {
            
            let info = op.operationInfo
            
            let stopInfo: StopInfo = .with {
                $0.info = info
                $0.error = (error != nil)
            }
            
            let result = warpClient?.stopTransfer(stopInfo)
            result?.response.whenComplete { result in
                print(self.DEBUG_TAG+"request to stop transfer had result: \(result)")
            }
        } else {
            print(DEBUG_TAG+"error trying to find operation: \(operation)")
        }
    }
    
    
    // MARK: Decline Receive Request
    func callClientDeclineTransfer(_ operation: TransferOperation, error: Error? = nil) {
        
        if let op = findTransferOperation(for: operation.UUID) {
            
            let result = warpClient?.cancelTransferOpRequest(op.operationInfo)
            result?.response.whenComplete { result in
                print(self.DEBUG_TAG+"request to cancel transfer had result: \(result)")
            }
            
        } else {
            print(DEBUG_TAG+"error trying to find operation: \(operation)")
        }
    }
    
}






//MARK: - Receive operations
extension Remote {
    
    
    // MARK: add
    func addReceivingOperation(_ operation: ReceiveFileOperation){
        
        operation.owningRemote = self
        
        receivingOperations.append(operation)
        informObserversOperationAdded(operation)
        
        operation.status = .WAITING_FOR_PERMISSION
    }
    
    // MARK: find
    func findReceiveOperation(withStartTime time: UInt64 ) -> ReceiveFileOperation? {
        for operation in receivingOperations {
            if operation.startTime == time {
                return operation
            }
        }
        return nil
    }
    
    //MARK: begin
    func callClientStartTransfer(for operation: ReceiveFileOperation){
        
//        let operationInfo = OpInfo.with {
//            $0.ident = Server.SERVER_UUID
//            $0.timestamp = operation.startTime
//            $0.readableName = Server.SERVER_UUID
//            $0.useCompression = false
//        }
        
        print(DEBUG_TAG+"callClientStartTransfer ")
        let operationInfo = operation.operationInfo
        let handler = operation.receiveHandler
        
        
        let dataStream = warpClient?.startTransfer(operationInfo, handler: handler)
        
        
        dataStream?.status.whenSuccess{ status in
            
            print(self.DEBUG_TAG+"transfer finished successfully with status \(status)")
            
            operation.finishReceive()
        }
        
        dataStream?.status.whenFailure{ error in
            operation.receiveWasCancelled()
            print(self.DEBUG_TAG+"transfer failed: \(error)")
        }
    }
}





// MARK: - Sending operations
extension Remote {
    
    
    // MARK: add
    func addSendingOperation(_ operation: SendFileOperation){
        
        operation.owningRemote = self
        
        sendingOperations.append(operation)
        informObserversOperationAdded(operation)
        
        operation.status = .WAITING_FOR_PERMISSION

    }
    
    
    // MARK: find
    func findSendOperation(withStartTime time: UInt64 ) -> SendFileOperation? {
        for operation in sendingOperations {
            if operation.startTime == time {
                return operation
            }
        }
        return nil
    }
    
    //MARK: begin
//    func sendFile(_ filename: FileName){
//
//        let operation = SendFileOperation(for: filename)
//
//        let request: TransferOpRequest = .with {
//            $0.info = operation.operationInfo
//            $0.senderName = Server.SERVER_UUID
//            $0.size = UInt64(operation.totalSize)
//            $0.count = UInt64(operation.fileCount)
//            $0.nameIfSingle = operation.singleName
//            $0.mimeIfSingle = operation.singleMime
//            $0.topDirBasenames = operation.topDirBaseNames
//        }
//
//        print(DEBUG_TAG+"Sending request: \(request)")
//
//        addSendingOperation(operation)
//
//        let response = warpClient?.processTransferOpRequest(request)
//
//        response?.response.whenComplete { result in
//            print(self.DEBUG_TAG+"process request completed; result: \(result)")
//        }
//    }
    
    
    func sendFiles(_ filenames: [FileName]){
        
        let operation = SendFileOperation(for: filenames)
        
        let request: TransferOpRequest = .with {
            $0.info = operation.operationInfo
            $0.senderName = Server.SERVER_UUID
            $0.size = UInt64(operation.totalSize)
            $0.count = UInt64(operation.fileCount)
            $0.nameIfSingle = operation.singleName
            $0.mimeIfSingle = operation.singleMime
            $0.topDirBasenames = operation.topDirBaseNames
        }
        
        print(DEBUG_TAG+"Sending request: \(request)")
        
        addSendingOperation(operation)
        
        let response = warpClient?.processTransferOpRequest(request)
        
        response?.response.whenComplete { result in
            print(self.DEBUG_TAG+"process request completed; result: \(result)")
        }
    }
    
}





//MARK: observers
extension Remote {
    
    func addObserver(_ model: RemoteViewModel){
        observers.append(model)
    }
    
    func removeObserver(_ model: RemoteViewModel){
        
        for (i, observer) in observers.enumerated() {
            if observer === model {
                observers.remove(at: i)
            }
        }
    }
    
    func informObserversInfoDidChange(){
        observers.forEach { observer in
            observer.updateInfo()
        }
    }
    
    func informObserversOperationAdded(_ operation: TransferOperation){
        observers.forEach { observer in
            observer.transferOperationAdded(operation)
        }
    }
    
}










extension Remote: ConnectivityStateDelegate {
    
    //MARK: connectivityStateDidChange
    public func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
        print(DEBUG_TAG+"channel state has moved from \(oldState) to \(newState)".uppercased())
        switch newState {
        case .ready:
            transientFailureCount = 0;
            print(DEBUG_TAG+"channel ready")
        case .transientFailure:
            transientFailureCount += 1
            print(DEBUG_TAG+"\tTransientFailure \(transientFailureCount)")
            if transientFailureCount == 10 {
                channelDidDisconnect( RegistrationError.ConnectionError )
            }
        case .idle, .shutdown: channelDidDisconnect()
        default: break
        }
        
    }
}

extension Remote: ClientErrorDelegate {
    //MARK
    public func didCatchError(_ error: Error, logger: Logger, file: StaticString, line: Int) {
        
        // bad cert, discard and retry
        if case NIOSSLError.handshakeFailed(_) = error {
            print(DEBUG_TAG+"Handshake error, bad cert: \(error)")
            authenticationCertificate = nil
            
            channelDidDisconnect()
            startConnection()
        } else {
            print(DEBUG_TAG+"Unknown error: \(error)")
        }
    }
}



// MARK: - Authentication
extension Remote: AuthenticationRecipient {
    
    // obtainCertificate
    func obtainCertificate(){
        
        if details.api == "1" {
            authenticationConnection = UDPConnection(details, manager: self)
        } else {
            authenticationConnection = GRPCConnection(details, manager: self)
        }
        
        authenticationConnection?.requestCertificate()
    }
    
    
    // MARK: success
    func authenticationCertificateObtained(forRemote details: RemoteDetails, certificate: NIOSSLCertificate){
        
        print(DEBUG_TAG+"certificate retrieved")
        self.details = details
        authenticationCertificate = certificate
        
        connect(withCertificate: certificate)
    }
    
    // MARK: failure
    func failedToObtainCertificate(forRemote details: RemoteDetails, _ error: RegistrationError){
        print(DEBUG_TAG+"failed to retrieve certificate, error: \(error)")
    }
}


