//
//  UDWallet+Signing.swift
//  domains-manager-ios
//
//  Created by Roman Medvid on 29.11.2022.
//

import Foundation
import CryptoSwift
import Boilertalk_Web3
import web3swift
import WalletConnectSwift


// Signing methods
extension UDWallet {
    var shouldParseMessage: Bool {
        guard let walletName = self.getExternalWalletName()?.lowercased() else {
            return false
        }
        return walletName.contains("alpha")
    }
    
    static func createSignaturesByPersonalSign(messages: [String],
                                               domain: DomainItem) async throws -> [String] {
        guard let walletAddress = domain.ownerWallet else {
            throw UDWallet.Error.noWalletOwner
        }
        guard let wallet = UDWalletsStorage.instance.getWallet(by: walletAddress, namingService: .UNS) else {
            throw UDWallet.Error.failedToFindWallet
        }
        let signatures =  try await wallet.multipleWalletPersonalSigns(messages: messages)
        return signatures
    }
    
    func getPersonalSignature(messageString: String, shouldTryToConverToReadable: Bool = true) async throws -> String {
        guard self.walletState == .verified else {
            if self.shouldParseMessage {
                let message = messageString.convertedIntoReadableMessage
                return try await signViaWalletConnectPersonalSign(message: message)
            }
            return try await signViaWalletConnectPersonalSign(message: messageString)
        }
        
        let messageToSend = shouldTryToConverToReadable ? messageString.convertedIntoReadableMessage : messageString
        
        guard let signature = self.signPersonal(messageString: messageToSend) else {
            throw UDWallet.Error.failedToSignMessage
        }
        return signature
    }
    
    func getEthSignature(messageString: String) async throws -> String {
        guard self.walletState == .verified else {
            return try await signViaWalletConnectEthSign(message: prepareMessageForEthSign(message: messageString))
        }
        
        guard let signature = self.signPersonalSignWithHexConversion(messageString: messageString) else {
            throw UDWallet.Error.failedToSignMessage
        }
        return signature
    }
    
    
    func signPersonalSignWithHexConversion(messageString: String) -> String? {
        guard messageString.droppedHexPrefix.isHexNumber else {
            return nil
        }
        return signPersonalAsHexString(messageString: messageString)
    }
    
    private func signPersonalAsHexString(messageString: String) -> String? {
        let data = Data(messageString.droppedHexPrefix.hexToBytes())
        guard let signature = try? self.signPersonalMessage(data) else {
            return nil
        }
        return HexAddress.hexPrefix + signature.dataToHexString()
    }
    
    static func hashed(messageString: String) -> String? {
        let messageBytes = messageString.droppedHexPrefix.hexToBytes()
        guard let hash = Web3.Utils.hashPersonalMessage(Data(messageBytes)) else { return nil }
        return HexAddress.hexPrefix + hash.dataToHexString()
    }
    
    func prepareMessageForEthSign(message: String) throws -> String {
        func willHash() -> Bool {
            guard let walletName = self.getExternalWalletName()?.lowercased() else {
                return false
            }
            return walletName.contains("rainbow") || walletName.contains("alpha") || walletName.contains("ledger")
        }
        
        let messageToSend: String
        if willHash() {
            messageToSend = message
        } else {
            guard let hash = Self.hashed(messageString: message) else {  throw WalletConnectRequestError.failedHashPersonalMessage }
            messageToSend = hash
        }
        return messageToSend
    }
    
    func getSignTypedData(dataString: String) async throws -> String {
        guard self.walletState == .verified else {
            let signature = try await signViaWalletConnectTypedData(dataString: dataString)
            return signature
        }        
        let data = dataString.data(using: .utf8)!
        let typedData = try! JSONDecoder().decode(EIP712TypedData.self, from: data)
        let signHash = typedData.signHash
        
        let privKey = self.getPrivateKey()! // safe
        guard let sig = try UDWallet.signMessageHash(messageHash: signHash, with: privKey) else {
            throw UDWallet.Error.failedToSignMessage
        }

        return "0x" + sig.dataToHexString()
    }
    
    func signViaWalletConnectTypedData(dataString: String) async throws -> String {
        let session = try detectWCSessionType()
        switch session {
        case .wc1(let wc1Session):
            let response = try await appContext.walletConnectExternalWalletHandler.signTypedDataViaWalletConnect_V1(session: wc1Session, walletAddress: self.address, message: dataString, in: self)
            return try handleResponse(response: response)
        case .wc2(let wc2Sessions):
            let response = try await appContext.walletConnectServiceV2.sendSignTypedData(sessions: wc2Sessions,
                                                                                        chainId: 1, // chain here makes no difference
                                                                                        dataString: dataString,
                                                                                        address: address,
                                                                                        in: self)
            return try appContext.walletConnectServiceV2.handle(response: response)
        }
    }
    
    func signViaWalletConnectPersonalSign(message: String) async throws -> String {
        let session = try detectWCSessionType()
        switch session {
        case .wc1(let wc1Session):
            let messageToSend: String
            if message.droppedHexPrefix.isHexNumber {
                let data = message.droppedHexPrefix.hexToBytes()
                messageToSend = String (bytes: data, encoding: .default)!
            } else {
                messageToSend = message
            }
            let response = try await appContext.walletConnectExternalWalletHandler.signPersonalSignViaWalletConnect_V1(session: wc1Session, message: messageToSend, in: self)
            return try handleResponse(response: response)
        case .wc2(let wc2Sessions):
            let response = try await appContext.walletConnectServiceV2.sendPersonalSign(sessions: wc2Sessions,
                                                                                        chainId: 1, // chain here makes no difference
                                                                                        message: message,
                                                                                        address: address,
                                                                                        in: self)
            return try appContext.walletConnectServiceV2.handle(response: response)
        }
    }
    
    enum WCSession {
        case wc1(Session)
        case wc2([WCConnectedAppsStorageV2.SessionProxy])
    }
    
    func detectWCSessionType() throws -> WCSession {
        let walletSessions = appContext.walletConnectServiceV2.findSessions(by: self.address)
        if  walletSessions.count > 0 { return .wc2(walletSessions) }
        guard let session = appContext.walletConnectClientService.findSessions(by: self.address).first else {
            Debugger.printFailure("Failed to find session for WC", critical: false)
            throw WalletConnectRequestError.noWCSessionFound
        }
        return .wc1(session)
    }
    
    func signViaWalletConnectEthSign(message: String) async throws -> String {
        let sessions = appContext.walletConnectServiceV2.findSessions(by: self.address)
        if  sessions.count > 0 {
            let response = try await appContext.walletConnectServiceV2.sendEthSign(sessions: sessions,
                                                                                   chainId: 1, // chain here makes no difference
                                                                                   message: message,
                                                                                   address: address,
                                                                                   in: self)
            return try appContext.walletConnectServiceV2.handle(response: response)
        }
        
        guard let session = appContext.walletConnectClientService.findSessions(by: self.address).first else {
            Debugger.printFailure("Failed to find session for WC", critical: false)
            throw WalletConnectRequestError.noWCSessionFound
        }
        
        let response = try await appContext.walletConnectExternalWalletHandler.signConnectEthSignViaWalletConnect_V1(session: session, message: message, in: self)

        return try handleResponse(response: response)
    }
    
    private func handleResponse(response: Response) throws -> String {
        let result = try response.result(as: String.self)
        return result
    }
    
    func multipleWalletPersonalSigns(messages: [String]) async throws -> [String]{
        var sigs = [String]()
        
        switch self.walletState {
        case .externalLinked:
            // Because it will be required to sign message in external wallet for each request, they can't be fired simultaneously
            for message in messages {
                let result = try await self.getPersonalSignature(messageString: message)
                sigs.append(result)
            }
        case .verified:
            await withTaskGroup(of: Optional<String>.self) { group in
                for message in messages {
                    group.addTask {
                        try? await self.getPersonalSignature(messageString: message)
                    }
                }
                
                for await result in group {
                    guard let sig = result else { continue }
                    sigs.append(sig)
                }
            }
        }
        guard messages.count == sigs.count else { throw UDWallet.Error.failedSignature }
        return sigs
    }
}

//core methods

extension UDWallet {
    
    func signPersonal(messageString: String) -> String? {
        if messageString.hasHexPrefix {
            return signPersonalAsHexString(messageString: messageString)
        }
        
        guard let data = messageString.data(using: .utf8),
              let signature = try? self.signPersonalMessage(data) else {
            return nil
        }
        return HexAddress.hexPrefix + signature.dataToHexString()
    }
    
    private func signPersonalMessage(_ personalMessageData: Data) throws -> Data? {
        guard let privateKeyString = self.getPrivateKey() else { return nil }
        return try UDWallet.signPersonalMessage(personalMessageData, with: privateKeyString)
    }
    
    
    
    static public func signPersonalMessage(_ personalMessageData: Data,
                                       with privateKeyString: String) throws -> Data? {
        guard let hash = Web3.Utils.hashPersonalMessage(personalMessageData) else { return nil }
        return try signMessageHash(messageHash: hash, with: privateKeyString)
    }
    
    static public func signMessageHash(messageHash: Data,
                                       with privateKeyString: String) throws -> Data? {
        var privateKey = Data(privateKeyString.droppedHexPrefix.hexToBytes())
        defer { Data.zero(&privateKey) }
        return try signMessageHash(messageHash: messageHash, with: privateKey)
    }
    
    static public func signMessageHash(messageHash: Data,
                                       with privateKeyData: Data) throws -> Data? {
        let (compressedSignature, _) = SECP256K1.signForRecovery(hash: messageHash, privateKey: privateKeyData, useExtraEntropy: false)
        return compressedSignature
    }
}
