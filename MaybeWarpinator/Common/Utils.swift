//
//  Utils.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-06.
//

import Foundation
import UIKit



public class Utils {
    
    
    
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
