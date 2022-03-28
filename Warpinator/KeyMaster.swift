//
//  KeyMaster.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-27.
//

import Foundation



final class KeyMaster {
    
    private static let DEBUG_TAG: String = "KeyMaster: "
    
    enum KeyMasterError: Error {
        case itemNotFound
        case duplicateItem
        case invalidFormat
    }
    
    
    static let service: String = "warpinator"
    
    
    
    // MARK: - Certificates
    

    // MARK: save
    // save SecCertificate
    static func saveCertificate(_ certificate: SecCertificate, withTag tag: String) throws {
        
//        print(DEBUG_TAG+"saving certificate for tag \'\(tag)\'")
        
        
        let query: [String: Any] = [ kSecAttrLabel as String : tag,
                                     kSecClass as String: kSecClassCertificate,
                                     kSecValueRef as String: certificate ]
        
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // IF: duplicate item
        guard status != errSecDuplicateItem else {
//            print(DEBUG_TAG+"Duplicate Certificate")
            throw KeyMasterError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw errorForOSStatus(status)
        }
        
        
//        print(DEBUG_TAG+"\t\t (SEC) certificate saved successfully")
    }
    
    
    
    
    
    //MARK: - read
    // read SecCertificate from keychain
    static func readCertificate(forTag tag: String) throws -> SecCertificate {
        
//        print(DEBUG_TAG+"Searching for certificate with tag \'\(tag)\'")
        
//        let tagData = tag.data(using: .utf8)
        
        let query: [String: Any] = [  kSecAttrLabel as String : tag,
                                     kSecClass as String: kSecClassCertificate,
                                     kSecMatchLimit as String: kSecMatchLimitOne,
                                     kSecReturnRef as String : kCFBooleanTrue as Any ]
        
        var itemCopy: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary,
                                         &itemCopy)
        
        
        // IF: item not found
        guard status != errSecItemNotFound else {
//            print(DEBUG_TAG+"\tNo certificate not found for tag \'\(tag)\'")
            throw KeyMasterError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw errorForOSStatus(status)
        }
        
//        print(DEBUG_TAG+"\tSuccessfully retrieved certificate for tag \'\(tag)\'")
        return itemCopy as! SecCertificate
    }
    
    
    
    //MARK: - delete
    static func deleteCertificate(forTag tag: String) throws {
        
//        print(DEBUG_TAG+"Deleting certificate for tag \'\(tag)\'")
        
//        let tagData = tag.data(using: .utf8)
        
        let query: [String: Any] = [   kSecAttrLabel as String : tag,
//                                       kSecAttrApplicationTag as String: tagData as Any,
                                      kSecClass as String: kSecClassCertificate ]
        
        
        let status = SecItemDelete(query as CFDictionary)
        
        
        // IF: item not found
        guard status != errSecItemNotFound else {
//            print(DEBUG_TAG+"\tCertificate deletion unsuccessful; no item found for tag \'\(tag)\'")
            return
        }
        
        
        guard status == errSecSuccess else {
            throw errorForOSStatus(status)
        }
        
        
//        print(DEBUG_TAG+"\tCertificate deleted successfully")
    }
    
    
    
    // MARK: - Private Keys
    
    
    
    
    //MARK: - save
    static func savePrivateKey(_ data: SecKey, forTag tag: String) throws {
        
//        print(DEBUG_TAG+"Saving private key for tag \'\(tag)\'")
        
        let tagData = tag.data(using: .utf8)
        
        let query: [String: Any ] = [ kSecAttrApplicationTag as String : tagData as Any,
                                      kSecValueRef as String: data,
                                      kSecClass as String: kSecClassKey ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // IF: duplicate item
        if status == errSecDuplicateItem {
//            print(DEBUG_TAG+"\tDuplicate private key found for tag \"\(tag)\"")
            throw KeyMasterError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw errorForOSStatus(status)
        }
        
//        print(DEBUG_TAG+"\tPrivate key saved successfully")
    }
    
    
    //
    // MARK: - read
    static func readPrivateKey(forTag tag: String) throws -> SecKey {
        
//        print(DEBUG_TAG+"Searching for private key with tag \'\(tag)\'")
        
        let tagData = tag.data(using: .utf8)
        
        let query: [String: Any] = [ kSecAttrApplicationTag as String: tagData as Any,
                                     
                                     kSecClass as String: kSecClassKey,
                                     kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                                     
                                     kSecMatchLimit as String: kSecMatchLimitOne,
                                     
                                     kSecReturnRef as String : kCFBooleanTrue as Any  ]
        
        var itemCopy: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary,
                                         &itemCopy)
        
        
        // IF: item not found
        guard status != errSecItemNotFound else {
//            print(DEBUG_TAG+"\tNo private key found for key \(tag)")
            throw KeyMasterError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw errorForOSStatus(status)
        }
        
//        print(DEBUG_TAG+"\tSuccessfully retrieved private key for tag \'\(tag)\'")
        return itemCopy as! SecKey
    }
    
    
    //MARK: - delete
    static func deletePrivateKey(forTag tag: String) throws {
        
//        print(DEBUG_TAG+"Deleting private key for tag \'\(tag)\'")
        
        let tagData = tag.data(using: .utf8)
        
        let query: [String: Any] = [  kSecAttrApplicationTag as String: tagData as Any,
                                      kSecClass as String: kSecClassKey ]
        
        
        let status = SecItemDelete(query as CFDictionary)
        
        
        // IF: item not found
        guard status != errSecItemNotFound else {
//            print(DEBUG_TAG+"\tPrivate key deletion unsuccessful: no item found for tag \'\(tag)\'")
            return
        }
        
        
        guard status == errSecSuccess else {
            throw errorForOSStatus(status)
        }
        
//        print(DEBUG_TAG+"\tPrivate key deleted successfully")
    }
    
    
    
    
    private static func errorForOSStatus(_ status: OSStatus) -> NSError {
        
        let description = SecCopyErrorMessageString(status, nil) ?? "Undefined Error" as CFString
        
        return NSError(domain: NSOSStatusErrorDomain,
                       code: Int(status),
                       userInfo: [NSLocalizedDescriptionKey: description] )
    }
    
}
