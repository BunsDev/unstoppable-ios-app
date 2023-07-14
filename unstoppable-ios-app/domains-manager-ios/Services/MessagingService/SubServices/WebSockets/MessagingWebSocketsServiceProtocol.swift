//
//  MessagingWebSocketsServiceProtocol.swift
//  domains-manager-ios
//
//  Created by Oleg Kuplin on 30.05.2023.
//

import Foundation

protocol MessagingWebSocketsServiceProtocol {
    func subscribeFor(profile: MessagingChatUserProfile,
                      eventCallback: @escaping MessagingWebSocketEventCallback) throws
    func disconnectAll()
}

struct MessagingWebSocketMessageEntity {
    let id: String
    let senderWallet: String
    let receiverWallet: String
    let serviceContent: Any
    
    var transformToMessageBlock: ((_ webSocketMessage: MessagingWebSocketMessageEntity,
                                   _ chat: MessagingChat,
                                   _ filesService: MessagingFilesServiceProtocol)->(MessagingChatMessage?))
}

struct MessagingWebSocketGroupMessageEntity {
    let chatId: String 
    let serviceContent: Any
    var transformToMessageBlock: ((_ webSocketMessage: MessagingWebSocketGroupMessageEntity,
                                   _ chat: MessagingChat,
                                   _ filesService: MessagingFilesServiceProtocol)->(MessagingChatMessage?))
}