//
//  Authenticator.swift
//  Warpinator
//
//  Created by William Millington on 2021-10-07.
//

import Foundation
import NIOSSL
import CryptoKit


import Sodium

import ShieldSecurity
import ShieldCrypto

import ShieldX509
import ShieldX500

import ShieldOID
import ShieldPKCS

import PotentASN1



final class Authenticator {
    
    private let DEBUG_TAG: String = "Authenticator: "
    
    public var DEFAULT_GROUP_CODE: String = "Warpinator"
    
    public lazy var groupCode: String = DEFAULT_GROUP_CODE
    
    
//    private var serverCertDERData: [UInt8]? = nil
//    private var serverCertPEMData: [UInt8]? {
//        guard let derData = serverCertDERData else { return nil }
//        return convertDERBytesToPEM(derData)
//    }
//
//    private var serverCert: NIOSSLCertificate? {
//        guard let data = serverCertDERData,
//              let cert = try? NIOSSLCertificate.init(bytes: data, format: .der) else { return nil }
//        return cert
//    }
//
//
//    private var serverKeyData: [UInt8]? = nil
//    private var serverKey: NIOSSLPrivateKey? {
//        guard let keyData = serverKeyData,
//              let key = try? NIOSSLPrivateKey.init(bytes: keyData, format: .der) else { return nil }
//
//        return key
//    }
    
    
    static var shared: Authenticator = Authenticator()
    
    private init(){
        
    }
    
    
    // MARK: - unbox cert string
    func unlockCertificate(_ certificateString: String) -> NIOSSLCertificate? {
        guard let decodedCertificateData = Data(base64Encoded: certificateString,
                                                options: .ignoreUnknownCharacters) else {
            print(DEBUG_TAG+"error decoding certificateString"); return nil
        }
        
        return unlockCertificate(decodedCertificateData)
    }
    
    
    
    // MARK: - unbox cert data
    func unlockCertificate(_ certificateData: Data) -> NIOSSLCertificate? {
        
        
        let keyCode = SettingsManager.shared.groupCode
        let keyCodeBytes = Array(keyCode.utf8)
        

        let encryptedKey = SHA256.hash(data: keyCodeBytes )
        let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })

        let sKey = SecretBox.Key(encryptedKeyBytes)
        
        let decodedBytes: [UInt8] = Array( certificateData )
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
                
//               let _ = convertDERBytesToPEM( try! certificate.toDERBytes() )
//                print(DEBUG_TAG+"remote cert is \(convertDERBytesToPEM( try! certificate.toDERBytes() ) )")
                
                return certificate
                
            } catch {
                print(DEBUG_TAG+"problem creating certificate \(error.localizedDescription)")
            }
        } else {  print(DEBUG_TAG+"Failed to unbox certificate")  }
        
        return nil
    }
    
    
    
    
    // MARK: box cert
    func getCertificateDataForSending() -> String {
        
        // generate encryption-key from key-code
        let keyCode = SettingsManager.shared.groupCode
        let keyCodeBytes = Array(keyCode.utf8)
        
        
        let encryptedKey = SHA256.hash(data: keyCodeBytes )
        let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })
        
        let sKey = SecretBox.Key(encryptedKeyBytes)
        
        
        // load certificate bytes
//        let certificateBytes =  loadCertificateBytesFromFile()
//        guard let certificateBytes = serverCertPEMData else {
//            print(DEBUG_TAG+"problem with the cert data")
//            return "NOCERTIFICATEFORYOU"
//        }
        
        
        guard let certificateBytes = try? getServerCertificate().extended.pemBytes else {
            print(DEBUG_TAG+"problem with the cert pem data")
            return "PEM_DATA_UNAVAILABLE"
        }
        
        
        // encrypt bytes
        let sodium = Sodium()
        let sealedBox: (Bytes, SecretBox.Nonce)? = sodium.secretBox.seal(message: certificateBytes,
                                                                        secretKey: sKey)
        
        let nonce = sealedBox!.1
        let encryptedText = sealedBox!.0
        
        // arrange nonce + bytes into single array of bytes
        var messageBytes: [UInt8] = []
        
        for byte in nonce {
            messageBytes.append(byte)
        }
        
        for byte in encryptedText {
            messageBytes.append(byte)
        }
        
        
        // encode bytes to base64 string
        let messageBytesEncoded = Data(messageBytes).base64EncodedString()
        
        return messageBytesEncoded
    }
    
    
    
    // MARK: - server cert
    func getServerCertificate() throws -> NIOSSLCertificate {
        
//            let sec_cert = try loadCertificateFromKeychain()
        
        let uuid = SettingsManager.shared.uuid
        
        let sec_cert = try KeyMaster.readCertificate(forKey: uuid)
            
            let data = sec_cert.derEncoded
            
            return try NIOSSLCertificate(bytes: Array(data) , format: .der)
    }

    // MARK: - server p_key
    func getServerPrivateKey() throws -> NIOSSLPrivateKey {
        
//        let sec_key = try loadPrivateKeyFromKeychain()
        
        
        let uuid = SettingsManager.shared.uuid
        
        let sec_key = try KeyMaster.readPrivateKey(forKey: uuid)
        
        let keyBytes = try sec_key.encode()
        
        return try NIOSSLPrivateKey.init(bytes: Array(keyBytes), format: .der)
    }
    
    
    
    // MARK: - Generate credentials
    func generateNewCertificate() {
        
        print(DEBUG_TAG+"generating new server certificate...")
        
        // CREATE KEYS
        let keypair = try! SecKeyPair.Builder(type: .rsa, keySize: 2048).generate()

        let publicKey = keypair.publicKey
        let publicKeyEncoded = try! publicKey.encode()
        let pubKeyInfo = SubjectPublicKeyInfo(algorithm: try! AlgorithmIdentifier(publicKey: publicKey),
                                                  subjectPublicKey: publicKeyEncoded)
        
        let privateKey = keypair.privateKey
        
        
        // SET VALIDITY TIME FRAME
        let day_seconds: Double = 60 * 60 * 24      // seconds in a day
        let expirationTime: Double = 30 * day_seconds // one month

        let startDate = Date(timeInterval: -(day_seconds) , since: Date() ) // yesterday
        let endDate = Date(timeInterval: expirationTime, since: startDate) // one month from yesterday

        let startTime = AnyTime(date: startDate, timeZone: .init(secondsFromGMT: 0) ?? .current )
        let endTime = AnyTime(date: endDate, timeZone: .init(secondsFromGMT: 0)  ?? .current  )
        
        
//        // ===============TESTING CERTIFICATE EXPIRATION CHECKS===============
//        let expirationTime: Double = 60 // 30 seconds from now
//
//        let startDate = Date(timeInterval: -30 , since: Date() ) // 30 seconds ago
//        let endDate = Date(timeInterval: expirationTime, since: startDate) // one month from yesterday
//
//        let startTime = AnyTime(date: startDate, timeZone: .init(secondsFromGMT: 0) ?? .current )
//        let endTime = AnyTime(date: endDate, timeZone: .init(secondsFromGMT: 0)  ?? .current  )
//
////        print(DEBUG_TAG+"cert start: \(startTime)")
////        print(DEBUG_TAG+"cert end: \(endTime)")
//        //====================================================================
        
        
        // COMMON NAME
        let hostname = "WarpinatorIOS"
        let x500Name = try! NameBuilder.parse(string:"CN="+hostname)
        
        
        // SERIAL NUMBER
        let currentTime = Double(Date.timeIntervalBetween1970AndReferenceDate + Date.timeIntervalSinceReferenceDate)
        let serialNumber = TBSCertificate.SerialNumber( String(currentTime) )
        
        
        // -- EXTENSIONS
        
        // Subject Alternative Name: IP address
        let ipAddress = Utils.getIP_V4_Address()
        
        var IPparts: [UInt8] = [] // break apart IP string into
        ipAddress.components(separatedBy: ".").forEach { part in
            if let uint = UInt8(part) {
                IPparts.append(uint)
            }
        }
        
        let ipAddressExtension = GeneralName.ipAddress( Data( IPparts ) )
        
        
        // SUBJECT AND ISSUER KEY IDENTIFIERS (self-signed, so same identifier for both)
        let keyID: KeyIdentifier = Digester.digest( publicKeyEncoded, using: .sha1)
        
        // EXTENDED KEY USAGES
        let kp = iso.org.dod.internet.security.mechanisms.pkix.kp.self
        let usages: Set<OID> = [ kp.clientAuth.oid, kp.serverAuth.oid  ]
        
        
        // CREATE CERTIFICATE BUILDER
        let certBuilder = try! Certificate.Builder(serialNumber: serialNumber,
                                              issuer: x500Name,
                                              subject: x500Name,
                                              subjectPublicKeyInfo: pubKeyInfo,
                                              notBefore: startTime,
                                              notAfter: endTime)
            .subjectKeyIdentifier(keyID)
            .authorityKeyIdentifier(keyID)
            .basicConstraints(ca: true)
            .addSubjectAlternativeNames(names: ipAddressExtension)
            .extendedKeyUsage(keyPurposes: usages , isCritical: true)
            
            
        // CREATE/SIGN CERTIFICATE
        let digestAlgorithm = Digester.Algorithm.sha256
        let certificate = try! certBuilder.build(signingKey: privateKey,
                                                 digestAlgorithm: digestAlgorithm)
        
        
        let uuid = SettingsManager.shared.uuid
        
        do {
            
            guard let secCert = try certificate.sec() else {
                print(DEBUG_TAG+"could not create new certificate"); return
            }
            
            // delete old key
            try KeyMaster.deleteCertificate(forKey: uuid)
            
            // save new key
            try KeyMaster.saveCertificate(secCert , forKey: uuid)
            
            
//            do {
            try KeyMaster.deletePrivateKey(forKey: uuid)
//            } catch KeyMaster.KeyMasterError.itemNotFound {
//                print(DEBUG_TAG+"\t\tNo key to delete")
//            }
            
            try KeyMaster.savePrivateKey(privateKey, forKey: uuid)
            
            
//            try saveCertificateToKeychain(secCert)
        
//            try savePrivateKeyToKeychain(privateKey)
            
        } catch {
            print(DEBUG_TAG+"Error saving credentials:\n\t\t \(error)")
        }
        
    }
    
    
    
    
    // Attempt to convert DER bytes to a PEM encoding by appending header/footer
    // MARK: DER->PEM
    private func convertDERBytesToPEM(_ derBytes: [UInt8]) -> [UInt8] {
        
        let derBytesString = Data(derBytes).base64EncodedString()
        
        let pemBytesString = "-----BEGIN CERTIFICATE-----\n" + derBytesString + "\n-----END CERTIFICATE-----\n"
        
        return pemBytesString.bytes
    }
    
    
    //
    // MARK: verify
    func verify(certificate: NIOSSLCertificate) -> Bool {
                
        
        // verify that we're still in the certificate's valid timeframe
        let before = certificate.notValidBefore
        let after = certificate.notValidAfter
        
        let now = Int(Date().timeIntervalSince1970)
        
//        Date(timeIntervalSince1970: TimeInterval( before) )
        
//        print(DEBUG_TAG+"before: \(before) \t(\( Date(timeIntervalSince1970: TimeInterval( before) ) ))")
//        print(DEBUG_TAG+"now: \(now) \t(\( Date(timeIntervalSince1970: TimeInterval( now) ) ))")
//        print(DEBUG_TAG+"after: \(after) \t (\( Date(timeIntervalSince1970: TimeInterval( after) ) ))")
        
        
        
        return (now > before) && (now < after)
    }
    
}



// MARK: KeyMaster Access
extension Authenticator {
    
    
    
    

    // MARK load cert
//    private func loadCertificateFromKeychain() throws -> SecCertificate {
//
////        print(DEBUG_TAG+"load certificate from keychain")
//
//        let uuid = SettingsManager.shared.uuid
//
//        return try KeyMaster.readCertificate(forKey: uuid)
//
//    }

    // MARK save cert
//    func saveCertificateToKeychain(_ cert: SecCertificate) throws {
//
////        print(DEBUG_TAG+"saving certificate to keychain")
//
//        let uuid = SettingsManager.shared.uuid
//
//
//        // delete old key
////        print(DEBUG_TAG+"\t\tdeleting old certificate...")
//        do {
//            try KeyMaster.deleteCertificate(forKey: uuid)
//        } catch KeyMaster.KeyMasterError.itemNotFound {
//            print(DEBUG_TAG+"\t\tNo certificate to delete")
//        }
//
//        try KeyMaster.saveCertificate(cert , forKey: uuid)
//
//    }
    
    
    

    // MARK load key
//    private func loadPrivateKeyFromKeychain() throws -> SecKey {
//
////        print(DEBUG_TAG+"load private key from keychain")
//
//        let uuid = SettingsManager.shared.uuid
//
//        return try KeyMaster.readPrivateKey(forKey: uuid)
//
////        do {
//
////            let seckey = try KeyMaster.readPrivateKey(forKey: uuid)
////            let pkBytes = try seckey.encode()
////
////            let privateKey = try NIOSSLPrivateKey(bytes: Array(pkBytes), format: .der)
//
//
//
////        } catch let error as KeyMaster.KeyMasterError {
////            print(DEBUG_TAG+"loadPrivateKeyFromKeychain KeyMaster error: \(error)")
////        } catch {
////            print(DEBUG_TAG+"couldn't create NIOSSLPrivateKey from data \(error)")
////        }
//
//
////        return nil
//    }
    
    
    
    // MARK save key
//    func savePrivateKeyToKeychain(_ key: SecKey) throws {
//
////        print(DEBUG_TAG+"saving private key to keychain")
//
//        let uuid = SettingsManager.shared.uuid
//
//        // delete old key
////        print(DEBUG_TAG+"\tdeleting old private key...")
//        do {
//            try KeyMaster.deletePrivateKey(forKey: uuid)
//        } catch KeyMaster.KeyMasterError.itemNotFound {
//            print(DEBUG_TAG+"\t\tNo key to delete")
//        }
//
//        try KeyMaster.savePrivateKey(key, forKey: uuid)
//
//    }
    
}





//extension Authenticator {
//
//    // MARK - mock bad credentials
//    func generateBadCertificate() {
//
//        print(DEBUG_TAG+"=========================================================================")
//        print(DEBUG_TAG+"=========================================================================")
//        print(DEBUG_TAG+"\t\t\tALERT")
//        print(DEBUG_TAG+"=========================================================================")
//        print(DEBUG_TAG+"=========================================================================")
//        print(DEBUG_TAG+"GENERATING BAD CREDENTIALS")
//
//        // CREATE KEYS
//        let keypair = try! SecKeyPair.Builder(type: .rsa, keySize: 2048)  .generate()
//
//        let publicKey = keypair.publicKey
//        let publicKeyEncoded = try! publicKey.encode()
//        let pubKeyInfo = SubjectPublicKeyInfo(algorithm: try! AlgorithmIdentifier(publicKey: publicKey),
//                                                  subjectPublicKey: publicKeyEncoded)
//
//        let privateKey = keypair.privateKey
//
//
//        // SET VALIDITY TIME FRAME
//        let day_seconds: Double = 60 * 60 * 24      // seconds in a day
////        let expirationTime: Double = 30 * day_seconds // one month
//        let expirationTime: Double = 2 * day_seconds // 4 days
//
//        let startDate = Date(timeInterval: -(day_seconds * 5) , since: Date() ) // 5 days ago
//        let endDate = Date(timeInterval: expirationTime, since: startDate) // should end 1 day ago
//
//
//        print(DEBUG_TAG+"startdate: \(startDate)")
//        print(DEBUG_TAG+"enddate: \(endDate)")
//
//
//
//        let startTime = AnyTime(date: startDate, timeZone: .init(secondsFromGMT: 0) ?? .current )
//        let endTime = AnyTime(date: endDate, timeZone: .init(secondsFromGMT: 0)  ?? .current  )
//
//
//        // COMMON NAME
//        let hostname = "WarpinatorIOS"
//        let x500Name = try! NameBuilder.parse(string:"CN="+hostname)
//
//
//        // SERIAL NUMBER
//        let currentTime = Double(Date.timeIntervalBetween1970AndReferenceDate + Date.timeIntervalSinceReferenceDate)
//        let serialNumber = TBSCertificate.SerialNumber( String(currentTime) )
//
//
//        // -- EXTENSIONS
//
//        // Subject Alternative Name: IP address
//        let ipAddress = Utils.getIP_V4_Address()
//
//        var IPparts: [UInt8] = [] // break apart IP string into
//        ipAddress.components(separatedBy: ".").forEach { part in
//            if let uint = UInt8(part) {
//                IPparts.append(uint)
//            }
//        }
//
//        let ipAddressExtension = GeneralName.ipAddress( Data( IPparts ) )
//
//
//        // SUBJECT AND ISSUER KEY IDENTIFIERS (self-signed, so same identifier for both)
//        let keyID: KeyIdentifier = Digester.digest( publicKeyEncoded, using: .sha1)
//
//        // EXTENDED KEY USAGES
//        let kp = iso.org.dod.internet.security.mechanisms.pkix.kp.self
//        let usages: Set<OID> = [ kp.clientAuth.oid, kp.serverAuth.oid  ]
//
//
//        // CREATE CERTIFICATE BUILDER
//        let certBuilder = try! Certificate.Builder(serialNumber: serialNumber,
//                                              issuer: x500Name,
//                                              subject: x500Name,
//                                              subjectPublicKeyInfo: pubKeyInfo,
//                                              notBefore: startTime,
//                                              notAfter: endTime)
//            .subjectKeyIdentifier(keyID)
//            .authorityKeyIdentifier(keyID)
//            .basicConstraints(ca: true)
//            .addSubjectAlternativeNames(names: ipAddressExtension)
//            .extendedKeyUsage(keyPurposes: usages , isCritical: true)
//
//
//        // CREATE/SIGN CERTIFICATE
//        let digestAlgorithm = Digester.Algorithm.sha256
//        let certificate = try! certBuilder.build(signingKey: privateKey,
//                                                 digestAlgorithm: digestAlgorithm)
//
//
//        do {
//
//
//            let secCert = try certificate.sec()
//            try saveCertificateToKeychain(secCert!)
//
//            try savePrivateKeyToKeychain(privateKey)
//
//        } catch {
//            print(DEBUG_TAG+"(MOCK) Error saving credentials:\n\t\t \(error)")
//        }
//
//    }
//
//}
