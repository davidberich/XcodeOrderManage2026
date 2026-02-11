import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

struct BackupAndRestoreView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // 使用独立的 Bool 状态变量
    @State private var isShowingExporter = false
    @State private var isShowingImporter = false
    @State private var showResultAlert = false
    
    @State private var backupFileURL: URL?
    
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            Form {
                // UI 布局保持不变
                Section(
                    header: Text("数据备份 (含图片)"),
                    footer: Text("将所有订单数据和相关图片打包成一个 .zip 文件。请将此文件妥善保管，用于恢复或迁移数据。")
                ) {
                    Button(action: createBackup) {
                        HStack {
                            Label("创建并导出完整备份", systemImage: "archivebox.circle.fill")
                            if isProcessing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.orders.isEmpty || isProcessing)
                }
                
                Section(
                    header: Text("数据恢复"),
                    footer: Text("从一个 .zip 备份文件中恢复订单和图片。App会自动跳过已存在的重复订单。")
                ) {
                    Button(action: { isShowingImporter = true }) {
                        Label("从备份文件导入", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isProcessing)
                }
            }
            .navigationTitle("备份与恢复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isShowingExporter, onDismiss: {
                if let url = backupFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
            }) {
                if let url = backupFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [UTType.zip]) { result in
                handleImport(result: result)
            }
            .alert(alertTitle, isPresented: $showResultAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func createBackup() {
        isProcessing = true
        Task(priority: .userInitiated) {
            do {
                let url = try await packageBackupInBackground()
                await MainActor.run {
                    self.backupFileURL = url
                    self.isProcessing = false
                    self.isShowingExporter = true
                }
            } catch {
                await MainActor.run {
                    self.alertTitle = "备份失败"
                    self.alertMessage = error.localizedDescription
                    self.isProcessing = false
                    self.showResultAlert = true
                }
            }
        }
    }
    
    // ✅ 修复：将 handleImport 函数的实现修正为使用正确的状态变量
    private func handleImport(result: Result<URL, Error>) {
        isProcessing = true
        guard case .success(let zipURL) = result else {
            if case .failure(let error) = result {
                self.alertTitle = "导入失败"
                self.alertMessage = "无法选择文件: \(error.localizedDescription)"
                self.showResultAlert = true
            }
            isProcessing = false
            return
        }
        
        guard zipURL.startAccessingSecurityScopedResource() else {
            self.alertTitle = "导入失败"
            self.alertMessage = "无法访问所选文件，请检查文件权限。"
            self.showResultAlert = true
            isProcessing = false
            return
        }
        
        Task(priority: .userInitiated) {
            let fileManager = FileManager.default
            let extractionDirectory = fileManager.temporaryDirectory.appendingPathComponent("OrderBackup-\(UUID().uuidString)")
            
            var finalAlertTitle: String
            var finalAlertMessage: String
            
            do {
                try fileManager.createDirectory(at: extractionDirectory, withIntermediateDirectories: true, attributes: nil)
                try fileManager.unzipItem(at: zipURL, to: extractionDirectory)
                
                guard let jsonURL = findFile(named: "app_orders.json", in: extractionDirectory) else {
                    throw NSError(domain: "ImportError", code: 404, userInfo: [NSLocalizedDescriptionKey: "在备份文件中找不到订单数据(app_orders.json)。"])
                }

                let data = try Data(contentsOf: jsonURL)
                let decoder = JSONDecoder()
                var importedOrders = try decoder.decode([Order].self, from: data)
                
                for i in 0..<importedOrders.count {
                    if importedOrders[i].status == nil { importedOrders[i].status = .active }
                }
                
                let imagesSourceDir = jsonURL.deletingLastPathComponent().appendingPathComponent("Images")
                if fileManager.fileExists(atPath: imagesSourceDir.path) {
                    let imageFiles = try fileManager.contentsOfDirectory(at: imagesSourceDir, includingPropertiesForKeys: nil)
                    for imageURL in imageFiles {
                        try ImageStore.shared.copyImage(from: imageURL, withName: imageURL.lastPathComponent)
                    }
                }
                
                let mergeResult = await MainActor.run {
                    viewModel.mergeImportedOrders(importedOrders)
                }
                finalAlertTitle = "恢复完成"
                finalAlertMessage = "成功导入 \(mergeResult.importedCount) 条新订单。\n跳过 \(mergeResult.skippedCount) 条重复订单。"
                
            } catch {
                finalAlertTitle = "导入失败"
                finalAlertMessage = error.localizedDescription
            }
            
            zipURL.stopAccessingSecurityScopedResource()
            try? fileManager.removeItem(at: extractionDirectory)
            
            await MainActor.run {
                self.alertTitle = finalAlertTitle
                self.alertMessage = finalAlertMessage
                self.showResultAlert = true
                self.isProcessing = false
            }
        }
    }

    private func findFile(named fileName: String, in directory: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.nameKey], options: [.skipsHiddenFiles])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent == fileName {
                return fileURL
            }
        }
        return nil
    }

    private func packageBackupInBackground() async throws -> URL {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
        
        await viewModel.saveOrders()
        let jsonSourceURL = viewModel.ordersFileURL
        let jsonDestinationURL = tempDirectory.appendingPathComponent("app_orders.json")
        if fileManager.fileExists(atPath: jsonSourceURL.path) {
            try fileManager.copyItem(at: jsonSourceURL, to: jsonDestinationURL)
        }
        
        let imagesDirectory = tempDirectory.appendingPathComponent("Images")
        let allImageIDs = Set(viewModel.orders.flatMap { $0.orderItems.flatMap { $0.productImageIdentifiers } })
        
        if !allImageIDs.isEmpty {
            try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true, attributes: nil)
            for imageID in allImageIDs {
                if let imageURL = ImageStore.shared.urlForImage(with: imageID) {
                    let destinationURL = imagesDirectory.appendingPathComponent("\(imageID).jpg")
                    try fileManager.copyItem(at: imageURL, to: destinationURL)
                }
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let zipFileName = "商家记账本备份_\(formatter.string(from: Date())).zip"
        let zipFileURL = fileManager.temporaryDirectory.appendingPathComponent(zipFileName)
        
        if fileManager.fileExists(atPath: zipFileURL.path) {
            try fileManager.removeItem(at: zipFileURL)
        }

        try fileManager.zipItem(at: tempDirectory, to: zipFileURL)
        try fileManager.removeItem(at: tempDirectory)
        
        return zipFileURL
    }
}
