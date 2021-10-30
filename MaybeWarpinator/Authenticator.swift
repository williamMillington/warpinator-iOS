//
//  Authenticator.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-10-07.
//

import Foundation
import NIOSSL
import CryptoKit


// 3rd party
import Sodium
import ShieldX509
import ShieldX500
import ShieldSecurity
import ShieldCrypto

import PotentASN1

class Authenticator {
    
    private let DEBUG_TAG: String = "Authenticator: "
    
    public  var DEFAULT_GROUP_CODE: String = "Warpinator"
    
    public lazy var groupCode: String = DEFAULT_GROUP_CODE
    
    static var shared: Authenticator = Authenticator()
    
    public var certificates: [String : NIOSSLCertificate] = [:]
    
    
    public var uuid: String = "WarpinatorIOS"
    public lazy var hostname = uuid
    
    
    
    private init(){
        
    }
    
    
    //
    func unlockCertificate(_ certificateString: String){
        
        guard let decodedCertificateData = Data(base64Encoded: certificateString, options: .ignoreUnknownCharacters) else {
            print(DEBUG_TAG+"error decoding certificateString"); return
        }
        
        
        let keyCode = "Warpinator"
        let keyCodeBytes = Array(keyCode.utf8)

        let encryptedKey = SHA256.hash(data: keyCodeBytes )
        let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })

        let sKey = SecretBox.Key(encryptedKeyBytes)
        
        let decodedBytes: [UInt8] = Array( decodedCertificateData )
        var nonce: [UInt8] = []
        var cipherText: [UInt8] = []

        for i in 0..<24 {
            nonce.append( decodedBytes[i] )
        }

        for i in 0..<(decodedBytes.count - 24) {
            cipherText.append(  decodedBytes[ i + 24 ] )
        }

        let sodium = Sodium()
        let snonce = SecretBox.Nonce(nonce)
        let certificateBytes = sodium.secretBox.open(authenticatedCipherText: cipherText,
                                                     secretKey: sKey,
                                                     nonce: snonce)
        
        if let bytes = certificateBytes {
            
            do {
                let certificate = try NIOSSLCertificate(bytes: bytes, format: .pem)
                
                print(DEBUG_TAG+"Success creating certificate from bytes: \(certificate)")
                
                
            } catch {
                print(DEBUG_TAG+"problem creating certificate \(error.localizedDescription)")
            }
        } else {  print(DEBUG_TAG+"Failed to unbox certificate")  }
        
    }
    
    
    
    
    
    //
    func getBoxedCertificate() -> Bytes {
        
        let key = SHA256.hash(data: Array("Warpinator".utf8) )
        let keyBytes: [UInt8] = key.compactMap( {  return UInt8($0) })
        
        
        let certBytes = Authenticator.shared.getServerCertificateBytes()!
        
        
        let sodium = Sodium()
        let skey = SecretBox.Key(keyBytes)
        
        let secretBox: Bytes = sodium.secretBox.seal(message: Array(certBytes), secretKey: skey)!
        
        return secretBox
    }
    
    
    //
    func getServerCertificateBytes() -> Data? {
        
        do {
            
            if let certBytes = try? KeyMaster.readCertificate(forKey: uuid) {
                return certBytes
                
            } else {
                print(DEBUG_TAG+"no certificate in keychain")
                
                let certBytes = generateNewCertificate(forHostname: uuid)
                
                try KeyMaster.saveCertificate(data: certBytes, forKey: uuid)
                
                
                return certBytes
            }
            
        } catch let error as KeyMaster.KeyMasterError {
            print("getServerCertificateBytes KeyMaster error: \(error)")
        } catch {
            print("couldn't create NIOSSLCertificate from data \(error)")
        }
        return nil
    }
    
    
    
    //
    func getServerCertificate() -> NIOSSLCertificate? {
//
        
//        return loadCertificateFromFile()
        return loadCertificateFromKeychain()
        
//        do {
//
//            let certificate: NIOSSLCertificate
//            if let certBytes = try? KeyMaster.readCertificate(forKey: uuid) {
//
//                certificate = try NIOSSLCertificate(bytes: Array(certBytes), format: .der)
//
//            } else {
//                print(DEBUG_TAG+"no certificate in keychain")
//
//                let certBytes = generateNewCertificate(forHostname: uuid)
//
//                certificate = try NIOSSLCertificate(bytes: Array(certBytes), format: .der)
//
//                try KeyMaster.saveCertificate(data: certBytes, forKey: uuid)
//
//            }
//
//            return certificate
//
//        } catch let error as KeyMaster.KeyMasterError {
//            print("getServerCertificate KeyMaster error: \(error)")
//        } catch {
//            print("couldn't create NIOSSLCertificate from data \(error)")
//        }
//
//
//
//        return nil
    }
    
    
    func getServerPrivateKey() -> NIOSSLPrivateKey? {

//        return loadPrivateKeyFromFile()
        return loadPrivateKeyFromFile()
        
//        do {
//
//            let seckey = try KeyMaster.readPrivateKey(forKey: uuid)
//            let pkBytes = try seckey.encode()
//
//            let privateKey = try NIOSSLPrivateKey(bytes: Array(pkBytes), format: .der)
//
//            return privateKey
//
//        } catch let error as KeyMaster.KeyMasterError {
//            print(DEBUG_TAG+"getServerPrivateKey PK KeyMaster error: \(error)")
//        } catch {
//            print(DEBUG_TAG+"couldn't create NIOSSLPrivateKey from data \(error)")
//        }
//
//
//        return nil
    }
    
    
    
    
    // MARK: - Generate certificate
    func generateNewCertificate(forHostname hostname: String) -> Data {
        
        print(DEBUG_TAG+"generating new server certificate...")
        
        
        var sanitizedHostname = hostname.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
//        print(DEBUG_TAG+"\tsanitized hostname: \(sanitizedHostname)")
        
        if sanitizedHostname.trimmingCharacters(in:[" "]).isEmpty{
            sanitizedHostname = "iOS-Warpinator"
        }
        
        sanitizedHostname = "WarpinatorIOS"
        
        let keypair = try! SecKeyPair.Builder(type: .rsa, keySize: 2048).generate()

        let publicKey = keypair.publicKey
        let publicKeyEncoded = try! publicKey.encode()
        
        let privateKey = keypair.privateKey
        
        // milliseconds in a day
        let day_seconds: Double = 60 * 60 * 24
        let expirationTime:Double = 30 * day_seconds
        
        let currentTime = Double(Date.timeIntervalBetween1970AndReferenceDate + Date.timeIntervalSinceReferenceDate)
        let serial = String(currentTime) //use current time as serial number
        
        let start = Date(timeInterval: -(day_seconds / 1000) , since: Date() ) // yesterday
        let end = Date(timeInterval: expirationTime, since: start) // one month from start
        
        
        let x500Name = try! NameBuilder.parse(string:"CN="+sanitizedHostname)
        let certSerial = TBSCertificate.SerialNumber(serial)
        
        let startTime = AnyTime(date: start, timeZone: .current)
        let endTime = AnyTime(date: end, timeZone: .current)
        
        
        
        let certPubKeyInfo = SubjectPublicKeyInfo(algorithm: try! AlgorithmIdentifier(publicKey: publicKey),
                                                  subjectPublicKey: publicKeyEncoded)
        
        
        
        
        let ipAddress = Utils.getIPAddress()
        let ipAddressExtension = GeneralName.ipAddress( Data(bytes: ipAddress.bytes, count: ipAddress.bytes.count) )
        
        let certBuilder = try! Certificate.Builder(serialNumber: certSerial,
                                              issuer: x500Name,
                                              subject: x500Name,
                                              subjectPublicKeyInfo: certPubKeyInfo,
                                              notBefore: startTime,
                                              notAfter: endTime)
            .addSubjectAlternativeNames(names: ipAddressExtension)
            .extendedKeyUsage(keyPurposes: .init(arrayLiteral: OID("id-kp-serverAuth") ) , isCritical: true)
        
        
        
        let digestAlgorithm = Digester.Algorithm.sha256
        let certificate = try! certBuilder.build(signingKey: privateKey,
                                                 digestAlgorithm: digestAlgorithm)
        
        
        // delete old key, if exists
        if let _ = try? KeyMaster.readPrivateKey(forKey: uuid) {
            print(DEBUG_TAG+"key exists, deleting it")
            try? KeyMaster.deletePrivateKey(forKey: uuid)
        }
        
        do {
            let keydata = try privateKey.encode() as CFData
            let attrs = try privateKey.attributes() as CFDictionary
            
            let secKey =  SecKeyCreateWithData(keydata,
                                               attrs, nil)!
            
            try KeyMaster.savePrivateKey( secKey, forKey: uuid)
            
        } catch let error as KeyMaster.KeyMasterError {
            print(DEBUG_TAG+"generateNewCertificate KeyMaster error: \(error)")
        } catch {
            print(DEBUG_TAG+"some other error occured: \(error)")
        }
        
        
        return try! certificate.encoded()
    }
    
    
}


// MARK: - loading creds from file
extension Authenticator {
    
    //
    private  func loadCertificateFromFile() -> NIOSSLCertificate? {
        
        let certificateFilePath = Bundle.main.path(forResource: "certificate",
                                                   ofType: "cer")!
        
        do {
            
            let certURL = URL(fileURLWithPath: certificateFilePath)
            let certBytes = try! Data(contentsOf: certURL)
            
            print(DEBUG_TAG+"loading certificate")
            let certificate = try NIOSSLCertificate(bytes: Array(certBytes), format: .pem)
            
            return certificate
            
        } catch {
            print("Error loading certificate from file \(error)")
        }
        return nil
    }
    
    
    //
    private  func loadPrivateKeyFromFile() -> NIOSSLPrivateKey? {
        
        let privateKeyPath  = Bundle.main.path(forResource: "certificate_key",
                                               ofType: "key")!
        
        do {
            
            let keyURL = URL(fileURLWithPath: privateKeyPath)
            let keyBytes = try! Data(contentsOf: keyURL)
            
            print(DEBUG_TAG+"loading private key")
            let privateKey = try NIOSSLPrivateKey(bytes: Array(keyBytes), format: .pem)
            
            return privateKey
            
        } catch {
            print("Error loading private key from file \(error)")
        }
        return nil
    }
}



// MARK: - loading creds from Keychain
extension Authenticator {
    
    //
    private func loadCertificateFromKeychain() -> NIOSSLCertificate? {
        
        do {
            let certificate: NIOSSLCertificate
            if let certBytes = try? KeyMaster.readCertificate(forKey: uuid) {

                certificate = try NIOSSLCertificate(bytes: Array(certBytes), format: .der)

            } else {
                print(DEBUG_TAG+"no certificate found in keychain")

                let certBytes = generateNewCertificate(forHostname: uuid)

                certificate = try NIOSSLCertificate(bytes: Array(certBytes), format: .der)

                try KeyMaster.saveCertificate(data: certBytes, forKey: uuid)

            }

            return certificate

        } catch let error as KeyMaster.KeyMasterError {
            print("getServerCertificate KeyMaster error: \(error)")
        } catch {
            print("couldn't create NIOSSLCertificate from data \(error)")
        }



        return nil
    }
    
    
    //
    private  func loadPrivateKeyFromKeychain() -> NIOSSLPrivateKey? {
        do {
            
            let seckey = try KeyMaster.readPrivateKey(forKey: uuid)
            let pkBytes = try seckey.encode()
            
            let privateKey = try NIOSSLPrivateKey(bytes: Array(pkBytes), format: .der)
                
            return privateKey
            
            
        } catch let error as KeyMaster.KeyMasterError {
            print(DEBUG_TAG+"loadPrivateKeyFromKeychain KeyMaster error: \(error)")
        } catch {
            print(DEBUG_TAG+"couldn't create NIOSSLPrivateKey from data \(error)")
        }
        
        
        return nil
    }
}





