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
    
    static var shared: Authenticator = Authenticator()
    
    
    private init(){
        
    }
    
    
    // MARK: - unlock cert string
    func unlockCertificate(_ certificateString: String) -> NIOSSLCertificate? {
        guard let decodedCertificateData = Data(base64Encoded: certificateString,
                                                options: .ignoreUnknownCharacters) else {
            print(DEBUG_TAG+"error decoding certificateString"); return nil
        }
        
        return unlockCertificate(decodedCertificateData)
    }
    
    
    
    // MARK: - unlock cert data
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
                
                return certificate
                
            } catch {
                print(DEBUG_TAG+"problem creating certificate \(error.localizedDescription)")
            }
        } else {  print(DEBUG_TAG+"Failed to unbox certificate")  }
        
        return nil
    }
    
    
    
    
    // MARK: lock cert
    func getCertificateDataForSending() -> String {
        
        // generate encryption-key from key-code
        let keyCode = SettingsManager.shared.groupCode
        let keyCodeBytes = Array(keyCode.utf8)
        
        
        let encryptedKey = SHA256.hash(data: keyCodeBytes )
        let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })
        
        let sKey = SecretBox.Key(encryptedKeyBytes)
        
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

    
    
    
    
    // MARK: getServerCredentials
    typealias Credentials = (certificate: NIOSSLCertificate, key: NIOSSLPrivateKey)
    var credential_generation_attempts: Int = 0
    
    func getServerCredentials() throws -> Credentials {
        
        credential_generation_attempts += 1
        
        // if, for some unknown reason, we can't generate credentials,
        // don't attempt endlessly.
        guard credential_generation_attempts < 5 else {
            throw AuthenticationError.CREDENTIALS_GENERATION_ERROR
        }
        
        
        let credentials: Credentials
        do {
            
            let cert = try getServerCertificate()
            let key = try getServerPrivateKey()
            
            
            // check cert is still valid  (certs only last 1 month)
            guard verify(certificate: cert) else {
                throw AuthenticationError.CREDENTIALS_INVALID
            }
            
            credentials = (cert, key)
            
        } catch AuthenticationError.CREDENTIALS_INVALID, KeyMaster.KeyMasterError.itemNotFound {
            
            //TODO: unnecessary to catch invalid credentials. But need to catch itemnotfound
            
            generateNewCertificate()
            
            return try getServerCredentials()
        } // If an error of any other type occurs,
        // then something real broken, so let it propogate back up
        
        credential_generation_attempts = 0 // reset upon success
        return credentials
    }
    
    
    // MARK: cert
    func getServerCertificate() throws -> NIOSSLCertificate {
        
        let sec_cert = try KeyMaster.readCertificate(forTag: SettingsManager.shared.uuid)
        
        let bytes = Array(sec_cert.derEncoded)
        
        return try NIOSSLCertificate(bytes: bytes , format: .der)
    }

    // MARK: private key
    func getServerPrivateKey() throws -> NIOSSLPrivateKey {
        
        let sec_key = try KeyMaster.readPrivateKey(forTag: SettingsManager.shared.uuid)
        
        let keyBytes = Array( try sec_key.encode() )
        
        return try NIOSSLPrivateKey.init(bytes: keyBytes, format: .der)
    }
    
    
    
    
    func deleteCredentials(){
        
        do {
            let uuid = SettingsManager.shared.uuid
            
            // delete certificate
            try KeyMaster.deleteCertificate(forTag: uuid)
            
            // delete key
            try KeyMaster.deletePrivateKey(forTag: uuid)
            
        } catch {
            print(DEBUG_TAG+"Error deleting credentials:\n\t\t \(error)")
        }
    }
    
    
    
    
    
    // MARK: - Generate credentials
    func generateNewCertificate() {
        
        print(DEBUG_TAG+"generating new server certificate...")
        
        //
        // CREATE KEYS
        let keypair = try! SecKeyPair.Builder(type: .rsa, keySize: 2048).generate()

        let publicKey = keypair.publicKey
        let publicKeyEncoded = try! publicKey.encode()
        let pubKeyInfo = SubjectPublicKeyInfo(algorithm: try! AlgorithmIdentifier(publicKey: publicKey),
                                                  subjectPublicKey: publicKeyEncoded)
        
        let privateKey = keypair.privateKey
        
        
        //
        // SET VALIDITY TIME FRAME
        let day_seconds: Double = 60 * 60 * 24      // seconds in a day
        let expirationTime: Double = 30 * day_seconds // one month

        let startDate = Date(timeInterval: -(day_seconds) , since: Date() ) // yesterday
        let endDate = Date(timeInterval: expirationTime, since: startDate) // one month from yesterday

        let startTime = AnyTime(date: startDate, timeZone: .init(secondsFromGMT: 0) ?? .current )
        let endTime = AnyTime(date: endDate, timeZone: .init(secondsFromGMT: 0)  ?? .current  )
        
        
        //
        // COMMON NAME
        let hostname = "WarpinatorIOS"
        let x500Name = try! NameBuilder.parse(string:"CN="+hostname)
        
        
        //
        // SERIAL NUMBER
        let currentTime = Double(Date.timeIntervalBetween1970AndReferenceDate + Date.timeIntervalSinceReferenceDate)
        let serialNumber = TBSCertificate.SerialNumber( String(currentTime) )
        
        
        
        // -- CERTIFICATE EXTENSIONS --
        
        
        //
        // Subject Alternative Name: IP address
        let ipAddress = Utils.getIP_V4_Address()
        
        var IPparts: [UInt8] = [] // break apart IP string into
        ipAddress.components(separatedBy: ".").forEach { part in
            if let uint = UInt8(part) {
                IPparts.append(uint)
            }
        }
        
        let ipAddressExtension = GeneralName.ipAddress( Data( IPparts ) )
        
        
        //
        // SUBJECT AND ISSUER KEY IDENTIFIERS (self-signed, so same identifier for both)
        let keyID: KeyIdentifier = Digester.digest( publicKeyEncoded, using: .sha1)
        
        //
        // EXTENDED KEY USAGES
        let kp = iso.org.dod.internet.security.mechanisms.pkix.kp.self
        let usages: Set<OID> = [ kp.clientAuth.oid, kp.serverAuth.oid  ]
        
        
        //
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
            
            
        //
        // CREATE/SIGN CERTIFICATE
        let digestAlgorithm = Digester.Algorithm.sha256
        let certificate = try! certBuilder.build(signingKey: privateKey,
                                                 digestAlgorithm: digestAlgorithm)
        
        
        let uuid = SettingsManager.shared.uuid
        
        do {
            
            guard let secCert = try certificate.sec() else {
                print(DEBUG_TAG+"could not create new certificate"); return
            }
            
            // delete old certificate
            try KeyMaster.deleteCertificate(forTag: uuid)
            
            // save new certificate
            try KeyMaster.saveCertificate(secCert , withTag: uuid)
            
            
            // delete old key
            try KeyMaster.deletePrivateKey(forTag: uuid)
            
            // save new key
            try KeyMaster.savePrivateKey(privateKey, forTag: uuid)
            
            
        } catch {
            print(DEBUG_TAG+"Error saving credentials:\n\t\t \(error)")
        }
        
    }
    
    
    //
    // MARK: verify cert
    // verify that we're still in the certificate's valid timeframe
    func verify(certificate: NIOSSLCertificate) -> Bool {
        
        let now = Int( Date().timeIntervalSince1970 )
        
        // check that we're between 'not before' and 'not after'
        return (certificate.notValidBefore < now)  &&  (now < certificate.notValidAfter)
    }
}
