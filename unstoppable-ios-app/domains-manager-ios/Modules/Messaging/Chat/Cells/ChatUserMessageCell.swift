//
//  ChatUserMessageCell.swift
//  domains-manager-ios
//
//  Created by Oleg Kuplin on 27.06.2023.
//

import UIKit

class ChatUserMessageCell: ChatBaseCell {
    
    @IBOutlet private weak var timeLabel: UILabel!
    @IBOutlet private weak var timeStackView: UIStackView!
    @IBOutlet private weak var deleteButton: FABRaisedTertiaryButton!
    
    private var timeLabelTapGesture: UITapGestureRecognizer?
    var actionCallback: ((ChatViewController.ChatMessageAction)->())?

    override func awakeFromNib() {
        super.awakeFromNib()
                
        let timeLabelTapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapTimeLabel))
        timeLabel.addGestureRecognizer(timeLabelTapGesture)
        self.timeLabelTapGesture = timeLabelTapGesture
        deleteButton.setTitle(nil, image: .trashIcon16)
        deleteButton.tintColor = .foregroundDefault
    }
    
    override func setWith(sender: MessagingChatSender) {
        super.setWith(sender: sender)
        
        if sender.isThisUser {
            timeStackView.alignment = .trailing
        } else {
            timeStackView.alignment = .leading
        }
    }
 
    func setWith(message: MessagingChatMessageDisplayInfo) {
        switch message.deliveryState {
        case .delivered:
            timeLabelTapGesture?.isEnabled = false
            deleteButton.isHidden = true
            let formatterTime = MessageDateFormatter.formatMessageDate(message.time)
            timeLabel.setAttributedTextWith(text: formatterTime,
                                            font: .currentFont(withSize: 11, weight: .regular),
                                            textColor: .foregroundSecondary)
        case .sending:
            timeLabelTapGesture?.isEnabled = false
            deleteButton.isHidden = true
            timeLabel.setAttributedTextWith(text: String.Constants.sending.localized() + "...",
                                            font: .currentFont(withSize: 11, weight: .regular),
                                            textColor: .foregroundSecondary)
        case .failedToSend:
            timeLabelTapGesture?.isEnabled = true
            deleteButton.isHidden = false
            let fullText = String.Constants.sendingFailed.localized() + ". " + String.Constants.tapToRetry.localized()
            timeLabel.setAttributedTextWith(text: fullText,
                                            font: .currentFont(withSize: 11, weight: .semibold),
                                            textColor: .foregroundDanger)
            timeLabel.updateAttributesOf(text: String.Constants.tapToRetry.localized(),
                                         textColor: .foregroundAccent)
        }
        timeLabel.isUserInteractionEnabled = timeLabelTapGesture?.isEnabled == true
        setWith(sender: message.senderType)
    }
    
}

// MARK: - Private methods
private extension ChatUserMessageCell {
    @objc func didTapTimeLabel() {
        UDVibration.buttonTap.vibrate()
        actionCallback?(.resend)
    }
    
    @IBAction func deleteButtonPressed(_ sender: Any) {
        actionCallback?(.delete)
    }
}
