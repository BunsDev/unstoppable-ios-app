//
//  ChatImageCell.swift
//  domains-manager-ios
//
//  Created by Oleg Kuplin on 19.06.2023.
//

import UIKit

final class ChatImageCell: ChatUserMessageCell {

    @IBOutlet private weak var imageView: UIImageView!
    
    private var imageViewConstraints: [NSLayoutConstraint] = []
    private let maxSize: CGFloat = (294/390) * UIScreen.main.bounds.width
    private var timeLabelTapGesture: UITapGestureRecognizer?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.contentMode = .scaleAspectFill
        setImageSize(.square(size: maxSize))
    }

}

// MARK: - Open methods
extension ChatImageCell {
    func setWith(configuration: ChatViewController.ImageBase64MessageUIConfiguration) {
        self.actionCallback = configuration.actionCallback
        setWith(message: configuration.message)
        setImage(configuration.imageMessageDisplayInfo.image ?? .domainSharePlaceholder)
    }
}

// MARK: - Private methods
private extension ChatImageCell {
    func setImage(_ image: UIImage) {
        imageView.image = image
        let imageSize = image.size
        let imageViewSize: CGSize
        
        if imageSize.width > imageSize.height {
            let height = maxSize * (imageSize.height / imageSize.width)
            imageViewSize = CGSize(width: maxSize,
                                   height: height)
        } else if imageSize.height > 0 {
            let width = maxSize * (imageSize.width / imageSize.height)
            imageViewSize = CGSize(width: width,
                                   height: maxSize)
        } else {
            imageViewSize = .square(size: maxSize)
        }
        
        setImageSize(imageViewSize)
    }
    
    func setImageSize(_ size: CGSize) {
        imageView.removeConstraints(imageViewConstraints)
        let widthConstraint = imageView.widthAnchor.constraint(equalToConstant: size.width)
        let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: size.height)
        heightConstraint.priority = .init(999)
        imageViewConstraints = [widthConstraint, heightConstraint]
        NSLayoutConstraint.activate(imageViewConstraints)
    }
}