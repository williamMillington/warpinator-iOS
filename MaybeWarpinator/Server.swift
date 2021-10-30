//
//  Server.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-04.
//

import UIKit

import GRPC
import NIO
import NIOSSL
import SwiftProtobuf

import Network

import CryptoKit
import Sodium


public class Server: NSObject {
    
    
//    public static var shared: Server!
    
    private let DEBUG_TAG: String = "Server: "
    
    private let SERVICE_TYPE = "_warpinator._tcp."
    private let SERVICE_DOMAIN = "local"
    
    
    public static var transfer_port: Int = 42000
    public static var registration_port: Int = 42001
    
    
    public var transfer_port: Int = Server.transfer_port
    public var registration_port: Int = Server.registration_port
    
    public var uuid: String = "WarpinatorIOS"
    public var displayName: String = "iOS_Device"
    
    public lazy var hostname = uuid
    
    var myService: NetService?
    let serviceBrowser = NetServiceBrowser()
    var savedServices: [String: NetService] = [:]
    
    
    var certificateServer = CertificateServer()
    
    
    private var gRPCServer: GRPC.Server?
    
    
    private var registrationServer: GRPC.Server?
    private var eventLoopGroup2: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    private var eventLoopGroup: EventLoopGroup = GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)
    
    private var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    private var warpinatorRegistrationProvider: WarpinatorRegistrationProvider = WarpinatorRegistrationProvider()
    
    
    var mDNSBrowser: MDNSBrowser?
    var mDNSListener: MDNSListener?
    
    
    var remotes: [String: Remote] = [:]
    
    
    func start(){
        
//        Server.shared = self
        
//        do {
//            try certificateServer.start()
//        }catch {
//            (DEBUG_TAG+"certificateServer failed: \(error.localizedDescription)")
//        }
        
//        publishWarpinatorService()
        
        startRegistrationServer()
        startWarpinatorServer()
        
        mDNSBrowser = MDNSBrowser()
        mDNSBrowser?.delegate = self
        
        mDNSListener = MDNSListener()
        mDNSListener?.delegate = self
        mDNSListener?.start()  //publishServiceAndListen()
        
    }
    
    
    
//    func publishWarpinatorService(){
//
//        myService = NetService(domain: "", type: SERVICE_TYPE,
//                             name: uuid, port: Int32(registration_port))
//
//
////        let properties: [String:String] = ["hostname":"mebbe_werpinator"]
////        let txtRecord = NWTXTRecord(properties)
////        let recordData = try! JSONEncoder().encode(properties)
//
//
////        myService?.setTXTRecord( NetService.data(fromTXTRecord: txtRecord) )
//
////        (DEBUG_TAG+"My service hostname is: \(myService?.hostName)")
//        myService?.includesPeerToPeer = true
//
//
////        myService?.delegate = self
//        myService?.publish(options: NetService.Options.listenForConnections)
//
//    }
    
    
    
    func startRegistrationServer(){
        
        let serverBuilder = GRPC.Server.insecure(group: eventLoopGroup2)
        
        let keepalive = ServerConnectionKeepalive(interval: .seconds(30) )
        let gRPCRegistrationServerFuture = serverBuilder.withServiceProviders([warpinatorRegistrationProvider])
            .withKeepalive(keepalive)
            .bind(host: "\(Utils.getIPAddress())", port: registration_port)
        
        
        gRPCRegistrationServerFuture.whenComplete { result in
            print(self.DEBUG_TAG+"fetch registration server object")
            if let server = try? result.get() {
                print(self.DEBUG_TAG+"registration server stored")
                self.registrationServer = server
            } else { print(self.DEBUG_TAG+"Failed to get registration server") }
        }
        
        gRPCRegistrationServerFuture.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            print(self.DEBUG_TAG+"registration server started on: \(String(describing: address))")
        }
        
        
        let closefuture = gRPCRegistrationServerFuture.flatMap {
            $0.onClose
        }
        
        closefuture.whenCompleteBlocking(onto: .main) { _ in
            print(self.DEBUG_TAG+"server exited")
        }
        closefuture.whenCompleteBlocking(onto: DispatchQueue(label: "cleanup-queue")){ _ in
            try! self.eventLoopGroup2.syncShutdownGracefully()
        }
    }
    
    
    
    
    
    
    
    func startWarpinatorServer(){
        
        guard let certificate = Authenticator.shared.getServerCertificate() else { return }
        guard let privateKey = Authenticator.shared.getServerPrivateKey() else { return }
        
        
        
        var tlsConfig = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(certificate) ] ,
                                                                 privateKey: .privateKey(privateKey) )
        tlsConfig.additionalTrustRoots = [ .certificates([certificate]) ]
        tlsConfig.certificateVerification = CertificateVerification.noHostnameVerification
        
        
        let gRPCConfig = GRPCTLSConfiguration.makeServerConfigurationBackedByNIOSSL(configuration: tlsConfig)
        
        
        let serverBuilder = GRPC.Server.usingTLS(with: gRPCConfig,
                                                 on: eventLoopGroup)
        
        let keepalive = ServerConnectionKeepalive(interval: .seconds(30) )
        let gRPCServerFuture = serverBuilder.withServiceProviders([warpinatorProvider])
            .withKeepalive(keepalive)
            .bind(host: "\(Utils.getIPAddress())", port: transfer_port)
        
        
        
        
        
        gRPCServerFuture.whenComplete { result in
            print("fetch server object")
            if let server = try? result.get() {
                print("server stored")
                self.gRPCServer = server
            } else { print(self.DEBUG_TAG+"Failed to get server") }
        }
        
//        do {
//            let certificate = try NIOSSLCertificate.fromPEMFile(certificateFilePath)
//        } catch {
//            print(DEBUG_TAG+"Error getting certificate from file")
//        }
 
//        gRPCServer = GRPC.Server.insecure(group: group)
//            .withServiceProviders([warpinatorProvider])
//            .bind(host: "localhost", port: transfer_port)
            
        
        gRPCServerFuture.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            print(self.DEBUG_TAG+"gRPC server started on port: \(String(describing: address))")
        }
        
        
        let closefuture = gRPCServerFuture.flatMap {
            $0.onClose
        }
        
        closefuture.whenCompleteBlocking(onto: .main) { _ in
            print(self.DEBUG_TAG+"server exited")
        }
        closefuture.whenCompleteBlocking(onto: DispatchQueue(label: "cleanup-queue")){ _ in
            try! self.eventLoopGroup.syncShutdownGracefully()
        }
    }
    
    
    // MARK: - Add remote
    func addRemote(_ remote: Remote){
        
//        remote.group = eventLoopGroup
        remotes[remote.uuid] = remote
        
        remote.connect()
    }
    
    
}




// MARK: - MDNSListenerDelegate
extension Server: MDNSListenerDelegate {

    func mDNSListenerIsReady() {
        print("listener is ready")
        mDNSBrowser?.startBrowsing()
    }
    
    func mDNSListenerDidEstablishIncomingConnection(_ connection: NWConnection) {}
}



// MARK: - MDNSBrowserDelegate
extension Server: MDNSBrowserDelegate {
    
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result) {
        
        print(DEBUG_TAG+"mDNSBrowser did add result:")
        print("\t\(result.endpoint)")
        print("\t\(result.metadata)")
        print("\t\(result.interfaces)")
        
        switch result.endpoint {
        case .hostPort(host: _, port: _): break
            
        case .service(name: let name, type: _, domain: _, interface: _):
            if name == uuid {
                print(DEBUG_TAG+"C'est moi (\(result.endpoint)"); return
            } else {
                print(DEBUG_TAG+"service discovered: \(name)")
            }
        default: print(DEBUG_TAG+"unknown service endpoint: \(result.endpoint)"); return
        }
        
        print(DEBUG_TAG+"adding remote")
        
//        let remote = Remote(connection: connection)
        let remote = Remote(endpoint: result.endpoint)
        
        
//        if case let NWEndpoint.hostPort(host: host, port: port) = result.endpoint {
//            remote.IPAddress = host // String(describing: host)
//            remote.port = port
//        }
        
        var hostname = ""
        if case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata {
            if let hn = record.dictionary["hostname"] {
                hostname = hn
            }
        }
        
        remote.hostname = hostname
        remote.serviceAvailable = true
        
        addRemote(remote)
        remote.connect()
////        if let addressData = sender.addresses?.first {
////            remote.IPAddress = String(data: addressData, encoding: .utf8) ?? "No address"
////            remote.port = sender.port
////        }
////
////        remote.hostname = sender.hostName ?? "No hostname"
////        remote.port = sender.port
////        remote.serviceName = serviceName
////        remote.uuid = serviceName
//
//        remote.serviceAvailable = true
//
//        addRemote(remote)
        
        
    }
    
    
}




































// MARK: - NetServiceDelegate
//extension Server: NetServiceDelegate {
//
//    public func netServiceWillPublish(_ sender: NetService) {
//        print("Will publish \(sender.name)")
//    }
//
//    public func netServiceDidPublish(_ sender: NetService) {
//        print("Did publish \(sender.name)")
//    }
//
//    public func netServiceWillResolve(_ sender: NetService) {
////        print("\tWill attempt to resolve \(sender.name)")
//
//
//        if let _ = savedServices[sender.name] {
//            print("\t\tService under name: \(sender.name) is already saved")
//        } else {
//            print("\t\tAdding service under name: \(sender.name)")
//            savedServices[sender.name] = sender
//        }
//    }
//
//    public func netServiceDidResolveAddress(_ sender: NetService) {
////        print("=================================================================================")
//        print("\tDid resolve \(sender.name)")
//        print("\t\thostname: \"\(sender.hostName ?? "No name")\"")
//        print("\t\tdomain: \"\(sender.domain)\"")
//        print("\t\tport: \"\(sender.port)\"")
//        print("\t\ttype: \"\(sender.type)\"")
//
//        let serviceName = sender.name
//
//
//        if let remote = remotes.first(where: { (key: String, remote: Remote) in
//            return key == serviceName
//        })?.value {
//
//            print("\t\tRemote exists, updating...")
//
//            remote.hostname = sender.hostName ?? remote.hostname
//            remote.serviceAvailable = true
//
//            if remote.status == Remote.RemoteStatus.Disconnected ||
//                remote.status == Remote.RemoteStatus.Error {
//
//                if let addressData = sender.addresses?.first {
//                    remote.IPAddress = String(data: addressData, encoding: .utf8) ?? "No address"
//                    remote.port = sender.port
//                }
//
////                remote.connect()
//            }
//
//
//        } else {
//
//            print("\t\tCreating remote...")
//            let remote = Remote()
//
//            if let addressData = sender.addresses?.first {
//                remote.IPAddress = String(data: addressData, encoding: .utf8) ?? "No address"
//                remote.port = sender.port
//            }
//
//            remote.hostname = sender.hostName ?? "No hostname"
//            remote.port = sender.port
//            remote.serviceName = serviceName
//            remote.uuid = serviceName
//            remote.serviceAvailable = true
//
//
//            addRemote(remote)
//        }
//
//    }
//
//
//
//    public func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
//        print("Failed to resolve: \(sender.name)")
//
//        for (_,error) in errorDict.enumerated() {
//            print("\t\(error)")
//        }
//    }
//
//    public func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
//            print("\(sender.name) accepted stream connection")
//    }
//
//}
//
//
//
//
//// MARK: -NetServiceBrowserDelegate
//extension Server: NetServiceBrowserDelegate {
//
//    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
//
//        print("found service")
//
//        if service.name != uuid {
//            print("\tFound external service: \(service.name)")
//
//            if service.port == -1 {
//                print("\t\tResolving...")
//                service.delegate = self
//                service.resolve(withTimeout: 5)
//            }
//        } else {
//            print("found myself: \(service.name)")
//        }
//
//    }
//
//    public func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
//
//        print("Found domain: \(domainString)")
//        print("\tinitiating search for services of type \(SERVICE_TYPE) on \(domainString)...")
//
//    }
//
//
//    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
//
//        print("Removed service: \(service.name)")
//        savedServices.removeValue(forKey: service.name)
//    }
//
//    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
//
//        print("Removed domain: \(domainString)")
//
//    }
//
//
//    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
//        print("Encountered error: ")
//        for (_, error) in errorDict.enumerated() {
//            print(error)
//        }
//    }
//
//    public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
//        print("Searching...")
//    }
//
//    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
//        print("...stopped searching.")
//    }
//
//}
