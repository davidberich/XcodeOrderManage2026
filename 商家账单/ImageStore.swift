// ImageStore.swift

import SwiftUI
import Foundation
import Photos

class ImageStore {
    static let shared = ImageStore()
    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    private init() {
        // 获取沙盒文档目录
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // 获取图片在沙盒中的URL
    func urlForImage(with identifier: String) -> URL? {
        let imagePath = documentsDirectory.appendingPathComponent("\(identifier).jpg")
        return fileManager.fileExists(atPath: imagePath.path) ? imagePath : nil
    }

    // 从一个源URL复制图片到沙盒
    func copyImage(from sourceURL: URL, withName fileName: String) throws {
        let destinationURL = documentsDirectory.appendingPathComponent(fileName)
        
        // 确保目录存在
        try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    // --- 核心修复：保存图片时强制检查目录是否存在 ---
    func saveImage(_ image: UIImage, withIdentifier identifier: String? = nil) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("ImageStore: Could not get JPEG data from image.")
            return nil
        }
        
        let uniqueID = identifier ?? UUID().uuidString
        let imagePath = documentsDirectory.appendingPathComponent("\(uniqueID).jpg")
        
        do {
            // 1. 确保文件夹存在 (防止首次安装App时保存失败)
            if !fileManager.fileExists(atPath: documentsDirectory.path) {
                try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // 2. 写入文件
            try data.write(to: imagePath)
            return uniqueID
        } catch {
            print("ImageStore: Error saving image to sandbox: \(error.localizedDescription)")
            return nil
        }
    }

    func loadImage(withIdentifier identifier: String) -> UIImage? {
        let imagePath = documentsDirectory.appendingPathComponent("\(identifier).jpg")
        guard fileManager.fileExists(atPath: imagePath.path) else { return nil }
        return UIImage(contentsOfFile: imagePath.path)
    }

    func deleteImage(withIdentifier identifier: String) {
        let imagePath = documentsDirectory.appendingPathComponent("\(identifier).jpg")
        guard fileManager.fileExists(atPath: imagePath.path) else { return }
        do {
            try fileManager.removeItem(at: imagePath)
        } catch {
            print("ImageStore: Error deleting image from sandbox: \(error.localizedDescription)")
        }
    }

    func deleteImages(withIdentifiers identifiers: [String]) {
        for id in identifiers {
            deleteImage(withIdentifier: id)
        }
    }

    // 保存到用户相册（用于工厂单）
    func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                let error = NSError(
                    domain: "PhotoLibraryAccess", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "App does not have permission to access the photo library."]
                )
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
}
