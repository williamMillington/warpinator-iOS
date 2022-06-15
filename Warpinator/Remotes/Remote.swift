//
//  Remote.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-03.
//

import UIKit

import NIO
import NIOSSL
import Network

import GRPC
import Logging




// MARK: Remote Details
struct RemoteDetails {
    enum ConnectionStatus: String {
        case OpeningConnection, FetchingCredentials, AquiringDuplex
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










//
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
        
        print(DEBUG_TAG+"Starting connection...")
        
        duplexAttempts = 0
        transientFailureCount = 0
        
        if let certificate = authenticationCertificate {
            connect(withCertificate: certificate)
        } else {
//            obtainCertificate()
            
            if details.api == "1" { // API_V1
                authenticationConnection = UDPConnection(onEventLoopGroup: eventloopGroup!,
                                     endpoint: details.endpoint)
            } else { // API_V2
                authenticationConnection = GRPCConnection(onEventLoopGroup: eventloopGroup!,
                                      details: details)
            }
            
            authenticationConnection?.requestCertificate()?.whenComplete { result in
                switch result {
                case .success(let info):
                    
                    self.details.ipAddress = info.address
                    self.details.port = info.port
                    
                    self.connect(withCertificate: info.certificate)
                    
                    self.authenticationConnection = nil
                    
                case .failure(let error): print(self.DEBUG_TAG+"Failed to connect \(error)")
                }
            }
            
        }
    }
    
    
    //
    // MARK: connect
    func connect(withCertificate certificate: NIOSSLCertificate) {
        
        authenticationCertificate = certificate
        
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
        
        
        let hostname =  details.ipAddress
        let port = details.port
        
        print(self.DEBUG_TAG+"creating channel for \(hostname):\(port)")
        channel = channelBuilder.connect(host: hostname, port: port)
            
        warpClient = WarpClient(channel: channel!)
        
        let duplexFuture = aquireDuplex()
        
        duplexFuture.whenComplete(){ result in
            
            switch result {
            case .success(let haveDuplex):
                print(self.DEBUG_TAG+" haveDuplex result: \(haveDuplex.response) (attempt:  \(self.duplexAttempts))")
                
                if haveDuplex.response {
                    self.details.status = .Connected
                    self.retrieveRemoteInfo()
                }
                
            case .failure(let error):
                print(self.DEBUG_TAG+"duplex not established")
                print(self.DEBUG_TAG+"\t\t error: \(error)")
                
                    _ = self.disconnect( DuplexError.DuplexNotEstablished )
                
            }
        }
        
    }
    
    
    
    
    //
    // MARK: disconnect
    func disconnect(_ error: Error? = nil) -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+"disconnecting remote...")
        print(DEBUG_TAG+"\twith error: \( String(describing:error) )")
        
        
        guard let channel = channel else {
            print(DEBUG_TAG+"\tremote already disconnected")
            return eventloopGroup!.next().makeSucceededVoidFuture()
        }
        
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
        
        
        
        let future = channel.close()
        
        future.whenComplete { response in
            
            switch response {
                case .success(_): print(self.DEBUG_TAG + "\t\tchannel closed successfully")
                case .failure(let error): print(self.DEBUG_TAG + "\t\tchannel closed with error: \(error)")
            }
            
            self.warpClient = nil
            self.details.status = .Disconnected
        }
        
        return future
    }
    
    
    //
    // MARK: stopAllTransfers
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
    private func aquireDuplex() -> EventLoopFuture<HaveDuplex> {
        
        
        guard let warpClient = warpClient else {
            print(DEBUG_TAG+"NO CLIENT")
            return eventloopGroup!.next().makeFailedFuture( DuplexError.UnknownRemote )
        }
        
        details.status = .AquiringDuplex
        
        duplexAttempts += 1
        
        print(DEBUG_TAG+"acquiring duplex, attempt: \(duplexAttempts)")
//        let options = CallOptions(logger: logger)
        
        var duplex: UnaryCall<LookupName, HaveDuplex>
        if details.api == "1" {
            duplex = warpClient.checkDuplexConnection(lookupName)//, callOptions: options)
        } else {
            duplex = warpClient.waitingForDuplex(lookupName)//, callOptions: options)
        }
        
        
        return duplex.response.flatMapThrowing { haveDuplex in
            
            // throw error if duplex wasn't established, despite a successful call
            if !haveDuplex.response {
                throw DuplexError.DuplexNotEstablished
            }
            return haveDuplex
        }.flatMapError { error in
            
            guard self.duplexAttempts < 10 else {
                return self.eventloopGroup!.next().makeFailedFuture(error)
            }
            
            return self.eventloopGroup!.next().flatScheduleTask(in: .seconds(2)  ) {
                return self.aquireDuplex()
            }.futureResult
            
        }
    }

    
    //
    // MARK: Ping
    public func ping() ->EventLoopFuture<Void> {
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection")
            return eventloopGroup!.next().makeFailedFuture( NSError() )
        }
        
        print(DEBUG_TAG+"pinging")
        
        return client.ping(lookupName).response.map { _ in
            return // transforms "VoidType" into regular swift-type "Void"
        }
    }
    
    
    // MARK: remoteInfo
    func retrieveRemoteInfo(){
        
        print(DEBUG_TAG+"Retrieving information from \(details.hostname)")
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"\t no client connection")
            return //eventloopGroup!.next().makeFailedFuture( NSError() )
        }
        
        // get info
        let infoCallFuture = client.getRemoteMachineInfo(lookupName).response
        
        infoCallFuture.whenComplete { result in
            
            switch result {
            case .success(let info):
                self.details.displayName = info.displayName
                self.details.username = info.userName
                self.details.status = .Connected
                
                print(self.DEBUG_TAG+"Remote display name: \(self.details.displayName)")
                print(self.DEBUG_TAG+"Remote username: \(self.details.username)")
            case .failure(let error):
                print(self.DEBUG_TAG+"failed to retrieve machine info \n\t\t error: \(error)")
            }
            
        }
        
        // holder for avatar bytes
        var avatarBytes: Data = Data()
        
        let imageCallFuture = client.getRemoteMachineAvatar(lookupName) { avatar in
            avatarBytes.append( avatar.avatarChunk ) // store each chunk as it comes
        }.status
        
        imageCallFuture.whenComplete { result in
            
            switch result {
            case .success(_):
                
                // assemble bytes into uiimage
                self.details.userImage = UIImage(data:  avatarBytes  )
                self.informObserversInfoDidChange()
                
            case .failure(let error):
                print(self.DEBUG_TAG+"failed to retrieve remote avatar")
                print(self.DEBUG_TAG+"\t\t error: \(error)")
            }
            
        }
    }
}





//
// MARK: - Transfers
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
    // MARK: stop Transfer
    func requestStop(forOperationWithUUID uuid: UInt64, error: Error?) {
        
        print(DEBUG_TAG+"callClientStopTransfer")
        
        if let op = findTransferOperation(for: uuid) {
            
            let stopInfo: StopInfo = .with {
                $0.info = op.operationInfo
                $0.error = (error != nil)
            }
            
            let result = warpClient?.stopTransfer(stopInfo)
            result?.response.whenComplete { result in
                print(self.DEBUG_TAG+"request to stop transfer had result: \(result)")
            }
        } else {
            print(DEBUG_TAG+"Couldn't find operation: \(uuid)")
        }
    }
    
    
    
    //
    // MARK: Decline Receive Request
    func informOperationWasDeclined(forUUID uuid: UInt64, error: Error? = nil) {
        
        if let op = findTransferOperation(for: uuid) {
            
            let result = warpClient?.cancelTransferOpRequest(op.operationInfo)
            result?.response.whenComplete { result in
                print(self.DEBUG_TAG+"request to cancel transfer had result: \(result)")
            }
            
        } else {
            print(DEBUG_TAG+"error trying to find operation for UUID: \(uuid)")
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
//            requestStop(forOperationWithUUID: operation.UUID, error: TransferError.ConnectionInterrupted )
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
                case .failure(let error): _ = self.disconnect(error) // if connection is dead, signal disconnect
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
                case .failure(let error): _ = self.disconnect(error) // if connection is dead, signal disconnect
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
    // MARK: add
    func addObserver(_ model: ObservesRemote){
        observers.append(model)
    }
    
    //
    // MARK: remove
    func removeObserver(_ model: ObservesRemote){
        
        for (i, observer) in observers.enumerated() {
            if observer === model {
                observers.remove(at: i)
            }
        }
    }
    
    //
    // MARK: inform info changed
    func informObserversInfoDidChange(){
        observers.forEach { observer in
            observer.infoDidUpdate()
        }
    }
    
    //
    // MARK: inform op added
    func informObserversOperationAdded(_ operation: TransferOperation){
        observers.forEach { observer in
            observer.operationAdded(operation)
        }
    }
    
}








//
// MARK: connectivity
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
            
            print(DEBUG_TAG+"\tTransientFailure #\(transientFailureCount)")
            
            if transientFailureCount == 10 {
                _ = disconnect( AuthenticationError.ConnectionError )
            }
//        case .idle:
//            details.status = .Idle
//        case .shutdown:  _ = disconnect()
        default: break
        }
        
    }
}





//
// MARK: ClientErrorDelegate
extension Remote: ClientErrorDelegate {
    
    //
    // MARK: caught error
    public func didCatchError(_ error: Error, logger: Logger, file: StaticString, line: Int) {
        
        print(DEBUG_TAG+"ERROR (\(file):\(line)): \(error)")
        
        // if certificate is bad
        if case NIOSSLError.handshakeFailed(_) = error {
            print(DEBUG_TAG+"Handshake error, bad cert: \(error)")
            authenticationCertificate = nil
            
            _ = disconnect()
            startConnection()
        } else {
            print(DEBUG_TAG+"Unknown error: \(error)")
        }
    }
}




//
// MARK: - Authentication
extension Remote {
    func getAuthenticationConnection() -> AuthenticationConnection {
        if details.api == "1" { // API_V1
            return UDPConnection(onEventLoopGroup: eventloopGroup!,
                                 endpoint: details.endpoint)
        } else { // API_V2
            return GRPCConnection(onEventLoopGroup: eventloopGroup!,
                                  details: details)
        }
    }
    
}


