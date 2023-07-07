//
//  PushMessagingContentDecrypterService.swift
//  domains-manager-ios
//
//  Created by Oleg Kuplin on 09.06.2023.
//

import Foundation
import Push

final class PushMessagingContentDecrypterService: MessagingContentDecrypterService {
    
    private var pgpKeysCache = [String : String]()
    
    func encryptText(_ text: String, with serviceMetadata: Data?, wallet: String) throws -> String {
        guard let serviceMetadata,
              let pgpKey = getPGPKeyFor(wallet: wallet),
              let messageMetadata = (try? JSONDecoder().decode(PushEnvironment.MessageServiceMetadata.self, from: serviceMetadata)) else {
            throw EncryptionError.failedToGatherRequiredData
        }
        
        //        let aesKey = getRandomHexString(length: 15)
        //        let cipherText = AESCBCHelper.encrypt(messageText: text, secretKey: aesKey)
        //        let encryptedAES = try Pgp.pgpEncryptV2(message: aesKey, pgpPublicKeys: publicKeys)
        //        messageMetadata.encryptedSecret = encryptedAES
        
        //        return cipherText
    
        return ""
    }
    
    func decryptText(_ text: String, with serviceMetadata: Data?, wallet: String) throws -> String {
        guard let serviceMetadata,
              let pgpKey = getPGPKeyFor(wallet: wallet),
              let messageMetadata = (try? JSONDecoder().decode(PushEnvironment.MessageServiceMetadata.self, from: serviceMetadata)) else {
            throw EncryptionError.failedToGatherRequiredData
        }
        
        switch EncryptionType(rawValue: messageMetadata.encType) {
        case .none:
            return text
        case .pgp:
            return try Push.PushChat.decryptMessage(text,
                                                    encryptedSecret: messageMetadata.encryptedSecret,
                                                    privateKeyArmored: pgpKey)
        }
    }
    
    private func getPGPKeyFor(wallet: String) -> String? {
        if let cachedKey = pgpKeysCache[wallet] {
            return cachedKey
        }
        
        if let pgpKey = KeychainPGPKeysStorage.instance.getPGPKeyFor(identifier: wallet) {
            pgpKeysCache[wallet] = pgpKey
            return pgpKey
        }
        
        return nil
    }
     
    private enum EncryptionType: String {
        case pgp
    }
}

// MARK: - Open methods
extension PushMessagingContentDecrypterService {
    enum EncryptionError: Error {
        case failedToGatherRequiredData
    }
}
