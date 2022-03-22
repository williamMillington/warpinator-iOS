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
//        case unexpectedStatus(OSStatus)
    }
    
    
    static let service: String = "warpinator"
    
    
    
    // MARK: - Certificates
    
    
    // MARK save
    // save DER data of X509 certificate
    static func saveCertificate(data: [UInt8], forKey key: String) throws {
        try saveCertificate(data: Data(data) , forKey: key)
    }
    
    // MARK save
    // save DER data of X509 certificate
    static func saveCertificate(data: Data, forKey key: String) throws {
        
        
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            throw KeyMasterError.invalidFormat
        }
        
        print(DEBUG_TAG+"saving certificate")
        
        let query: [String: Any] = [ kSecClass as String: kSecClassCertificate,
                                     kSecAttrLabel as String : key,
                                     kSecValueRef as String: certificate ]
        
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        
        // IF: duplicate item
        if status == errSecDuplicateItem {
            print(DEBUG_TAG+"Duplicate Certificate")
            throw KeyMasterError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
//            throw KeyMasterError.unexpectedStatus(status)
        }
//        try saveCertificate(certificate, forKey: key)
        print(DEBUG_TAG+"\t\t (DATA) certificate saved successfully")
    }
    
    
    // MARK: save
    // save SecCertificate
    static func saveCertificate(_ certificate: SecCertificate, forKey key: String) throws {
        
        print(DEBUG_TAG+"saving certificate")
        
        let query: [String: Any] = [ kSecClass as String: kSecClassCertificate,
                                     kSecAttrLabel as String : key,
                                     kSecValueRef as String: certificate ]
        
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // IF: duplicate item
        if status == errSecDuplicateItem {
            print(DEBUG_TAG+"Duplicate Certificate")
            throw KeyMasterError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
//            throw KeyMasterError.unexpectedStatus(status)
        }
        
        
        print(DEBUG_TAG+"\t\t (SEC) certificate saved successfully")
    }
    
    
    
    
    
    //MARK: - read
    // read DER data of X509 certificate
//    static func readCertificate(forKey key: String) throws -> Data {
//
//        let query: [String: Any] = [ kSecClass as String: kSecClassCertificate,
//                                     kSecAttrLabel as String : key,
//                                     kSecMatchLimit as String: kSecMatchLimitOne,
//                                     kSecReturnRef as String : kCFBooleanTrue ]
//
//        var itemCopy: CFTypeRef?
//        let status = SecItemCopyMatching(query as CFDictionary,
//                                         &itemCopy)
//
//        guard status != errSecItemNotFound else {
//            throw KeyMasterError.itemNotFound
//        }
//
//        guard status == errSecSuccess else {
//            throw KeyMasterError.unexpectedStatus(status)
//        }
//
//        let item = itemCopy as! SecCertificate
//
//        return item.derEncoded
//    }
    static func readCertificate(forKey key: String) throws -> SecCertificate {
        
        print(DEBUG_TAG+"reading certificate")
        
        let query: [String: Any] = [ kSecClass as String: kSecClassCertificate,
                                     kSecAttrLabel as String : key,
//                                     kSecMatchLimit as String: kSecMatchLimitOne,
                                     kSecReturnRef as String : kCFBooleanTrue ]
        
        var itemCopy: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary,
                                         &itemCopy)
        
        
        // IF: item not found
        if status == errSecItemNotFound {
            print(DEBUG_TAG+"Certificate not found")
            throw KeyMasterError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
//            throw KeyMasterError.unexpectedStatus(status)
        }
        
        return itemCopy as! SecCertificate
    }
    
    
    //MARK: - delete
    static func deleteCertificate(forKey key: String) throws {
        
        print(DEBUG_TAG+"deleting certificate")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: key,
        ]
        
        
        let status = SecItemDelete(query as CFDictionary)
        
        
        // IF: item not found
        if status == errSecItemNotFound {
            print(DEBUG_TAG+"Certificate not found")
            throw KeyMasterError.itemNotFound
        }
        
        
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
//            throw KeyMasterError.unexpectedStatus(status)
        }
        
        
        print(DEBUG_TAG+"\t\tcertificate deleted successfully")
    }
    
    
    
    
    
    
    // MARK: - Private Keys
    
    
    
    
    //MARK: - save
    static func savePrivateKey(_ data: SecKey, forKey key: String) throws {
        
        
        print(DEBUG_TAG+"saving private key")
        
        
        let tag = key.data(using: .utf8)
//        let pk = SEckey
        
        
        let query: [String: Any ] = [
//            kSecAttrService as String : KeyMaster.service as AnyObject,
//            kSecAttrAccount as String : key as AnyObject,
            
            kSecAttrApplicationTag as String : tag as Any,
            kSecValueRef as String: data,
            kSecClass as String: kSecClassKey
        ]
        
        let status = SecItemAdd(query as CFDictionary,
                                nil)
        
        
        // IF: duplicate item
        if status == errSecDuplicateItem {
            print(DEBUG_TAG+"Duplicate Private Key ")
            throw KeyMasterError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
//            throw KeyMasterError.unexpectedStatus(status)
        }
        
        print(DEBUG_TAG+"\t\tprivate key saved successfully")
    }
    
    
    //MARK: - read
    static func readPrivateKey(forKey key: String) throws -> SecKey {
        
        print(DEBUG_TAG+"reading private key")
        
        let tag = key.data(using: .utf8)
        
        let query: [String: Any] = [
//            kSecAttrService as String : KeyMaster.service as AnyObject,
//            kSecAttrAccount as String : key as AnyObject,
            kSecAttrApplicationTag as String: tag as Any,
            
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            
            kSecMatchLimit as String: kSecMatchLimitOne,
            
            kSecReturnRef as String : kCFBooleanTrue as Any
        ]
        
        var itemCopy: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary,
                                         &itemCopy)
        
        
        // IF: item not found
        if status == errSecItemNotFound {
            print(DEBUG_TAG+"Private Key not found")
            throw KeyMasterError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
//            throw KeyMasterError.unexpectedStatus(status)
        }
        
        let item = itemCopy as! SecKey
        return item
    }
    
    
    //MARK: - delete
    static func deletePrivateKey(forKey key: String) throws {
        
        print(DEBUG_TAG+"deleting private key")
        
        let tag = key.data(using: .utf8)
        
        let query: [String: Any] = [
                kSecAttrApplicationTag as String: tag as Any,
//            kSecAttrService as String : KeyMaster.service,
//                                     kSecAttrAccount as String : key,
                                     kSecClass as String: kSecClassKey ]
        
        
        let status = SecItemDelete(query as CFDictionary)
        
        
        // IF: item not found
        if status == errSecItemNotFound {
            print(DEBUG_TAG+"Private Key not found")
            throw KeyMasterError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
//            throw KeyMasterError.unexpectedStatus(status)
        }
        
        print(DEBUG_TAG+"\t\tprivate key deleted successfully")
    }
    
    
}
