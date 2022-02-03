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
import Logging


//MARK: Remote Details
struct RemoteDetails {
    enum ConnectionStatus: String {
        case OpeningConnection, FetchingCredentials, AquiringDuplex, DuplexAquired
        case Error
        case Connected, Idle, Disconnected
    }
    
    static let NO_IP_ADDRESS = "No_IPAddress"
    
    lazy var DEBUG_TAG: String = "RemoteDetails (hostname: \"\(hostname)\"): "
    
    var endpoint: NWEndpoint
    
    var displayName: String = "Name"
    var username: String = "username"
    var userImage: UIImage?
    
    var hostname: String = "hostname"
    var ipAddress: String = RemoteDetails.NO_IP_ADDRESS
    var port: Int = 0 //"No_Port"
    var authPort: Int = 0 //"No_Auth_Port"
    
    var uuid: String = "NO_UUID"
    var api: String = "1"
    
    var status: ConnectionStatus = .Disconnected
    
    var serviceAvailable: Bool = false
    
}

extension RemoteDetails {
    static var MOCK_DETAILS: RemoteDetails = {
        let mockEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("So.me.Ho.st") ,
                                               port: NWEndpoint.Port(integerLiteral: 8080))
        let mock = RemoteDetails(DEBUG_TAG: "MoCkReMoTe",
                                 endpoint: mockEndpoint,
                                 displayName: "mOcK ReMoTe",
                                 username: "mOcK uSeR",
                                 hostname: "mOcK hOsT",
                                 ipAddress: "Som.eAd.dre.ss",
                                 port: 8080,
                                 authPort: 8081,
                                 uuid: "mOcK uUiD",
                                 api: "2",
                                 status: .Disconnected,
                                 serviceAvailable: false)
        return mock
    }()
}












// MARK: -
// MARK: - Remote
public class Remote {
    
    lazy var DEBUG_TAG: String = "REMOTE (hostname: \"\(details.hostname)\"): "
    
    var details: RemoteDetails {
        didSet {  informObserversInfoDidChange()  }
    }
    
    var sendingOperations: [SendFileOperation] = []
    var receivingOperations: [ReceiveFileOperation] = []
    
    var channel: ClientConnection?
    var warpClient: WarpClient?
    
    var eventloopGroup: EventLoopGroup?
    
    
    var authenticationConnection: AuthenticationConnection?
    var authenticationCertificate: NIOSSLCertificate?
    
    
    var observers: [ObservesRemote] = []
    
    var transientFailureCount: Int = 0
    var duplexAttempts: Int = 0
    
    
    var logger: Logger {
        var logger = Logger(label: "warpinator.Remote", factory: StreamLogHandler.standardOutput)
        logger.logLevel = .debug
        return logger }
    
    
    var lookupName: LookupName {
        return LookupName.with {
            $0.id =  SettingsManager.shared.uuid
            $0.readableName = SettingsManager.shared.displayName
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
    
    
    //
    // MARK: startConnection
    func startConnection(){
        
        duplexAttempts = 0
        transientFailureCount = 0
        
        if let certificate = authenticationCertificate {
            connect(withCertificate: certificate)
        } else {
//            
//            if  details.api == "2" && (details.ipAddress == RemoteDetails.NO_IP_ADDRESS) {
//                print(DEBUG_TAG+"Remote does not yet have an IP Address")
//                return
//            }
            
            obtainCertificate()
        }
    }
    
    
    //
    //MARK: connect
    func connect(withCertificate certificate: NIOSSLCertificate){
        
        guard let eventloopGroup = eventloopGroup else {
            print(DEBUG_TAG+"No eventloopGroup")
            return
        }
        
        details.status = .OpeningConnection

        var keepalive = ClientConnectionKeepalive()
        keepalive.permitWithoutCalls = true
        
        let channelBuilder = ClientConnection.usingTLSBackedByNIOSSL(on: eventloopGroup)
            .withTLS(trustRoots: .certificates([certificate]) )
            .withKeepalive(keepalive)
            .withConnectivityStateDelegate(self)
            .withErrorDelegate(self)
//            .withBackgroundActivityLogger(logger)
        
        
        
//        let hostname = "192.168.50.42"
        let hostname =  details.ipAddress
        
        let port = details.port
        
        print(self.DEBUG_TAG+"creating channel for \(hostname):\(port)")
        channel = channelBuilder.connect(host: hostname, port: port)
            
        warpClient = WarpClient(channel: channel!)
        
        details.status = .AquiringDuplex
        aquireDuplex()
    }
    
    
    
    
    //
    // MARK: disconnect
    func disconnect(_ error: Error? = nil){
        print(self.DEBUG_TAG+"channel disconnected")
        
        // stop all transfers
        for operation in sendingOperations {
            if [.TRANSFERRING, .INITIALIZING, .WAITING_FOR_PERMISSION].contains(operation.status) {
                operation.orderStop(TransferError.ConnectionInterrupted)
            }
        }
        for operation in receivingOperations {
            if [.TRANSFERRING, .INITIALIZING].contains(operation.status) {
                operation.orderStop( TransferError.ConnectionInterrupted )
            }
        }
        
        warpClient = nil
        let _ = channel?.close()
        
        if let error = error {
            print(DEBUG_TAG+"with error: \(error)")
        }
        
        details.status = .Disconnected
        
    }
    
    
    //
    //
    func stopAllTransfers(forStatus status: TransferDirection){
        
        if status == .SENDING {
            for operation in sendingOperations {
                if [.TRANSFERRING, .INITIALIZING, .WAITING_FOR_PERMISSION].contains(operation.status) {
                    operation.orderStop(TransferError.ConnectionInterrupted)
                }
            }
        } else {
            for operation in receivingOperations {
                if [.TRANSFERRING, .INITIALIZING].contains(operation.status) {
                    operation.orderStop( TransferError.ConnectionInterrupted )
                }
            }
        }
    }
}






//
// MARK: - Duplex
extension Remote {
    
    
    //
    // MARK: acquireDuplex
    private func aquireDuplex(){
        
        duplexAttempts += 1
        
        print(DEBUG_TAG+"acquiring duplex, attempt: \(duplexAttempts)")
//        let options = CallOptions(logger: logger)
        
        var duplex: UnaryCall<LookupName, HaveDuplex>?
        if details.api == "1" {
            duplex = warpClient?.checkDuplexConnection(lookupName)//, callOptions: options)
        } else {
            duplex = warpClient?.waitingForDuplex(lookupName)//, callOptions: options)
        }
        
        
        duplex?.response.whenComplete { result in
            
            // check for success
            do {
                let haveDuplex = try result.get()
                
                print(self.DEBUG_TAG+"haveDuplex result is \(haveDuplex.response)")
                
                // if acquired
                if haveDuplex.response {
                    
                    print(self.DEBUG_TAG+"duplex verified after \(self.duplexAttempts) attempts")
                    
                    self.details.status = .DuplexAquired
                    self.retrieveRemoteInfo() // retreive
                    
                    return
                }
                
            } catch  {
                print(self.DEBUG_TAG+"did not establish duplex -> \(error)")
            }
            
            
            // check number of tries (10)
            guard self.duplexAttempts < 10 else {
                print(self.DEBUG_TAG+"unable to establish duplex")
                self.disconnect( DuplexError.DuplexNotEstablished )
                return
            }
            
            
            // try again in 2 seconds
            print(self.DEBUG_TAG+"\ttrying again...")
            self.duplexQueue.asyncAfter(deadline: .now() + 2) {
                self.aquireDuplex()
            }
            
        }
    }
}


//
// MARK: -
extension Remote {
    
    //
    // MARK: Ping
    public func ping(){
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        
//        if sendingOperations.count == 0 {
            
            print(self.DEBUG_TAG+"pinging")
            
            let pingResponse = client.ping(self.lookupName) //, callOptions: calloptions)
            
            pingResponse.response.whenFailure { _ in
                print(self.DEBUG_TAG+"ping failed")
//                self.details.status = .Disconnected
            }
//        }
        
        // ping again in 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.details.status == .Connected {
                self.ping()
            }
        }
    }
    
    
    // MARK: getRemoteInfo
    func retrieveRemoteInfo(){
        
        print(DEBUG_TAG+"Retrieving information from \(details.hostname)")
        
        // get info
        let infoCall = warpClient?.getRemoteMachineInfo(lookupName)
        
        infoCall?.response.whenSuccess { info in
            self.details.displayName = info.displayName
            self.details.username = info.userName
            self.details.status = .Connected
            
            print(self.DEBUG_TAG+"Remote display name: \(self.details.displayName)")
            print(self.DEBUG_TAG+"Remote username: \(self.details.username)")
        }
        infoCall?.response.whenFailure { error in
            print(self.DEBUG_TAG+"failed to retrieve machine info")
        }
        
        
        
        // get image
        var avatarBytes: Data = Data()
        
        let imageCall = warpClient?.getRemoteMachineAvatar(lookupName) { avatar in
            print(self.DEBUG_TAG+"avatar chunk is \(avatar.avatarChunk.count) bytes long")
            avatarBytes.append( avatar.avatarChunk )
        }
        
        imageCall?.status.whenSuccess { status in
            print(self.DEBUG_TAG+"retrieved avatar, status \(status)")
//            print(self.DEBUG_TAG+"image bytes are \(avatarBytes)")
            self.details.userImage = UIImage(data:  avatarBytes  )
//            print(self.DEBUG_TAG+"image is \(self.details.userImage)")
            self.informObserversInfoDidChange()
        }
        
        imageCall?.status.whenFailure { error in
            print(self.DEBUG_TAG+"failed to retrieve remote avatar")
        }
        
    }
}





//
// MARK: - Transfers Common
extension Remote {
    
    //
    // MARK: find transfer operation
    func findTransferOperation(for uuid: UInt64) -> TransferOperation? {
        
        if let operation = findReceiveOperation(withStartTime: uuid) {
            return operation  }
        
        if let operation = findSendOperation(withStartTime: uuid){
            return operation  }
        
        return nil
    }
    
    //
    // MARK: Stop Transfer
    func callClientStopTransfer(_ operation: TransferOperation, error: Error?) {
        
        print(DEBUG_TAG+"callClientStopTransfer")
        
        if let op = findTransferOperation(for: operation.UUID) {
            
            let stopInfo: StopInfo = .with {
                $0.info = op.operationInfo
                $0.error = (error != nil)
            }
            
            let result = warpClient?.stopTransfer(stopInfo)
            result?.response.whenComplete { result in
                print(self.DEBUG_TAG+"request to stop transfer had result: \(result)")
            }
        } else {
            print(DEBUG_TAG+"Couldn't find operation: \(operation)")
        }
    }
    
    
    //
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





//
//MARK: - Receive operations
extension Remote {
    
    //
    // MARK: add
    func addReceivingOperation(_ operation: ReceiveFileOperation){
        
        operation.owningRemote = self
        
        receivingOperations.append(operation)
        informObserversOperationAdded(operation)
        
        operation.status = .WAITING_FOR_PERMISSION
    }
    
    
    //
    // MARK: find
    func findReceiveOperation(withStartTime time: UInt64 ) -> ReceiveFileOperation? {
        for operation in receivingOperations {
            if operation.timestamp == time {
                return operation
            }
        }
        return nil
    }
    
    //
    //MARK: start
    func callClientStartTransfer(for operation: ReceiveFileOperation){
        
        print(DEBUG_TAG+"callClientStartTransfer ")
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"cancel receiving; no client connection "); return
        }
        
        // ping to wake up before sending, if idle
        guard details.status != .Idle else {
            
            let result = client.ping(lookupName)
            
            result.response.whenComplete { result in
                switch result {
                case .success(_):
                    self.details.status = .Connected
                    operation.startReceive(usingClient: client) // if still connected, proceed with sending
                case .failure(let error): self.disconnect(error)          // if connection is dead, signal disconnect
                }
            }
            return
        }
        
        
        operation.startReceive(usingClient: client)
        
    }
}




//
// MARK: - Sending operations
extension Remote {
    
    //
    // MARK: add
    func addSendingOperation(_ operation: SendFileOperation){
        
        operation.owningRemote = self
        
        sendingOperations.append(operation)
        informObserversOperationAdded(operation)
        
        operation.status = .WAITING_FOR_PERMISSION

    }
    
    //
    // MARK: find
    func findSendOperation(withStartTime time: UInt64 ) -> SendFileOperation? {
        for operation in sendingOperations {
            if operation.timestamp == time {
                return operation
            }
        }
        return nil
    }
    
    
    //
    // MARK: send
    // create sending operation from selection of files
    func sendFiles(_ selections: [TransferSelection]){
        
        let operation = SendFileOperation(for: selections) 

        addSendingOperation(operation)
        sendRequest(toTransfer: operation)
        
    }
    
    //
    // send client a message that we have files we want to send
    func sendRequest(toTransfer operation: SendFileOperation ){
        
        print(DEBUG_TAG+"Sending request: \(operation.transferRequest)")
        
        // check if we're connected
        guard let client = warpClient else {
            print(DEBUG_TAG+"cancelled sending; no client connection"); return
        }
        
        // ping to wake up before sending, if idle
        guard details.status != .Idle else {
            
            let result = client.ping(lookupName)
            
            result.response.whenComplete { result in
                switch result {
                case .success(_):
                    self.details.status = .Connected
                    self.sendRequest(toTransfer: operation) // if still connected, proceed with sending
                case .failure(let error): self.disconnect(error)          // if connection is dead, signal disconnect
                }
            }
            return
        }
        
        
        let response = client.processTransferOpRequest(operation.transferRequest)
        
        response.response.whenComplete { result in
            print(self.DEBUG_TAG+"process request completed; result: \(result)")
        }
        
    }
}





//MARK: - observers
extension Remote {
    
    //
    //
    func addObserver(_ model: ObservesRemote){
        observers.append(model)
    }
    
    //
    //
    func removeObserver(_ model: ObservesRemote){
        
        for (i, observer) in observers.enumerated() {
            if observer === model {
                observers.remove(at: i)
            }
        }
    }
    
    //
    //
    func informObserversInfoDidChange(){
        observers.forEach { observer in
            observer.infoDidUpdate()
        }
    }
    
    //
    //
    func informObserversOperationAdded(_ operation: TransferOperation){
        observers.forEach { observer in
            observer.operationAdded(operation)
        }
    }
    
}









//MARK: ConnectivityStateDelegate
extension Remote: ConnectivityStateDelegate {
    
    
    //
    //MARK: - connectivityStateDidChange
    public func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
        print(DEBUG_TAG+"channel state has moved from \(oldState) to \(newState)".uppercased())
        switch newState {
        case .ready:
            transientFailureCount = 0;
            print(DEBUG_TAG+"channel ready")
        case .transientFailure:
            transientFailureCount += 1
            
//            stopAllTransfers(forStatus: .SENDING)
//            stopAllTransfers(forStatus: .RECEIVING)
            
            print(DEBUG_TAG+"\tTransientFailure #\(transientFailureCount)")
            if transientFailureCount == 10 {
                disconnect( AuthenticationError.ConnectionError )
            }
        case .idle:
            details.status = .Idle
        case .shutdown: disconnect()
        default: break
        }
        
    }
}



extension Remote: ClientErrorDelegate {
    
    //
    // MARK: handle bad certificate
    public func didCatchError(_ error: Error, logger: Logger, file: StaticString, line: Int) {
        
        // if bad cert, discard certificate and retry
        if case NIOSSLError.handshakeFailed(_) = error {
            print(DEBUG_TAG+"Handshake error, bad cert: \(error)")
            authenticationCertificate = nil
            
            disconnect()
            startConnection()
        } else {
            print(DEBUG_TAG+"Unknown error: \(error)")
        }
    }
}





//
// MARK: - Authentication
extension Remote: AuthenticationRecipient {
    
    //
    // MARK: fetch cert
    func obtainCertificate(){
        
        if details.api == "1" { // API_V1
            authenticationConnection = UDPConnection(details, manager: self)
        } else { // API_V2
            authenticationConnection = GRPCConnection(details, manager: self)
        }
        
        authenticationConnection?.requestCertificate()
    }
    
    //
    // MARK: success
    func authenticationCertificateObtained(forRemote details: RemoteDetails, certificate: NIOSSLCertificate){
        
        print(DEBUG_TAG+"certificate retrieved")
        self.details = details
        authenticationCertificate = certificate
        
        connect(withCertificate: certificate)
    }
    
    //
    // MARK: failure
    func failedToObtainCertificate(forRemote details: RemoteDetails, _ error: AuthenticationError){
        print(DEBUG_TAG+"failed to retrieve certificate, error: \(error)")
    }
}


