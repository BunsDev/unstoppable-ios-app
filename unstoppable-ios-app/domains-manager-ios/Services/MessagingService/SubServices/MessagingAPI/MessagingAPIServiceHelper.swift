//
//  MessagingAPIServiceHelper.swift
//  domains-manager-ios
//
//  Created by Oleg Kuplin on 24.07.2023.
//

import Foundation

struct MessagingAPIServiceHelper {
    func getAnyDomainItem(for wallet: HexAddress) async throws -> DomainItem {
        let wallet = wallet.normalized
        guard let domain = await appContext.dataAggregatorService.getDomainItems().first(where: { $0.ownerWallet == wallet }) else {
            throw MessagingHelperError.noDomainForWallet
        }
        
        return domain
    }
    
    func decodeServiceMetadata<T: Codable>(from data: Data?) throws -> T {
        guard let data else {
            throw MessagingHelperError.failedToDecodeServiceData
        }
        guard let serviceMetadata = T.objectFromData(data) else {
            throw MessagingHelperError.failedToDecodeServiceData
        }
        
        return serviceMetadata
    }
    
    enum MessagingHelperError: String, LocalizedError {
        case noDomainForWallet
        case failedToDecodeServiceData
        
        public var errorDescription: String? { rawValue }
    }
}