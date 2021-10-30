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





public class Remote {
    
    public enum RemoteStatus {
        case Connected, Disconnected
        case Connecting
        case Error
        case AwaitingDuplex
    }
    
    lazy var DEBUG_TAG: String = "REMOTE (hostname: \"\(hostname)\"): "
    
    private var connection: NWConnection?
    
    private var endpoint: NWEndpoint
    
//    public var IPAddress: NWEndpoint.Host?
//    public var port: NWEndpoint.Port?
    public var serviceName: String = ""
    public var username: String = ""
    public var hostname: String = ""
    public var displayName: String = ""
    public var uuid: String = ""
    public var picture: UIImage?
    public var status: RemoteStatus = .Disconnected
    public var serviceAvailable: Bool = false
    
    var transfers: [Transfer] = []
    
    
    var channel: ClientConnection?
    var warpClient: WarpClientProtocol?
    
    
    let certificateServer = CertificateServer()
    
//    var group: EventLoopGroup?
    let group = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
//    init(){
//
//    }
    
//    convenience init(connection conn: NWConnection){
//        self.init()
//        connection = conn
//    }
    
     init(endpoint ep: NWEndpoint){
        endpoint = ep
    }
    
    
    convenience init(fromResult result: NWBrowser.Result){
        self.init(endpoint: result.endpoint)
        
        switch endpoint {
        case .service(name: let name, type: _, domain: _, interface: _):
            hostname = name
            break
        default: print("not a service nor host/port pair")
        }
        
    }
    
    
    func connect(){
        
        print("============================================================================")
        print("Creating UDP connection to remote: \(hostname)")
        
        
        status = .Connecting
        
        
        let params = NWParameters(dtls: nil, udp: NWProtocolUDP.Options() )
        params.allowLocalEndpointReuse = true
        
        connection = NWConnection(to: endpoint, using: params)
        connection?.stateUpdateHandler = { newState in
            switch newState {
            case .ready: print(self.DEBUG_TAG+"connection ready");
                
                self.fetchCertificate()
            default: print(self.DEBUG_TAG+"state updated: \(newState)")
            }
        }
        connection?.start(queue: .main)
        
    }
    
    
    private func fetchCertificate(onComplete: @escaping ()->Void = {} ){
        
        print(DEBUG_TAG+"fetching certificate")
        
        guard let connection = connection else {
            print(DEBUG_TAG+"connection failed"); return
        }
        
        certificateServer.serveCertificate(to: connection)
//        print("attempting api2 request")
        
//        let port = 42001
//        guard hostname != "" else {
//            print("no hostname")
//            return
//        }
//
//        let channel = ClientConnection.insecure(group: group).connect(host: hostname, port: port)
//
//        let client = WarpRegistrationClient(channel: channel)
//
//        let request: RegRequest = .with {
//            $0.hostname = uuid
//            $0.ip = Utils.getIPAddress()
//        }
//        let options = CallOptions(timeLimit: .timeout( .seconds(5)) )
//
//        let registrationRequest = client.requestCertificate(request, callOptions: options)
//
//        registrationRequest.response.whenSuccess { result in
//            print(self.DEBUG_TAG+"completed ")
////            print("cert is \(result.lockedCert)")
//            Authenticator.shared.unlockCertificate(result.lockedCert)
//        }
        
        
        
//        let keyCode = "Warpinator"
//        let keyCodeBytes = Array(keyCode.utf8)
//
//        let encryptedKey = SHA256.hash(data: keyCodeBytes )
//        let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })
//
//        let sKey = SecretBox.Key(encryptedKeyBytes)
//
//        if case let NWEndpoint.hostPort(host: host, port: port) = endpoint {
//            print(DEBUG_TAG+"fetching certificate from host: \(host), port: \(port)")
//        } else {
//            print(DEBUG_TAG+"connection is not a host/port: \(endpoint)")
//        }
        
        
//        print("about to try receiving")
        
//        let requestString = "REQUEST"
//        let requestStringBytes = requestString.bytes
//        connection.send(content: requestStringBytes,
//                        completion: NWConnection.SendCompletion.contentProcessed { error in
//
////                            print(self.DEBUG_TAG+"finished sending request, attempting to receive certificate...")
//
//                            // RECEIVING
//                            connection.receiveMessage  { (data, context, isComplete, error) in
//
////                                print("receiving response")
//
//                                if isComplete {
//
//                                    if let concrete_data = data,
//                                       let decoded = Data(base64Encoded: concrete_data, options: .ignoreUnknownCharacters  ) {
//
//                                        let decodedBytes: [UInt8] = Array(decoded)
//                                        var nonce: [UInt8] = []
//                                        var cipherText: [UInt8] = []
//
//                                        for i in 0..<24 {
//                                            nonce.append( decodedBytes[i] )
//                                        }
//
//                                        for i in 0..<(decodedBytes.count - 24) {
//                                            cipherText.append(  decodedBytes[ i + 24 ] )
//                                        }
//
//                                        let sodium = Sodium()
//                                        let snonce = SecretBox.Nonce(nonce)
//                                        let certificateBytes = sodium.secretBox.open(authenticatedCipherText: cipherText,
//                                                                                     secretKey: sKey,
//                                                                                     nonce: snonce)
//
//                                        if let bytes = certificateBytes {
//
//                                            do {
//                                                let certificate = try NIOSSLCertificate(bytes: bytes, format: .pem)
//
//                                                self.openChannel(withCertificate: certificate)
//
//                                            } catch {
//                                                print("problem creating certificate \(error.localizedDescription)")
//                                            }
//                                        } else {  print("Failed to unbox certificate")  }
//
//                                    } else {   print("No data received") }
//                                }
//                            }
//
//                        })
    }
    
    
    
    
    
    // MARK: - Open Channel
    private func openChannel(withCertificate certificate: NIOSSLCertificate, onComplete: @escaping ()->Void = {} ){
        
        print(DEBUG_TAG+"opening channel with certificate: \( Data( try! certificate.toDERBytes() ).base64EncodedString() ) ")
        
        
        // close the connection so we can use the port
//        if let connection = connection {
//            connection.cancel()
//        }
        
        
        var config = TLSConfiguration.makeClientConfiguration()
        config.additionalTrustRoots = [ .certificates([certificate]) ]
        config.certificateVerification = .noHostnameVerification
        
        let port = 42000
        
//        let sslContext = try! NIOSSLContext(configuration: config)
//        let _ = try! NIOSSLClientHandler(context: sslContext,
//                                         serverHostname: hostname + "\(port)")
        
//        var meta = NWProtocolTLS.Metadata()
        
//        let options = NWProtocolTLS.Options()
        
//        let grpcTLSConfig = GRPC.GRPCTLSConfiguration.makeServerConfigurationBackedByNetworkFramework(options: options)   //makeClientConfigurationBackedByNetworkFramework()
         //makeClientDefault(for: .best)
        
        
        let channelBuilder = ClientConnection.usingPlatformAppropriateTLS(for: group) //   /(with: grpcTLSConfig, on: group)  //
//            .usingTLSBackedByNIOSSL(on: self.group)
//            .withTLS(trustRoots: config.trustRoots!)
//            .withKeepalive( ClientConnectionKeepalive(interval: .seconds(30) ) )
            .withConnectivityStateDelegate(self)
        
        guard hostname != "" else {
            print("no hostname")
            return
        }
        
        channel = channelBuilder.connect(host: hostname, port: port)
        
        if let channel = channel {
            warpClient = WarpClient(channel: channel)
        } else {
            print("channel setup failed")
        }
        
//        print(DEBUG_TAG+"client connection: \(warpClient.debugDescription)")
        
        waitForDuplex()
//        onComplete()
        
    }
    
    
    private func waitForDuplex(onComplete: @escaping ()->Void = {} ){
        
        print(DEBUG_TAG+"waiting for duplex...")
        
        guard let client = warpClient else {
            print(DEBUG_TAG+"no client connection"); return
        }
        
        let lookupname: LookupName = .with({
            $0.id = "MAYBEWARPINATOR_IOS"
            $0.readableName = "MaybeWarpinator"
        })
        
        let duplex = client.checkDuplexConnection(lookupname)
        
//        duplex.
        duplex.response.whenComplete { result in
            print("waitForDuplex: result is \(result)")
        }
        
        print("duplex is \(duplex.response)")
        
    }
    
    
    
    
    private func sendCertificate(){
        
//        print("sending certificate to \(self.hostname)")
        
//        guard let connection = connection else {
//            print(DEBUG_TAG+"No connection present")
//            return
//        }
        
        
//        let keyCode = "Warpinator"
//        let keyCodeBytes = Array(keyCode.utf8)
//
//        let encryptedKey = SHA256.hash(data: keyCodeBytes )
//        let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })
//
//        let sKey = SecretBox.Key(encryptedKeyBytes)
        
        
//        print("\tsending request...")
        // SENDING
        
        
//        connection.receiveMessage { (data, context, isComplete, error) in
//
//            if isComplete {
//                guard let data = data else {
//                    print("Received data is nil"); return
//                }
//
//                if let requestString = String(bytes: Array(data), encoding: .utf8) {
//                    print("requeststring is: \(requestString)")
//                }
//
//
//                let certificateFilePath = Bundle.main.path(forResource: "certificate",
//                                                           ofType: "pem")!
//                let certificate = try! NIOSSLCertificate(file: certificateFilePath, format: .der)
//                let certificateBytes = try! certificate.toDERBytes()
//
//                let sodium = Sodium()
////                let sNonce = sodium.secretBox.nonce()
//                let sealedBox: (Bytes, SecretBox.Nonce)? = sodium.secretBox.seal(message: certificateBytes,
//                                                                                secretKey: sKey)
//
//                let nonce = sealedBox!.1
//                let encryptedText = sealedBox!.0
//                var messageBytes: [UInt8] = []
//
//                for byte in nonce {
////                    print("NONCE: byte appended")
//                    messageBytes.append(byte)
//                }
//                for byte in encryptedText {
////                    print("MSG_TEXT: byte appended")
//                    messageBytes.append(byte)
//                }
//
//
////                print("MESSAGEBYTES: \(messageBytes)")
//
//                let messageBytesEncoded = Data(messageBytes).base64EncodedString()
//
////                print("MESSAGEBYTESEncoded: \(messageBytesEncoded)")
//
//                connection.send(content: Data(bytes: messageBytesEncoded.bytes, count: messageBytesEncoded.bytes.count),
//                                completion: NWConnection.SendCompletion.contentProcessed { (error) in
//                                    if error != nil {
//                                        print("Error sending cert is: \(String(describing: error))")
//                                    } else {
//                                        print("Cert sent successfully")
//                                    }
//                })
//            }
//        }
        
//        let data = "REQUEST".data(using: .utf8)
//        connection.send(content: data, completion: NWConnection.SendCompletion.contentProcessed { (error) in
//            if error == nil {
//            } else {  print("Error: \(String(describing: error))")  }
//        })
        
//        print("attempting to receive certificate...?")
//
//        // RECEIVING
//        connection.receiveMessage  { (data, context, isComplete, error) in
//
//            print("receiving response")
//
//            if isComplete {
//
//                if let concrete_data = data,
//                   let decoded = Data(base64Encoded: concrete_data, options: .ignoreUnknownCharacters  ) {
//
////                            let dataString = String(decoding: decoded, as: UTF8.self)
//
////                            print("data: \(dataString)")
//
////                    let encryptedKey = SHA256.hash(data: keyCodeBytes )
////                    let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })
//
//                    let decodedBytes: [UInt8] = Array(decoded)
//                    var nonce: [UInt8] = []
//                    var cipherText: [UInt8] = []
//
//                    for i in 0..<24 {
//                        nonce.append( decodedBytes[i] )
//                    }
//
//                    for i in 0..<(decodedBytes.count - 24) {
//                        cipherText.append(  decodedBytes[ i + 24 ] )
//                    }
//
////                            print("key: \(keyBytes)")
////                            print("bytes: \(bytes)")
////                            print("nonce: \(nonce)")
////                            print("ciphertext : \(cipherText)")
//
//
//                    let sodium = Sodium()
////                    let skey = SecretBox.Key(encryptedKeyBytes)
//                    let snonce = SecretBox.Nonce(nonce)
//                    let certificateBytes = sodium.secretBox.open(authenticatedCipherText: cipherText,
//                                                                 secretKey: sKey,
//                                                                 nonce: snonce)
//
//                    if let bytes = certificateBytes {
////                                    print("succccccccceeded")
//
//                        do {
//                            let certificate = try NIOSSLCertificate(bytes: bytes, format: .pem)
//
////                                    print("made certificate!! yeet")
//
//                            let port = Int( self.port!.rawValue)
//
//                            let connection = ClientConnection.usingPlatformAppropriateTLS(for: self.group)
//                                .withTLS(certificateChain: [certificate])
//                                .connect(host: self.hostname, port: port )
//
//                            let client = WarpClient(channel: connection)
//
//                                    let lookupname: LookupName = .with({
//                                        $0.id = self.uuid
//                                        $0.readableName = "MaybeWarpinator"
//                                    })
//                                    let calloptions = CallOptions(timeLimit: .timeout(.seconds(30)))
//
////                                    let ping = client.ping(lookupname)
////                                    ping.response.whenComplete({ result in
////                                        print("ping is \(result)")
////                                    })
//
////                                    let duplexExists = client.checkDuplexConnection(lookupname, callOptions: calloptions)
////                                    duplexExists.response.whenComplete( { result in
////                                        print("The result of duplexExists is \(result)")
////                                    })
////                                    let rmi = client.getRemoteMachineInfo(lookupname)
////                                    rmi.response.whenComplete({ result in
////                                        print("The result of getRemoteMachineInfo is: \(result)")
////                                    })
////                                    print("\(certificate)")
//                        } catch {
//                            print("problem connection \(error.localizedDescription)")
//                        }
////                                if let certString = String(bytes: bytes, encoding: .utf8) {
////                                    print("Certificate: \n\(certString)")
////                                }
//
////                                let tls = GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL()
//                    } else {
//                        print("Failed to unbox certificate")
//                    }
//
//                } else {
//                    print("No data received")
//                }
//            }
//        }
        
        
        
//        connection.stateUpdateHandler = { (newState) in
//            switch newState {
////                print("\tconnection ready, fetching certificate request")
////
////                connection.receiveMessage(completion:  { (data, context, isComplete, error) in
////
////                    guard isComplete else {
////                        print("\t\tMessage incomplete. Error: \(String(describing: error))"); return
////                    }
////
////                    if let concrete_data = data {
////                        let decoded_request = String(decoding: concrete_data, as: UTF8.self)
////                            print("\t\tdecoded request: \(decoded_request)")
////                    }
////                })
//            default: print("\tconnection state updated to: \(newState)")
//            }
//        }
        
//        connection.start(queue: .main )
    }
    
    
    
}




extension Remote: ConnectivityStateDelegate {
    public func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
        print(DEBUG_TAG+"channel state has moved from \(oldState) to \(newState)")
        switch newState {
        case .ready: print(DEBUG_TAG+"channel ready")
            waitForDuplex()
        default: break
        }
        
    }
}
