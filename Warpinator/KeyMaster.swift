//
//  KeyMaster.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-27.
//

import Foundation



class KeyMaster {
    
    enum KeyMasterError: Error {
        case itemNotFound
        case duplicateItem
        case invalidFormat
        case unexpectedStatus(OSStatus)
    }
    
    
    static let service: String = "warpinator"
    
    
    
    // MARK: - Certificates
    
    
    
    
    // MARK: - save
    // save DER data of X509 certificate
    static func saveCertificate(data: Data, forKey key: String) throws {
        
        
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            throw KeyMasterError.invalidFormat
        }
        
        
        let query: [String: Any] = [ kSecClass as String: kSecClassCertificate,
                                     kSecAttrLabel as String : key,
                                     kSecValueRef as String: certificate ]
        
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            throw KeyMasterError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw KeyMasterError.unexpectedStatus(status)
        }
    }
    
    
    //MARK: - read
    // read DER data of X509 certificate
    static func readCertificate(forKey key: String) throws -> Data {
        
        let query: [String: Any] = [ kSecClass as String: kSecClassCertificate,
                                     kSecAttrLabel as String : key,
                                     kSecMatchLimit as String: kSecMatchLimitOne,
                                     kSecReturnRef as String : kCFBooleanTrue ]
        
        var itemCopy: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary,
                                         &itemCopy)
        
        guard status != errSecItemNotFound else {
            throw KeyMasterError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw KeyMasterError.unexpectedStatus(status)
        }
        
        let item = itemCopy as! SecCertificate
        
        return item.derEncoded
    }
    
    
    //MARK: - delete
    static func deleteCertificate(forKey key: String) throws {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: key,
        ]
        
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecItemNotFound else {
            throw KeyMasterError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw KeyMasterError.unexpectedStatus(status)
        }
        
        
    }
    
    
    
    
    
    
    // MARK: - Private Keys
    
    
    
    
    //MARK: - save
    static func savePrivateKey(_ data: SecKey, forKey key: String) throws {
        
        let tag = key.data(using: .utf8)
//        let pk = SEckey
        
        
        let query: [String: Any ] = [
//            kSecAttrService as String : KeyMaster.service as AnyObject,
//            kSecAttrAccount as String : key as AnyObject,
            
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String : tag as Any,
            kSecValueRef as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary,
                                nil)
        
        if status == errSecDuplicateItem {
            throw KeyMasterError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw KeyMasterError.unexpectedStatus(status)
        }
    }
    
    
    //MARK: - read
    static func readPrivateKey(forKey key: String) throws -> SecKey {
        
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
        
        guard status != errSecItemNotFound else {
            throw KeyMasterError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw KeyMasterError.unexpectedStatus(status)
        }
        
        let item = itemCopy as! SecKey
        return item
    }
    
    
    //MARK: - delete
    static func deletePrivateKey(forKey key: String) throws {
        
        
        let query: [String: AnyObject] = [
            kSecAttrService as String : KeyMaster.service as AnyObject,
            kSecAttrAccount as String : key as AnyObject,
            
            kSecClass as String: kSecClassKey
        ]
        
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecItemNotFound else {
            throw KeyMasterError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw KeyMasterError.unexpectedStatus(status)
        }
        
    }
    
    
}
