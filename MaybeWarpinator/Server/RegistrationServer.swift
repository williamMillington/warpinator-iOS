//
//  RegistrationServer.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-01.
//

import Foundation

import NIO
import NIOSSL

import GRPC
import Network

import Logging


// MARK: - Registration Server
class RegistrationServer {
    
    private let DEBUG_TAG: String = "RegistrationServer: "
    
    public static let REGISTRATION_PORT: Int = 42001
    private var registration_port: Int = RegistrationServer.REGISTRATION_PORT
    
    private lazy var uuid: String = Server.SERVER_UUID
    
    
    var mDNSBrowser: MDNSBrowser?
    var mDNSListener: MDNSListener?
    
    var certificateServer = CertificateServer()
    
    
    private var registrationServerELG: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: (System.coreCount / 2) ) //GRPC.PlatformSupport.makeEventLoopGroup(loopCount: 1, networkPreference: .best)

    private var warpinatorProvider: WarpinatorServiceProvider = WarpinatorServiceProvider()
    private var warpinatorRegistrationProvider: WarpinatorRegistrationProvider = WarpinatorRegistrationProvider()
    
    
    var remoteManager: RemoteManager? {
        didSet {
            warpinatorRegistrationProvider.remoteManager = remoteManager
        }
    }
    
    // MARK: - start server
    func start(){
        
        
        
        
        let registrationServerFuture = GRPC.Server.insecure(group: registrationServerELG)
            .withServiceProviders([warpinatorRegistrationProvider])
            .bind(host: "\(Utils.getIPV4Address())", port: registration_port)
            
        
        registrationServerFuture.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            self.startMDNSServices()
            print(self.DEBUG_TAG+"registration server started on: \(String(describing: address))")
        }
        
        
        let closefuture = registrationServerFuture.flatMap {
            $0.onClose
        }
        
        closefuture.whenCompleteBlocking(onto: .main) { _ in
            print(self.DEBUG_TAG+" registration server exited")
        }
        closefuture.whenCompleteBlocking(onto: DispatchQueue(label: "cleanup-queue")){ _ in
            try! self.registrationServerELG.syncShutdownGracefully()
        }
        
    }
    
    
    
    func startMDNSServices(){
        mDNSBrowser = MDNSBrowser()
        mDNSBrowser?.delegate = self
        
        mDNSListener = MDNSListener()
        mDNSListener?.delegate = self
        mDNSListener?.start()
    }
    
    
    func mockStart(){
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            print(self.DEBUG_TAG+"mocking registration")
            self.mockRegistration()
        }
    }
    
    

}




// MARK: - MDNSListenerDelegate
extension RegistrationServer: MDNSListenerDelegate {
    func mDNSListenerIsReady() {
        mDNSBrowser?.startBrowsing()
    }
}



// MARK: - MDNSBrowserDelegate
extension RegistrationServer: MDNSBrowserDelegate {
    
    // MARK: didAddResult
    func mDNSBrowserDidAddResult(_ result: NWBrowser.Result) {
        
        
        // if the metadata has a record "type",
        // and if type is 'flush', then ignore this service
        if case let NWBrowser.Result.Metadata.bonjour(record) = result.metadata,
           let type = record.dictionary["type"],
           type == "flush" {
            print(DEBUG_TAG+"service \(result.endpoint) is flushing; ignore"); return
        }
        print(DEBUG_TAG+"assuming service is real, continuing...")
        
        
        var serviceName = "unknown_service"
        switch result.endpoint {
        case .service(name: let name, type: _, domain: _, interface: _):
            
            serviceName = name
            if name == uuid {
                print(DEBUG_TAG+"Found myself (\(result.endpoint))"); return
            } else {
                print(DEBUG_TAG+"service discovered: \(name)")
            }
//            print(DEBUG_TAG+"\tinterface: \(String(describing: interface))")
            
        default: print(DEBUG_TAG+"unknown service endpoint type: \(result.endpoint)"); return
        }
        
        
        print(DEBUG_TAG+"mDNSBrowser did add result:")
        print("\t\(result.endpoint)")
        print("\t\(result.metadata)")
        
        
        var hostname = serviceName
        var api = "1"
        var authPort = 42000
        // parse TXT record for metadata
        if case let NWBrowser.Result.Metadata.bonjour(TXTrecord) = result.metadata {
            
            for (key, value) in TXTrecord.dictionary {
                switch key {
                case "hostname": hostname = value
                case "api-version": api = value
                case "auth-port": authPort = Int(value) ?? 42000
                case "type": break
                default: print("unknown TXT record type: \(key)-\(value)")
                }
            }
        }
        
        
        
        if let remote = remoteManager?.containsRemote(for: serviceName) {
                print(DEBUG_TAG+"Service already added")
            if remote.details.status == .Disconnected || remote.details.status == .Error {
                print(DEBUG_TAG+"\tstatus is not connected: reconnecting...")
                remote.startConnection()
            }
            return
        }
        
        
        var details = RemoteDetails(endpoint: result.endpoint)
        details.serviceName = serviceName
        details.hostname = hostname
        details.uuid = serviceName
        details.api = api
        details.port = 42000
        details.authPort = authPort //"42000"
        details.status = .Disconnected
        
        
        
        let newRemote = Remote(details: details)
        
        
        remoteManager?.addRemote(newRemote)
    }
    
}



//MARK: - Mock Registration
extension RegistrationServer {
    func mockRegistration(){
        
        for i in 0...5 {
            
            var mockDetails = RemoteDetails.MOCK_DETAILS
            mockDetails.uuid = mockDetails.uuid + "__\(i)"
            
            let mockRemote = Remote(details: mockDetails)
            
            remoteManager?.addRemote(mockRemote)
            
        }
        
    }
}
