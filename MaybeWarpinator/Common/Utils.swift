//
//  Utils.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-06.
//

import Foundation
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
    
    
    public static func getDeviceName() -> String {
        return "MyDeviceName"
    }
    
    
    
    /** Why the everloving fuck is this what a person needs to do to get a goddamn IP address on iOS  jesus christ if
     I wanted to use pointers I'd go back to university
     */
    public static func getIPV4Address() -> String {
        
        var addrList: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&addrList) == 0,
              let firstAddr = addrList else {  return  "Whelp."}
        
        defer {  freeifaddrs(addrList) }
        
        var address: String = "???.???.???"
        for cursor in sequence(first: firstAddr, next: {  $0.pointee.ifa_next  }) {
            let interfaceName = String(cString: cursor.pointee.ifa_name)
            
            let interface = cursor.pointee
            let addressFamily = interface.ifa_addr.pointee.sa_family
            
            if addressFamily != UInt8(AF_INET) {
                continue
            }
            
            // we only care about wifi
            if interfaceName != "en0" {
                continue
            }
            
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if let addr = cursor.pointee.ifa_addr,
               getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0,
               hostname[0] != 0 {
                address = String(cString: hostname)
            }
        }
        return address
    }
    
    
    
    
//    static func checkFolderExists(){
//        
//        let url = FileManager.default.extended.documentsDirectory
//        
//    }
    
    
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
