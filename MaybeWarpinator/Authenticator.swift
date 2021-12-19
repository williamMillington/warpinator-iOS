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
        
        
        let keyCode = "Warpinator"
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
    
    
    
    
    // MARK: box cert
    func getCertificateDataForSending() -> String {

        
        // generate encryption-key from key-code
        let keyCode = "Warpinator"
        let keyCodeBytes = Array(keyCode.utf8)
        
        let encryptedKey = SHA256.hash(data: keyCodeBytes )
        let encryptedKeyBytes: [UInt8] = encryptedKey.compactMap( {  return UInt8($0) })
        
        let sKey = SecretBox.Key(encryptedKeyBytes)
        
        
        let certificateBytes =  loadCertificateBytesFromFile()
        
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
    func getServerCertificate() -> NIOSSLCertificate {
        return loadNIOSSLCertificateFromFile()
    }
    
    // MARK: - server PK
    func getServerPrivateKey() -> NIOSSLPrivateKey {
        return loadServerPrivateKeyFromFile()
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
        
        let keypair = try! SecKeyPair.Builder(type: .rsa, keySize: 2048)  .generate()

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
        
        
        
        
        let ipAddress = Utils.getIPV4Address()
        let ipAddressExtension = GeneralName.ipAddress( Data(bytes: ipAddress.bytes, count: ipAddress.bytes.count) )
        
        let certBuilder = try! Certificate.Builder(serialNumber: certSerial,
                                              issuer: x500Name,
                                              subject: x500Name,
                                              subjectPublicKeyInfo: certPubKeyInfo,
                                              notBefore: startTime,
                                              notAfter: endTime)
            .addSubjectAlternativeNames(names: ipAddressExtension)
            .extendedKeyUsage(keyPurposes:   .init(arrayLiteral: OID("1.3.6.1.5.5.7.3.1")  ),
                              isCritical: true)
            
        
        
        let digestAlgorithm = Digester.Algorithm.sha256
        let certificate = try! certBuilder.build(signingKey: privateKey,
                                                 digestAlgorithm: digestAlgorithm)
        
        
        // delete old key, if exists
        if let _ = try? KeyMaster.readPrivateKey(forKey: uuid) {
            print(DEBUG_TAG+"key exists, deleting it")
            try? KeyMaster.deletePrivateKey(forKey: uuid)
        }
        
        
        
//        do {
//            let keydata = try privateKey.encode() as CFData
//            let attrs = try privateKey.attributes() as CFDictionary
//
//            let secKey =  SecKeyCreateWithData(keydata,
//                                               attrs, nil)!
//
//            try KeyMaster.savePrivateKey( secKey, forKey: uuid)
//
//        } catch let error as KeyMaster.KeyMasterError {
//            print(DEBUG_TAG+"generateNewCertificate KeyMaster error: \(error)")
//        } catch {
//            print(DEBUG_TAG+"some other error occured: \(error)")
//        }
        
        
        print(DEBUG_TAG+"Certificate Data: ")
        print(DEBUG_TAG+"\t Serial Number: \( certificate.tbsCertificate.serialNumber)")
        print(DEBUG_TAG+"\t SignatureAlgorithm: \( certificate.tbsCertificate.signature.algorithm)")
        print(DEBUG_TAG+"\t Issuer: \( certificate.tbsCertificate.issuer[0][0])")
        print(DEBUG_TAG+"\t Validity: \( certificate.tbsCertificate.validity)")
        print(DEBUG_TAG+"\t Subject: \( certificate.tbsCertificate.subject[0][0])")
        print(DEBUG_TAG+"\t Subject PUB KEY info: \( certificate.tbsCertificate.subjectPublicKeyInfo)")
        for ext in certificate.tbsCertificate.extensions! {
            print(DEBUG_TAG+"\t Extension: \(ext)")
        }
        print(DEBUG_TAG+"\t Signature: \( certificate.tbsCertificate.signature)")

        
        return try! certificate.encoded()
    }
    
    
}


// MARK: - Loading from file:
extension Authenticator {
    
    
    //MARK: -certificate
     func loadNIOSSLCertificateFromFile() -> NIOSSLCertificate {
        
        let certData = loadCertificateBytesFromFile()
        
        let cert = try! NIOSSLCertificate.fromPEMBytes(certData)[0]
        
        return cert
    }
    
    
    //MARK: -certificate Data
     func loadCertificateBytesFromFile() -> [UInt8] {
        
        let filename = "root"
        let ext = "pem"
        
        let filepath = Bundle.main.path(forResource: filename,
                                        ofType: ext)!
        
        let certURL = URL(fileURLWithPath: filepath)
        let certBytes = try! Data(contentsOf: certURL)
        
        return Array(certBytes)
    }
    
    
    
    
    //MARK: -private key
    private  func loadServerPrivateKeyFromFile() -> NIOSSLPrivateKey {
        
        let filename = "rootkey"
        let ext = "key"
        
        let filepath = Bundle.main.path(forResource: filename,
                                        ofType: ext)!
        
        let keyURL = URL(fileURLWithPath: filepath)
        let keyBytes = try! Data(contentsOf: keyURL)
        
        let privateKey = try! NIOSSLPrivateKey(bytes: Array(keyBytes), format: .pem)
        
        return privateKey
    }
}




// MARK loading creds from Keychain
//extension Authenticator {
//
//    //
//    private func loadCertificateFromKeychain() -> NIOSSLCertificate? {
//
//        do {
//            let certificate: NIOSSLCertificate
//            if let certBytes = try? KeyMaster.readCertificate(forKey: uuid) {
//
//                certificate = try NIOSSLCertificate(bytes: Array(certBytes), format: .der)
//
//            } else {
//                print(DEBUG_TAG+"no certificate found in keychain")
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
//            print(DEBUG_TAG+"getServerCertificate KeyMaster error: \(error)")
//        } catch {
//            print(DEBUG_TAG+"couldn't create NIOSSLCertificate from data \(error)")
//        }
//
//
//
//        return nil
//    }
//
//
//    //
//    private  func loadPrivateKeyFromKeychain() -> NIOSSLPrivateKey? {
//        do {
//
//            let seckey = try KeyMaster.readPrivateKey(forKey: uuid)
//            let pkBytes = try seckey.encode()
//
//            let privateKey = try NIOSSLPrivateKey(bytes: Array(pkBytes), format: .der)
//
//            return privateKey
//
//
//        } catch let error as KeyMaster.KeyMasterError {
//            print(DEBUG_TAG+"loadPrivateKeyFromKeychain KeyMaster error: \(error)")
//        } catch {
//            print(DEBUG_TAG+"couldn't create NIOSSLPrivateKey from data \(error)")
//        }
//
//
//        return nil
//    }
//}





