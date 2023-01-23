//
//  LegalSelectionView.swift
//  domains-manager-ios
//
//  Created by Oleg Kuplin on 03.05.2022.
//

import UIKit
import SwiftUI

enum PullUpSelectionViewEmptyItem: CaseIterable, PullUpCollectionViewCellItem {
    var title: String { "" }
    var icon: UIImage { .init() }
    var analyticsName: String { "" }
}

final class PullUpSelectionView<Item: PullUpCollectionViewCellItem>: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    
    typealias ItemCallback = ((Item)->())
    
    private var collectionView: UICollectionView?
    private var titleLabel: UILabel!
    private var currentMinYAnchor: NSLayoutYAxisAnchor!
    
    private var configuration: PullUpSelectionViewConfiguration!
    var items = [Item]()
    var itemSelectedCallback: ItemCallback?
    
    init(configuration: PullUpSelectionViewConfiguration, items: [Item], itemSelectedCallback: ItemCallback? = nil) {
        super.init(frame: .zero)
        
        self.configuration = configuration
        self.items = items
        self.itemSelectedCallback = itemSelectedCallback
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setup()
    }
    
    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCellOfType(PullUpCollectionViewCell.self, forIndexPath: indexPath)
        
        let legalType = items[indexPath.row]
        cell.setWith(pullUpItem: legalType)
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        UDVibration.buttonTap.vibrate()
        let item = items[indexPath.row]
        logButtonPressed(item.analyticsName)
        itemSelectedCallback?(item)
    }
    
    @objc private func cancelButtonPressed() {
        pullUpView?.cancel()
    }
    
    @objc private func didTapButton(_ button: UIButton) {
        let tag = button.tag
        logButtonPressed(configuration.buttonContentInButtonWith(tag: tag)?.analyticsName.rawValue ?? "unspecified")
        configuration.callActionInButtonWith(tag: tag)
    }
    
    @objc private func didTapLabel() {
        switch configuration.title {
        case .highlightedText(let textDescription):
            logButtonPressed(textDescription.analyticsActionName?.rawValue ?? "unspecified")
            textDescription.action?()
            return
        case .none, .text:
            Void()
        }
        
        switch configuration.subtitle {
        case .label(let label):
            switch label {
            case .highlightedText(let textDescription):
                logButtonPressed(textDescription.analyticsActionName?.rawValue ?? "unspecified")
                textDescription.action?()
            case .text:
                return
            }
            return
        case .none, .button:
            return
        }
    }
    
    private func logButtonPressed(_ buttonName: String) {
        let pullUp = (self.findViewController() as? PullUpViewController)?.pullUp ?? .unspecified
        
        appContext.analyticsService.log(event: .buttonPressed, withParameters: [.pullUpName : pullUp.rawValue,
                                                                            .button : buttonName])
    }
}

// MARK: - Open methods
extension PullUpSelectionView {
    var pullUpView: PullUpView? {
        var view: UIView? = superview
        while view != nil {
            if view is PullUpView {
                break
            }
            view = view?.superview
        }
        return view as? PullUpView
    }
}

// MARK: - Setup methods
private extension PullUpSelectionView {
    func setup() {
        backgroundColor = .clear
        setupCustomHeader()
        setupIcon()
        setupTitleLabel()
        setupSubtitle()
        setupExtraViews()
        setupCollectionView()
        setupActionButton()
        setupCancelButton()
    }
    
    func setupCustomHeader() {
        guard let customHeader = configuration.customHeader else { return }
        
        customHeader.translatesAutoresizingMaskIntoConstraints = false
        addSubview(customHeader)
        customHeader.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        customHeader.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
        currentMinYAnchor = customHeader.bottomAnchor
    }
    
    func setupIcon() {
        guard let iconContent = configuration.icon else { return }
        
        let iconView = buildIconView(iconContent)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        iconView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        iconView.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
        currentMinYAnchor = iconView.bottomAnchor
    }
    
    func setupTitleLabel() {
        guard let configurationTitle = configuration.title else { return }

        titleLabel = UILabel(frame: CGRect(x: 16, y: 0, width: 200, height: 28))
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let title: String
        var highlightedTextDescription: PullUpSelectionViewConfiguration.HighlightedText?
        
        switch configurationTitle {
        case .text(let text):
            title = text
        case .highlightedText(let textDescription):
            title = textDescription.text
            highlightedTextDescription = textDescription
        }
        
        titleLabel.setAttributedTextWith(text: title,
                                         font: .currentFont(withSize: 22, weight: .bold),
                                         textColor: .foregroundDefault,
                                         alignment: configuration.contentAlignment.textAlignment,
                                         lineHeight: 28)
        
        if let textDescription = highlightedTextDescription {
            textDescription.highlightedText.forEach { textDescription in
                titleLabel.updateAttributesOf(text: textDescription.highlightedText,
                                              withFont: .currentFont(withSize: titleLabel.font.pointSize, weight: .medium),
                                              textColor: textDescription.highlightedColor)
            }
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapLabel))
        titleLabel.addGestureRecognizer(tap)
        
        addSubview(titleLabel)
        titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
        titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        if let currentMinYAnchor = currentMinYAnchor {
            titleLabel.topAnchor.constraint(equalTo: currentMinYAnchor, constant: 16).isActive = true
        } else {
            titleLabel.topAnchor.constraint(equalTo: topAnchor).isActive = true
        }
        currentMinYAnchor = titleLabel.bottomAnchor
    }
    
    func setupSubtitle() {
        guard let subtitle = configuration.subtitle else { return }
        
        let subtitleView = buildSubtitleView(subtitle)
        addSubview(subtitleView)
        alignToTitleView(subtitleView, andUpdateCurrentMin: 8)
    }
    
    func setupExtraViews() {
        guard let extraViews = configuration.extraViews else { return }
        
        extraViews.forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            alignToTitleView(view, andUpdateCurrentMin: 24)
        }
    }
    
    func setupCollectionView() {
        guard !items.isEmpty else { return }
        
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 52, width: bounds.width, height: 170),
                                          collectionViewLayout: buildLayout())
        collectionView.accessibilityIdentifier = "Pull Up Collection View"
        self.collectionView = collectionView
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isScrollEnabled = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.registerCellNibOfType(PullUpCollectionViewCell.self)
        
        collectionView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        collectionView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        let height = items.reduce(0, { $0 + $1.height })
        collectionView.heightAnchor.constraint(equalToConstant: height).isActive = true
        
        if let currentMinYAnchor = currentMinYAnchor {
            collectionView.topAnchor.constraint(equalTo: currentMinYAnchor, constant: 24).isActive = true
        } else {
            collectionView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        }
        currentMinYAnchor = collectionView.bottomAnchor
    }
    
    func buildLayout() -> UICollectionViewLayout {
        let spacing: CGFloat = UICollectionView.SideOffset
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = spacing
        
        let layout = UICollectionViewCompositionalLayout(sectionProvider: {
            (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            
            let section = NSCollectionLayoutSection.flexibleListItemSection()
            section.contentInsets = NSDirectionalEdgeInsets(top: 1,
                                                            leading: spacing + 1,
                                                            bottom: 1,
                                                            trailing: spacing + 1)
            
            section.decorationItems = [
                NSCollectionLayoutDecorationItem.background(elementKind: CollectionReusableRoundedBackground.reuseIdentifier)
            ]
            
            return section
            
        }, configuration: config)
        layout.register(CollectionReusableRoundedBackground.self, forDecorationViewOfKind: CollectionReusableRoundedBackground.reuseIdentifier)
        
        return layout
    }
    
    func setupActionButton() {
        guard let actionButton = self.configuration.actionButton else { return }
        
        let button = buildButtonView(actionButton)
        button.accessibilityIdentifier = "Pull Up Confirm Button"
        addSubview(button)
        alignToTitleView(button, andUpdateCurrentMin: 24)
    }
    
    func setupCancelButton() {
        guard let cancelButton = self.configuration.cancelButton else { return }
        
        let button = buildButtonView(cancelButton)
        button.accessibilityIdentifier = "Pull Up Cancel Button"
        button.addTarget(self, action: #selector(cancelButtonPressed), for: .touchUpInside)
        addSubview(button)
        let space: CGFloat = self.configuration.actionButton == nil ? 24 : 16
        alignToTitleView(button, andUpdateCurrentMin: space)
    }
}

// MARK: - UI elements builder
private extension PullUpSelectionView {
    func alignToTitleView(_ view: UIView, andUpdateCurrentMin distanceToTop: CGFloat) {
        view.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor).isActive = true
        view.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        view.topAnchor.constraint(equalTo: currentMinYAnchor, constant: distanceToTop).isActive = true
        currentMinYAnchor = view.bottomAnchor
    }
    
    func buildSubtitleView(_ subtitle: PullUpSelectionViewConfiguration.Subtitle) -> UIView {
        switch subtitle {
        case .label(let labelType):
            switch labelType {
            case .text(let text):
                return buildSubtitleLabel(with: text)
            case .highlightedText(let textDescription):
                let label = buildSubtitleLabel(with: textDescription.text)
                textDescription.highlightedText.forEach { highlightedTextDescription in
                    label.updateAttributesOf(text: highlightedTextDescription.highlightedText,
                                             withFont: .currentFont(withSize: label.font.pointSize, weight: .medium),
                                             textColor: highlightedTextDescription.highlightedColor,
                                             lineHeight: 25)
                }
                label.isUserInteractionEnabled = true
                let tap = UITapGestureRecognizer(target: self, action: #selector(didTapLabel))
                label.addGestureRecognizer(tap)
                return label
            }
        case .button(let button):
            return buildButtonView(button)
        }
    }
    
    func buildSubtitleLabel(with text: String) -> UILabel {
        let subtitleLabel = UILabel()
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.setAttributedTextWith(text: text,
                                            font: .currentFont(withSize: 16, weight: .regular),
                                            textColor: .foregroundSecondary,
                                            alignment: configuration.contentAlignment.textAlignment,
                                            lineHeight: 24)
        
        return subtitleLabel
    }
    
    func buildButtonView(_ buttonType: PullUpSelectionViewConfiguration.ButtonType) -> UIButton {
        let button: BaseButton
        let buttonContent: PullUpSelectionViewConfiguration.ButtonContent
        
        switch buttonType {
        case .main(let content):
            let mainButton = MainButton()
            mainButton.isSuccess = content.isSuccessState
            button = mainButton
            buttonContent = content
        case .secondary(let content):
            button = SecondaryButton()
            buttonContent = content
        case .textTertiary(let content):
            let ttButton = TextTertiaryButton()
            ttButton.isSuccess = content.isSuccessState
            button = ttButton
            buttonContent = content
        case .primaryDanger(let content):
            button = PrimaryDangerButton()
            buttonContent = content
        case .secondaryDanger(let content):
            button = SecondaryDangerButton()
            buttonContent = content
        case .applePay(let content):
            button = ApplePayButton()
            buttonContent = content
        }
        
        button.isUserInteractionEnabled = buttonContent.isUserInteractionEnabled
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: buttonType.height).isActive = true
        button.imageLayout = buttonContent.imageLayout
        button.setTitle(buttonContent.title,
                        image: buttonContent.icon)
        if #available(iOS 14.0, *) {
            button.addAction(.init(handler: { [weak self] _ in
                self?.logButtonPressed(buttonContent.analyticsName.rawValue)
                buttonContent.action?()
            }), for: .touchUpInside)
        } else {
            button.tag = configuration.tagForButtonType(buttonType)
            button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        }
        
        if buttonContent.isLoading {
            button.showLoadingIndicator()
        }
        
        return button
    }
    
    func buildIconView(_ iconContent: PullUpSelectionViewConfiguration.IconContent) -> UIView {
        let imageView = UIImageView(image: iconContent.icon)
        imageView.tintColor = iconContent.tintColor
        imageView.contentMode = .scaleAspectFit
        
        let resultView: UIView
        switch iconContent.size {
        case .largeCentered:
            imageView.translatesAutoresizingMaskIntoConstraints = false
            let wrapView = UIView()
            wrapView.backgroundColor = .clear
            wrapView.addSubview(imageView)
            
            imageView.heightAnchor.constraint(equalToConstant: iconContent.size.size / 2).isActive = true
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 1).isActive = true
            
            imageView.centerXAnchor.constraint(equalTo: wrapView.centerXAnchor).isActive = true
            imageView.centerYAnchor.constraint(equalTo: wrapView.centerYAnchor).isActive = true
            wrapView.heightAnchor.constraint(equalToConstant: iconContent.size.size).isActive = true
            wrapView.widthAnchor.constraint(equalTo: wrapView.heightAnchor, multiplier: 1).isActive = true
            
            resultView = wrapView
        case .small, .large:
            imageView.heightAnchor.constraint(equalToConstant: iconContent.size.size).isActive = true
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 1).isActive = true
            resultView = imageView
        }
        
        resultView.backgroundColor = iconContent.backgroundColor
        resultView.clipsToBounds = true

        switch iconContent.corners {
        case .circle:
            resultView.layer.cornerRadius = iconContent.size.size / 2
        case .custom(let value):
            resultView.layer.cornerRadius = value
        case .none:
            Void()
        }
        
        return resultView
    }
}

struct PullUpSelectionViewConfiguration {
    var customHeader: UIView? = nil
    var title: LabelType?
    var contentAlignment: ContentAlignment
    var icon: IconContent? = nil
    var subtitle: Subtitle? = nil
    var extraViews: [UIView]? = nil
    var actionButton: ButtonType? = nil
    var cancelButton: ButtonType? = nil
    
    /// Remove tagForButtonType, and callActionInButtonWith, (callAction in ButtonType) when iOS 13 will be dropped.
    func tagForButtonType(_ buttonType: ButtonType) -> Int {
        if buttonType == actionButton {
            return 0
        } else if buttonType == cancelButton {
            return 1
        } else {
            return 2
        }
    }
    
    func buttonContentInButtonWith(tag: Int) -> ButtonContent? {
        if tag == 0 {
            return actionButton?.content
        } else if tag == 1 {
            return cancelButton?.content
        } else if case .button(let buttonType) = subtitle {
            return buttonType.content
        }
        return nil
    }
    
    func callActionInButtonWith(tag: Int) {
        if tag == 0 {
            actionButton?.callAction()
        } else if tag == 1 {
            cancelButton?.callAction()
        } else if case .button(let buttonType) = subtitle {
            buttonType.callAction()
        }
    }
    
    // Title
    enum LabelType {
        case text(_ text: String)
        case highlightedText(_ highlightedText: HighlightedText)
    }
    
    struct HighlightedText {
        let text: String
        let highlightedText: [HighlightedTextDescription]
        let analyticsActionName: Analytics.Button?
        let action: EmptyCallback?
    }
    
    struct HighlightedTextDescription {
        let highlightedText: String
        let highlightedColor: UIColor
    }
    
    // Content
    enum ContentAlignment {
        case left, center
        
        var textAlignment: NSTextAlignment {
            switch self {
            case .left:
                return .left
            case .center:
                return .center
            }
        }
    }
    
    // Subtitle
    enum Subtitle {
        case label(_ label: LabelType)
        case button(_ button: ButtonType)
    }
    
    // Icon
    enum IconSize {
        case largeCentered, large, small
        
        var size: CGFloat {
            switch self {
            case .largeCentered, .large:
                return 56
            case .small:
                return 40
            }
        }
    }
    
    enum IconCorners {
        case none, circle, custom(_ value: CGFloat)
    }
    
    struct IconContent {
        let icon: UIImage
        let size: IconSize
        var corners: IconCorners = .none
        var backgroundColor: UIColor = .clear
        var tintColor: UIColor = .foregroundMuted
    }
    
    // Button
    struct ButtonContent: Equatable {
        let title: String
        let icon: UIImage?
        var imageLayout: ButtonImageLayout = .leading
        var analyticsName: Analytics.Button
        var isSuccessState: Bool = false
        var isLoading: Bool = false
        var isUserInteractionEnabled: Bool = true
        let action: EmptyCallback?
        
        static func == (lhs: PullUpSelectionViewConfiguration.ButtonContent, rhs: PullUpSelectionViewConfiguration.ButtonContent) -> Bool {
            lhs.title == rhs.title
        }
        
    }
    
    enum ButtonType: Equatable {
        static let cancelButton: ButtonType = .secondary(content: .init(title: String.Constants.cancel.localized(),
                                                                        icon: nil,
                                                                        analyticsName: .cancel,
                                                                        action: nil))
        static let laterButton: ButtonType = .secondary(content: .init(title: String.Constants.later.localized(),
                                                                        icon: nil,
                                                                        analyticsName: .later,
                                                                        action: nil))
        static func gotItButton(action: EmptyCallback? = nil) -> ButtonType {
            .secondary(content: .init(title: String.Constants.gotIt.localized(),
                                      icon: nil,
                                      analyticsName: .gotIt,
                                      action: action))
        }

        case main(content: ButtonContent)
        case primaryDanger(content: ButtonContent)
        case secondary(content: ButtonContent)
        case secondaryDanger(content: ButtonContent)
        case textTertiary(content: ButtonContent)
        case applePay(content: ButtonContent)
        
        var height: CGFloat {
            switch self {
            case .main, .secondary, .primaryDanger, .secondaryDanger, .applePay:
                return 48
            case .textTertiary:
                return 24
            }
        }
        
        func callAction() {
            switch self {
            case .main(let content), .secondary(let content), .textTertiary(let content), .primaryDanger(let content), .secondaryDanger(let content), .applePay(let content):
                content.action?()
            }
        }
        
        var content: ButtonContent {
            switch self {
            case .main(let content), .secondary(let content), .textTertiary(let content), .primaryDanger(let content), .secondaryDanger(let content), .applePay(let content):
                return content
            }
        }
    }
}


