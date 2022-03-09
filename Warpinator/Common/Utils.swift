//
//  Utils.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-06.
//
import UIKit


public class Utils {
    
    
    static let borderColour: UIColor = #colorLiteral(red: 0.7877369523, green: 0.7877556682, blue: 0.7877456546, alpha: 1)
    static let backgroundColour: UIColor = #colorLiteral(red: 0.9531012177, green: 0.9531235099, blue: 0.9531114697, alpha: 1)
    static let foregroundColour: UIColor = #colorLiteral(red: 0.9688121676, green: 0.9688346982, blue: 0.9688225389, alpha: 1)
    static let textColour: UIColor = #colorLiteral(red: 0.2464925945, green: 0.2464992404, blue: 0.2464956939, alpha: 1)
    
    
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask){
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.orientationLock = orientation
        }
    }
    
    
    
    // MARK: get IPv4
    public static func getIP_V4_Address() -> String {
        
        // get address list
        var addrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrList) == 0,
              let firstAddr = addrList else {  return  " (getIP_V4_Address) No addresses."}
        
        // make sure we free the memory when done
        defer {  freeifaddrs(addrList) }
        
        
        // cycle interfaces until we find IP_v4
        var address: String = "???.???.???"
        for cursor in sequence(first: firstAddr, next: {  $0.pointee.ifa_next  }) {
            
            let interfaceName = String(cString: cursor.pointee.ifa_name)
            
            // we only care about wifi
            if interfaceName != "en0" {  continue  }
            
            let interface = cursor.pointee
            let addressFamily = interface.ifa_addr.pointee.sa_family
            
            if addressFamily != UInt8(AF_INET) {
                continue
            }
            
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if let addr = cursor.pointee.ifa_addr,
               getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname,
                           socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0,
               hostname[0] != 0 {
                address = String(cString: hostname)
            }
        }
        return address
    }
    
    
    
    // MARK: get IPv6
    public static func getIP_V6_Address() -> String {
        
        // get address list
        var addrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrList) == 0,
              let firstAddr = addrList else {  return  " (getIP_V6_Address) No addresses."}
        
        // make sure we free the memory when done
        defer {  freeifaddrs(addrList) }
        
        
        // cycle interfaces until we find IP_v6
        var address: String = "????::????:????:????:????"
        for cursor in sequence(first: firstAddr, next: {  $0.pointee.ifa_next  }) {
            
            let interfaceName = String(cString: cursor.pointee.ifa_name)
            
            // we only care about wifi
            if interfaceName != "en0" {  continue  }
            
            
            let interface = cursor.pointee
            let addressFamily = interface.ifa_addr.pointee.sa_family
            
            
            // If address is IPV6
            if addressFamily == UInt8(AF_INET6) {
                
                let s6_addr = interface.ifa_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    $0.pointee.sin6_addr.__u6_addr.__u6_addr8
                }
                
                if s6_addr.0 == 0xfe && (s6_addr.1 & 0xc0 ) == 0x80 {
                    
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    
                    if let addr = interface.ifa_addr,
                       getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname,
                                   socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0,
                       hostname[0] != 0 {
                        
                        // string will include %en0 at the end; strip it off
                        let wholeAddress = String(cString: hostname)
                        let components = wholeAddress.split(separator: Character("%"))
                        address = String(components[0])
                        print("v6_address: \(address)")
                    }
                }
            }
        }
        
        return address
    }
    
    
    // MARK: get available disk space
    static func queryAvailableDiskSpace() -> Int64 {
        
        let url = FileManager.default.extended.documentsDirectory
        
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return capacity
            }
        } catch {
            print("Error retrieving disk capacity: ")
        }
        
        return 0
    }
    
    
    
    
    
    
}
