// PhotoSaver.swift
import UIKit

// <<< 核心修改：将 PhotoSaver 改为单例模式
class PhotoSaver: NSObject {
    // 1. 创建一个静态的共享实例
    static let shared = PhotoSaver()
    
    // 2. 将回调闭包作为属性，以便可以从外部设置
    var onSuccess: (() -> Void)?
    var onError: ((Error?) -> Void)?
    
    // 3. 将 init 设为私有，防止外部创建新的实例
    private override init() {
        super.init()
    }

    func save(image: UIImage, onSuccess: @escaping () -> Void, onError: @escaping (Error?) -> Void) {
        // 4. 在调用时直接设置回调，而不是依赖预设的属性
        self.onSuccess = onSuccess
        self.onError = onError
        
        // 5. 调用系统函数，并将 self（这个单例对象）作为回调目标
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc private func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            onError?(error)
        } else {
            onSuccess?()
        }
    }
}
