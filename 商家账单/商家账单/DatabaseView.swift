// DatabaseView.swift

import SwiftUI

struct DatabaseView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var flatRecords: [FlatOrderRecord] = []
    
    @State private var isShowingShareSheet = false
    @State private var csvFileURL: URL?
    
    // MARK: - 1. 定义表头
    private let headers = [
        "订单号",        // 0
        "客户名称",      // 1
        "产品编号ID",    // 2
        "颜色/皮料",     // 3
        "码数/件数",     // 4 (合并显示)
        "总件数",        // 5
        "无标/客人标",   // 6
        "单价💰",        // 7
        "销售总金额",    // 8
        "订单日期"       // 9
    ]
    
    // MARK: - 2. 定义列宽
    private let columnWidths: [CGFloat] = [
        140, // 订单号
        100, // 客户名称
        140, // 产品编号ID
        150, // 颜色/皮料
        160, // 码数/件数 (变宽了，因为要显示一长串)
        60,  // 总件数
        90,  // 无标/客人标
        100, // 单价
        100, // 销售总金额
        110  // 订单日期
    ]

    private let columnAlignments: [Alignment] = [
        .leading, .leading, .leading, .leading,
        .leading, // 码数现在比较长，靠左对齐可能更好看
        .center,
        .center,
        .trailing, .trailing, .trailing
    ]
    
    var body: some View {
        NavigationView {
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    LazyVGrid(columns: [GridItem()], pinnedViews: [.sectionHeaders]) {
                        Section(header: HeaderView(headers: headers, columnWidths: columnWidths, alignments: columnAlignments)) {
                            ForEach(flatRecords.indices, id: \.self) { index in
                                RowView(
                                    record: flatRecords[index],
                                    columnWidths: columnWidths,
                                    alignments: columnAlignments,
                                    backgroundColor: index % 2 == 0 ? Color(.systemBackground) : Color(.systemGray6)
                                )
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("数据库")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: exportData) {
                        Label("导出Excel (CSV)", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear(perform: flattenOrders)
            .sheet(isPresented: $isShowingShareSheet, onDismiss: cleanupCSVFile) {
                if let url = csvFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
}

// MARK: - 导出逻辑
private extension DatabaseView {
    func exportData() {
        let csvString = generateCSVString()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let fileName = "数据库导出_\(Date().formattedAsYMDWithSlash().replacingOccurrences(of: "/", with: "-")).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            self.csvFileURL = fileURL
            self.isShowingShareSheet = true
        } catch {
            print("创建CSV文件失败: \(error.localizedDescription)")
        }
    }

    func generateCSVString() -> String {
        var csvText = "\u{FEFF}" // BOM for Excel
        
        csvText += headers.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
        
        for record in flatRecords {
            let rowData: [String] = [
                record.orderNumber,
                record.customerName,
                record.productName,
                record.colorAndLeather,
                record.sizeQuantitySummary,                     // 聚合后的字符串 (37x1, 38x2)
                "\(record.totalItemQuantity)",                  // 总件数
                record.trademark,
                "CN¥\(String(format: "%.2f", record.unitPrice))",
                "CN¥\(String(format: "%.2f", record.itemTotalPrice))",
                record.orderDate.formattedAsYMDWithSlash()
            ]
            
            csvText += rowData.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
        }
        
        return csvText
    }
    
    func escapeCSVField(_ field: String) -> String {
        let sanitized = field.replacingOccurrences(of: "\"", with: "\"\"")
        if sanitized.contains(",") || sanitized.contains("\n") || sanitized.contains("\"") {
            return "\"\(sanitized)\""
        }
        return sanitized
    }
    
    func cleanupCSVFile() {
        if let url = csvFileURL {
            try? FileManager.default.removeItem(at: url)
            csvFileURL = nil
        }
    }
}

// MARK: - 视图组件
private struct HeaderView: View {
    let headers: [String]
    let columnWidths: [CGFloat]
    let alignments: [Alignment]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<headers.count, id: \.self) { index in
                Text(headers[index])
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .frame(width: columnWidths[index], alignment: .init(horizontal: alignments[index].horizontal, vertical: .center))
            }
        }
        .background(Color(.systemGray5))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(.systemGray3)), alignment: .bottom)
    }
}

private struct RowView: View {
    let record: FlatOrderRecord
    let columnWidths: [CGFloat]
    let alignments: [Alignment]
    let backgroundColor: Color
    
    var body: some View {
        HStack(spacing: 0) {
            cell(text: record.orderNumber, width: columnWidths[0], align: alignments[0])
                .font(.system(.caption, design: .monospaced))
            
            cell(text: record.customerName, width: columnWidths[1], align: alignments[1])
            
            cell(text: record.productName, width: columnWidths[2], align: alignments[2])
            
            cell(text: record.colorAndLeather, width: columnWidths[3], align: alignments[3])
                .font(.caption)
            
            // 码数/件数 (显示聚合字符串)
            cell(text: record.sizeQuantitySummary, width: columnWidths[4], align: alignments[4])
                .fontWeight(.bold)
                .font(.caption) // 字稍微小一点，因为可能很长
            
            cell(text: "\(record.totalItemQuantity)", width: columnWidths[5], align: alignments[5])
            
            cell(text: record.trademark, width: columnWidths[6], align: alignments[6])
            
            cell(text: "CN¥\(String(format: "%.2f", record.unitPrice))", width: columnWidths[7], align: alignments[7])
                .font(.caption)
            
            cell(text: "CN¥\(String(format: "%.2f", record.itemTotalPrice))", width: columnWidths[8], align: alignments[8])
                .foregroundColor(.blue)
                .fontWeight(.medium)
            
            cell(text: record.orderDate.formattedAsYMDWithSlash(), width: columnWidths[9], align: alignments[9])
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .background(backgroundColor)
    }
    
    private func cell(text: String, width: CGFloat, align: Alignment) -> some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
            .frame(width: width, alignment: align)
            .lineLimit(2)
    }
}

// MARK: - 数据扁平化逻辑 (核心修改)
extension DatabaseView {
    private func flattenOrders() {
        var records: [FlatOrderRecord] = []
        let sortedOrders = viewModel.orders.sorted { $0.date > $1.date }
        
        for order in sortedOrders {
            for item in order.orderItems {
                // 1. 获取所有有数量的尺码
                let validSizes = item.sizeQuantities.filter { $0.value > 0 }
                
                if !validSizes.isEmpty {
                    // 2. 按照尺码大小排序 (37, 38, 39...)
                    let sortedSizeKeys = validSizes.keys.sorted()
                    
                    // 3. 构建聚合字符串: "37x1, 38x2"
                    // replacingOccurrences: 去掉"码"字，只留数字
                    let summaryString = sortedSizeKeys.map { sizeKey in
                        let qty = validSizes[sizeKey]!
                        let sizeNum = sizeKey.replacingOccurrences(of: "码", with: "")
                        return "\(sizeNum)x\(qty)"
                    }.joined(separator: ", ")
                    
                    // 4. 创建一条记录
                    let record = FlatOrderRecord(
                        orderNumber: order.orderNumber,
                        customerName: order.customerName,
                        productName: item.productName,
                        colorAndLeather: item.color,
                        sizeQuantitySummary: summaryString, // <--- 使用聚合字符串
                        totalItemQuantity: item.totalItemQuantity,
                        trademark: order.trademark.displayTitle,
                        unitPrice: item.unitPrice,
                        orderDate: order.date
                    )
                    records.append(record)
                }
            }
        }
        self.flatRecords = records
    }
} 
