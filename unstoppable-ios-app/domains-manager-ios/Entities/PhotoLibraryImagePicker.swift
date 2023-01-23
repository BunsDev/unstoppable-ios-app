//
//  ImagePicker.swift
//  domains-manager-ios
//
//  Created by Oleg Kuplin on 18.10.2022.
//

import UIKit
import Photos
import PhotosUI

typealias PhotoLibraryImagePickerCallback = (UIImage)->()

final class PhotoLibraryImagePicker: NSObject {
    
    static let shared = PhotoLibraryImagePicker()
    private var imagePickerCallback: PhotoLibraryImagePickerCallback?
    
    private override init() {
        super.init()
    }
    
    func pickImage(in viewController: UIViewController, imagePickerCallback: @escaping PhotoLibraryImagePickerCallback) {
        Task { @MainActor in
            let requiredFunctionality = PermissionsService.Functionality.photoLibrary(options: .addOnly)
            let isPermissionsGranted = await appContext.permissionsService.checkPermissionsFor(functionality: requiredFunctionality)
            
            if !isPermissionsGranted {
                guard await appContext.permissionsService.askPermissionsFor(functionality: requiredFunctionality,
                                                                            in: viewController,
                                                                            shouldShowAlertIfNotGranted: true) else { return }
            }
            
            self.imagePickerCallback = imagePickerCallback
            var pickerVC: UIViewController
            if #available(iOS 14.0, *) {
                var config = PHPickerConfiguration(photoLibrary: .shared())
                config.filter = .images
                config.selectionLimit = 1
                let imagePicker = PHPickerViewController(configuration: config)
                imagePicker.delegate = self
                pickerVC = imagePicker
            } else {
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.mediaTypes = ["public.image"]
                pickerVC = imagePicker
            }
            
            pickerVC.modalPresentationStyle = .fullScreen
            viewController.present(pickerVC, animated: true)
        }
    }
}

// MARK: - PHPickerViewControllerDelegate
extension PhotoLibraryImagePicker: PHPickerViewControllerDelegate {
    @available(iOS 14.0, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let result = results.first else {
            picker.dismiss(animated: true) // User cancelled selection
            return
        }
        
        result.itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { [weak self] (object, error) in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self?.didPick(image: image, from: picker)
                } else {
                    Debugger.printFailure("Failed to get image from PHImagePicker with error \(error)", critical: false)
                    self?.didFailToPickImage(from: picker)
                }
            }
        })
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension PhotoLibraryImagePicker: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.editedImage] as? UIImage {
            didPick(image: image, from: picker)
        } else if let image = info[.originalImage] as? UIImage {
            didPick(image: image, from: picker)
        } else {
            Debugger.printFailure("Failed to get image from UIImagePicker", critical: true)
            didFailToPickImage(from: picker)
        }
    }
}

// MARK: - Private methods
private extension PhotoLibraryImagePicker {
    func didPick(image: UIImage, from picker: UIViewController) {
        picker.presentingViewController?.dismiss(animated: true) { [weak self] in
            self?.imagePickerCallback?(image)
        }
    }
    
    func didFailToPickImage(from picker: UIViewController) {
        guard let presentingVC = picker.presentingViewController else {
            picker.dismiss(animated: true)
            Debugger.printFailure("Failed to get presenting view controller from image picker", critical: true)
            return
        }
        
        Task {
            await presentingVC.dismiss(animated: true)
            await appContext.pullUpViewService.showSelectedImageBadPullUp(in: presentingVC)
        }
    }
}
