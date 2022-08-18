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
    
    lazy var DEBUG_TAG: String = "RemoteDetails (\"\(hostname)\"): "
    
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
    
    lazy var DEBUG_TAG: String = "REMOTE (\"\(details.hostname)\"): "
    
    var details: RemoteDetails {
        didSet {  informObserversInfoDidChange()  }
    }
    
    
    enum Error: Swift.Error {
        case REMOTE_PROCESSING_ERROR
        case UNKNOWN_ERROR
    }
    
    
    
    var sendingOperations: [SendFileOperation] = []
    var receivingOperations: [ReceiveFileOperation] = []
    
    var channel: ClientConnection?
    var warpClient: WarpClient?
    
    var eventLoopGroup: EventLoopGroup
    
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
    
    
    
    init(details deets: RemoteDetails, eventLoopGroup group: EventLoopGroup){
        details = deets
        eventLoopGroup = group
    }
    
    
    //
    // MARK: +startupConnection
    @discardableResult
    func startupConnection() -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+"Initiating connection with remote...")
        
        guard ![.Connected, .AquiringDuplex ].contains( details.status ) else {     //  details.status != .Connected else {
            return eventLoopGroup.next().makeSucceededVoidFuture()
        }
        
        // return success if we're already connected, or connecting
        if let state = channel?.connectivity.state {
           
            if [.ready, .connecting].contains( state ) {
                return eventLoopGroup.next().makeSucceededVoidFuture()
            }
            
            // if idle, just ping
            if let client = warpClient,
                state == .idle {
                
//                let ping = client.ping( lookupName )
                return client.ping( lookupName ).status
                    .flatMap { status in
                        switch status { // status okay, we're still connected
                        case .ok:  return self.eventLoopGroup.next().makeSucceededVoidFuture()
                        case .processingError : return self.eventLoopGroup.next().makeFailedFuture(Remote.Error.REMOTE_PROCESSING_ERROR)
                        default: return self.eventLoopGroup.next().makeFailedFuture( Remote.Error.UNKNOWN_ERROR )
                        }
                }
                // error while pinging triggers a connection restart
                .flatMapError { error in
                    print(self.DEBUG_TAG+"ERROR pinging: \(error), assume disconnected ")
                    
                    // ensures we enter the .Disconnected state we this isn't an
                    // infinite loop
                    return self.disconnect(error)
                }.flatMap {
                    // try again! :D
                    self.startupConnection()
                }
            }
        }
        
        duplexAttempts = 0
        transientFailureCount = 0
        
        return connect()
            .flatMapError { error in
                print(self.DEBUG_TAG+"Failed to connect \(error)")
                return self.eventLoopGroup.next().makeFailedFuture(error)
            }
    }
    
    
    
    // MARK: authenticate
    private func authenticate() -> EventLoopFuture<NIOSSLCertificate> {
        
        // if we've already got the certificate, just return that
        guard let certificate = authenticationCertificate else {
            
            if details.api == "1" { // API_V1, UDP connection
                authenticationConnection = UDPConnection(onEventLoopGroup: eventLoopGroup,
                                     endpoint: details.endpoint)
            } else { // API_V2, GRPC call
                authenticationConnection = GRPCConnection(onEventLoopGroup: eventLoopGroup,
                                      details: details)
            }
            
            // Otherwise, fetch the certificate
            return authenticationConnection!.requestCertificate()
                .flatMap { info in
                    
                    self.details.ipAddress = info.address
                    self.details.port = info.port
                    
                    self.authenticationCertificate = info.certificate
                    
                    return self.eventLoopGroup.next().makeSucceededFuture(info.certificate)
                }
        }
        
        return self.eventLoopGroup.next().makeSucceededFuture(certificate)
    }
    
    
    //
    // MARK: - connect
    private func connect() -> EventLoopFuture<Void> {
        
        return authenticate() // get certificate
            .flatMap { certificate in
                
                print(self.DEBUG_TAG+"\t connecting...")
                
                self.details.status = .OpeningConnection

                var keepalive = ClientConnectionKeepalive()
                keepalive.permitWithoutCalls = true
                
                let client = ClientConnection.usingTLSBackedByNIOSSL(on: self.eventLoopGroup)
                    .withTLS(trustRoots: .certificates([certificate]) )
                    .withKeepalive(keepalive)
                    .withConnectivityStateDelegate(self)
                    .withErrorDelegate(self)
        //            .withBackgroundActivityLogger(logger)
                
                
                let hostname =  self.details.ipAddress
                let port = self.details.port
                
                print(self.DEBUG_TAG+"creating channel for \(hostname):\(port)")
                self.channel = client.connect(host: hostname, port: port)
                
                self.warpClient = WarpClient(channel: self.channel!)
                
                return self.eventLoopGroup.next().makeSucceededVoidFuture()
            }
            .flatMap {
                self.aquireDuplex()
            }
        
            // TODO: I need to create some extension methods that more transparently communicate the steps involved
        
            .flatMap { haveDuplex in // Duplex call succeeded

                print(self.DEBUG_TAG+" duplex result: \(haveDuplex.response) (attempt:  \(self.duplexAttempts))")

                // if call succeeded, but answer was 'no'
                guard haveDuplex.response else {
                    return self.eventLoopGroup.next().makeFailedFuture(DuplexError.DuplexNotEstablished)
                }

                // we're connected, get info
                self.details.status = .Connected
                return self.retrieveRemoteInfo()
            }
            .flatMapError { error in // duplex failed

                print(self.DEBUG_TAG+"duplex not established")
                print(self.DEBUG_TAG+"\t\t error: \(error)")

                _ = self.disconnect( DuplexError.DuplexNotEstablished )
                return self.eventLoopGroup.next().makeFailedFuture(error)
            }
        
    }
    
    
    
    
    //
    // MARK: disconnect
    func disconnect(_ error: Swift.Error? = nil) -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+"disconnecting remote...")
        print(DEBUG_TAG+"\twith error: \( String(describing:error) )")
        
        
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
        
        return channel?.close()
            .map { // clean up
                self.warpClient = nil
                self.details.status = .Disconnected
            }
            .flatMap { // report success
                print(self.DEBUG_TAG + "\t\t channel closed successfully")
                return self.eventLoopGroup.next().makeSucceededVoidFuture()
            }
            .flatMapError{ error in // report error, but succeed because channel is closed
                print(self.DEBUG_TAG + "\t\t channel closed with error: \(error)")
                return self.eventLoopGroup.next().makeSucceededVoidFuture()
            }
        ?? eventLoopGroup.next().makeSucceededVoidFuture()
            .flatMap {
                print(self.DEBUG_TAG + "\t\t channel was already closed")
                return self.eventLoopGroup.next().makeSucceededVoidFuture()
        }
            
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
            return eventLoopGroup.next().makeFailedFuture( DuplexError.UnknownRemote )
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
            
            // throw error if call was successful, but duplex not established
            if !haveDuplex.response {
                throw DuplexError.DuplexNotEstablished
            }
            return haveDuplex
        }.flatMapError { error in
            
            guard self.duplexAttempts < 10 else {
                return self.eventLoopGroup.next().makeFailedFuture(error)
            }
            
            // try again in 2 seconds
            return self.eventLoopGroup.next().flatScheduleTask(in: .seconds(2)  ) {
                return self.aquireDuplex()
            }.futureResult
            
        }
    }

    
    //
    // MARK: Ping
    public func ping() -> EventLoopFuture<Void> {
        
        return client()
            .flatMap { client in
                return client.ping(self.lookupName).response
            }
            .map { _ in
                print(self.DEBUG_TAG+"pinging")
        }
    }
    
    
    // MARK: remoteInfo
    func retrieveRemoteInfo() -> EventLoopFuture<Void>{
        
        print(DEBUG_TAG+"Retrieving information from \(details.hostname)")
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"\t no client connection")
            return eventLoopGroup.next().makeFailedFuture( NSError() )
        }
        
        var avatarBytes: Data = Data()
        
        // get info
        //        let infoCallFuture = client.getRemoteMachineInfo(lookupName).response
        return client.getRemoteMachineInfo(lookupName).response
            .flatMap { info in
                self.details.displayName = info.displayName
                self.details.username = info.userName
                self.details.status = .Connected
                
                print(self.DEBUG_TAG+"\t\tRetrieved display name: \(self.details.displayName)")
                print(self.DEBUG_TAG+"\t\tRetrieved username: \(self.details.username)")
                
                return client.getRemoteMachineAvatar( self.lookupName) { avatar in
                    avatarBytes.append( avatar.avatarChunk ) // store each chunk as it comes
                }.status
                
            }
            .flatMap { (status: GRPCStatus) in
                switch status {
                case .ok:
                    // assemble bytes into uiimage
                    self.details.userImage = UIImage(data:  avatarBytes  )
                    self.informObserversInfoDidChange()
                case .processingError:
                    print(self.DEBUG_TAG+"\t processing error")
                    return self.eventLoopGroup.next().makeFailedFuture(NSError())
                default: break
                    
                }
                return self.eventLoopGroup.next().makeSucceededVoidFuture()
            }
    }
}




//
// MARK: - Transfers
extension Remote {
    
    
    //
    // MARK: find transfer operation
    func findTransfer(withUUID uuid: UInt64) -> TransferOperation? {
        
        if let operation = findReceiveOperation(withStartTime: uuid) {
            return operation  }
        
        if let operation = findSendOperation(withStartTime: uuid){
            return operation  }
        
        return nil
    }
    
    
    //
    // MARK: stop Transfer
    func stopTransfer(withUUID uuid: UInt64, error: Swift.Error?) {
        
        print(DEBUG_TAG+"stopping transfer...")
        
        if let op = findTransfer(withUUID: uuid) {
            
            
            if let error = error as? TransferError,
                error == .TransferDeclined {
                
                let result = warpClient?.cancelTransferOpRequest(op.operationInfo)
                result?.response.whenComplete { result in
                    print(self.DEBUG_TAG+"request to cancel transfer had result: \(result)")
                    (op as? ReceiveFileOperation)?.receiveWasCancelled()
                }
                
            } else {
                
//                let stopInfo: StopInfo = .with {
//                    $0.info = op.operationInfo
//                    $0.error = (error != nil)
//                }
                
//                let result =
                warpClient?.stopTransfer( .with {
                    $0.info = op.operationInfo
                    $0.error = (error != nil)
                })
//                result?
                    .response.whenComplete { result in
                    print(self.DEBUG_TAG+"request to stop transfer had result: \(result)")
                }
            }
            
        } else {
            print(DEBUG_TAG+"Couldn't find operation: \(uuid)")
        }
    }
    
    
    
    //
    // MARK: Decline Receive Request
    func informOperationWasDeclined(forUUID uuid: UInt64, error: Swift.Error? = nil) {
        
        if let op = findTransfer(withUUID: uuid) {
            
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
    func startTransfer(for operation: ReceiveFileOperation) {
        
        print(DEBUG_TAG+"startTransfer ")
        
        let f: EventLoopFuture<Void> = client().flatMap { client in
            
            guard self.details.status != .Idle else {
                return client.ping(self.lookupName).status.flatMap { voidType in
                    print(self.DEBUG_TAG+"client connection verified")
                    return operation.startReceive(usingClient: client)
                }
            }
            
            return operation.startReceive(usingClient: client)
        }
        
        
        
        
        
        
//        guard let client = warpClient else {
////            requestStop(forOperationWithUUID: operation.UUID, error: TransferError.ConnectionInterrupted )
//            print(DEBUG_TAG+"cancel receiving; no client connection "); return
//        }
//
//        // ping to wake up before sending, if idle
//        guard details.status != .Idle else {
//
//            let result = client.ping(lookupName)
//
//            result.response.whenComplete { result in
//                switch result {
//                case .success(_):
//                    self.details.status = .Connected
//                    operation.startReceive(usingClient: client) // if still connected, proceed with sending
//                case .failure(let error): _ = self.disconnect(error) // if connection is dead, signal disconnect
//                }
//            }
//            return
//        }
//
//
//        operation.startReceive(usingClient: client)
        
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
    func sendFiles(_ selections: [TransferSelection]) -> EventLoopFuture<Void> {
        
        let operation = SendFileOperation(for: selections) 

        addSendingOperation(operation)
        return sendRequest(toTransfer: operation)
    }
    
    //
    // send client a message that we have files we want to send
    func sendRequest(toTransfer operation: SendFileOperation ) -> EventLoopFuture<Void> {
        
        print(DEBUG_TAG+"Sending request: \(operation.transferRequest)")
        print(DEBUG_TAG+"\t\t info: \(operation.transferRequest.info)")
        print(DEBUG_TAG+"\t\t sender: \(operation.transferRequest.senderName)")
        print(DEBUG_TAG+"\t\t size: \(operation.transferRequest.size)")
        print(DEBUG_TAG+"\t\t count: \(operation.transferRequest.count)")
        
        operation.prepareToSend()
        
        return ping()
            .flatMap {
                return self.client()
            }
            .flatMap { client in
                return client.processTransferOpRequest(operation.transferRequest).response
            }
            .convertVoidTypeToVoid()
            .flatMapError { error in
                print(self.DEBUG_TAG+"process request failed: \(error)")
                return self.disconnect(error) // if connection is dead, signal disconnect
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
// MARK: ConnectivityStateDelegate
extension Remote: ConnectivityStateDelegate {
    
    
    // fails if client has been disconnected
    private func client() -> EventLoopFuture<WarpClient> {
        
        if let client = warpClient {
            return eventLoopGroup.next().makeSucceededFuture(client)
        }
        
        return eventLoopGroup.next().makeFailedFuture(Error.UNKNOWN_ERROR)
    }
    
    
    //
    //MARK: - stateDidChange
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
    public func didCatchError(_ error: Swift.Error, logger: Logger, file: StaticString, line: Int) {
        
        print(DEBUG_TAG+"ERROR (\(file):q\(line)): \(error)")
        
        // if certificate is bad
        if case NIOSSLError.handshakeFailed(_) = error {
            print(DEBUG_TAG+"Handshake error, bad cert: \(error)")
            authenticationCertificate = nil
            
            _ = disconnect()
            startupConnection()
        } else {
            print(DEBUG_TAG+"Unknown error: \(error)")
        }
    }
}




////
//// MARK: - Authentication
//extension Remote {
//    func getAuthenticationConnection() -> AuthenticationConnection {
//        if details.api == "1" { // API_V1
//            return UDPConnection(onEventLoopGroup: eventLoopGroup,
//                                 endpoint: details.endpoint)
//        } else { // API_V2
//            return GRPCConnection(onEventLoopGroup: eventLoopGroup,
//                                  details: details)
//        }
//    }
//
//}


