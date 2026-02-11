// OrderDetailView.swift

import SwiftUI
import PhotosUI

struct OrderDetailView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    @EnvironmentObject var userSettings: UserSettings
    @Binding var order: Order
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingImages = false
    
    @FocusState private var focusedField: FocusField?
    enum FocusField: Hashable {
        case customerName, productName, colorAndLeather, quantity(String), unitPrice
    }
    
    private let allSizes = (33...42).map { "\($0)码" }
    private let columns = [GridItem(.adaptive(minimum: 70))]
    private let imageGridColumns = [GridItem(.adaptive(minimum: 100))]
    
    private var isReadOnly: Bool {
        order.status == .refunded
    }

    var body: some View {
        Form {
            if isReadOnly {
                readOnlyBanner
            }
            
            // 1. 客户信息
            customerInfoSection
            
            if !order.orderItems.isEmpty {
                // 2. 商品规格
                productSpecsSection
                
                // 3. 尺码选择
                sizeSelectionSection
                
                // 4. 尺码数量微调
                sizeQuantityAdjustmentSection
                
                // 5. 新增：价格信息 (查看/编辑)
                priceSection
                
                // 6. 图片选择
                imageSelectionSection
            } else {
                Text("数据异常：此订单没有商品").foregroundColor(.red)
            }
            
            // 7. 订单总览
            orderTotalSection
            
            // 8. 按钮
            factoryOrderButtonSection
        }
        .navigationTitle(isReadOnly ? "订单明细 (已退款)" : "订单明细/编辑")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    Task { await viewModel.saveOrders() }
                    presentationMode.wrappedValue.dismiss()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusedField = nil }
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            if !newItems.isEmpty { Task { await loadImages(from: newItems) } }
        }
        .onChange(of: order) { _ in
            Task { await viewModel.saveOrders() }
        }
    }
    
    // MARK: - 界面模块
    
    private var readOnlyBanner: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                Text("此订单已退货退款")
                Spacer()
                Button("恢复订单") {
                    viewModel.updateOrderStatus(for: order.id, to: .active)
                }
                .buttonStyle(.bordered)
            }
            .font(.headline).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private var customerInfoSection: some View {
        Section(header: Text("客户信息")) {
            HStack {
                Text("订单编号")
                Spacer()
                Text(order.orderNumber).foregroundColor(.secondary)
            }
            TextField("客户名称", text: $order.customerName)
                .focused($focusedField, equals: .customerName)
            
            Picker("订单速度", selection: $order.urgency) {
                ForEach(OrderUrgency.allCases) { Text($0.displayTitle).tag($0) }
            }.pickerStyle(.segmented)
            
            Picker("商标", selection: $order.trademark) {
                ForEach(TrademarkOption.allCases) { Text($0.displayTitle).tag($0) }
            }.pickerStyle(.segmented)
            
            DatePicker("日期", selection: $order.date, displayedComponents: .date)
        }
        .disabled(isReadOnly)
    }
    
    private var productSpecsSection: some View {
        Section(header: Text("商品规格")) {
            TextField("商品名称", text: $order.orderItems[0].productName)
                .focused($focusedField, equals: .productName)
            TextField("颜色和皮料", text: $order.orderItems[0].color)
                .focused($focusedField, equals: .colorAndLeather)
        }
        .disabled(isReadOnly)
    }
    
    private var sizeSelectionSection: some View {
        Section(header: Text("选择尺码")) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(allSizes, id: \.self) { size in
                    let isSelected = order.orderItems[0].sizeQuantities[size] != nil
                    Button(action: { toggleSizeSelection(size) }) {
                        Text(size)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(isSelected ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 5)
        }
        .disabled(isReadOnly)
    }
    
    private var sizeQuantityAdjustmentSection: some View {
        let selectedSizes = order.orderItems[0].sizeQuantities.keys.sorted()
        return Section(header: Text("尺码数量")) {
            if selectedSizes.isEmpty {
                Text("请先在上方选择尺码").foregroundColor(.secondary)
            } else {
                ForEach(selectedSizes, id: \.self) { size in
                    HStack {
                        Text(size).fontWeight(.medium).frame(width: 60, alignment: .leading)
                        TextField("数量", text: Binding(
                            get: { String(order.orderItems[0].sizeQuantities[size] ?? 0) },
                            set: { if let val = Int($0) { updateQuantity(for: size, value: val) } }
                        ))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .quantity(size))
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        
                        Stepper("", value: Binding(
                            get: { order.orderItems[0].sizeQuantities[size] ?? 1 },
                            set: { updateQuantity(for: size, value: $0) }
                        ), in: 0...999)
                    }
                }
            }
        }
        .disabled(isReadOnly)
    }
    
    // --- 新增：价格信息 ---
    private var priceSection: some View {
        Section(header: Text("价格信息")) {
            HStack {
                Text("单价")
                Spacer()
                // 使用 Binding 转换 Double <-> String
                TextField("0", text: Binding(
                    get: {
                        let val = order.orderItems[0].unitPrice
                        return val == 0 ? "" : String(format: "%.0f", val)
                    },
                    set: {
                        if let val = Double($0) { order.orderItems[0].unitPrice = val }
                        else if $0.isEmpty { order.orderItems[0].unitPrice = 0 }
                    }
                ))
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .unitPrice)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.blue)
                .frame(width: 100)
                
                Text("元").foregroundColor(.secondary)
            }
            
            HStack {
                Text("本单总金额")
                Spacer()
                let total = order.orderItems[0].unitPrice * Double(order.totalOrderQuantity)
                Text("¥\(String(format: "%.2f", total))")
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
        }
        .disabled(isReadOnly)
    }
    // -------------------
    
    private var imageSelectionSection: some View {
        Section(header: Text("商品图片")) {
            let identifiers = order.orderItems[0].productImageIdentifiers
            if !identifiers.isEmpty {
                LazyVGrid(columns: imageGridColumns, spacing: 12) {
                    ForEach(identifiers, id: \.self) { id in
                        if let uiImage = ImageStore.shared.loadImage(withIdentifier: id) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 100, height: 100).cornerRadius(8).clipped()
                                if !isReadOnly {
                                    Button(action: { deleteImage(id: id) }) {
                                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.white, .red)
                                    }.offset(x: 5, y: -5)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            if !isReadOnly {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) {
                    HStack { Image(systemName: "photo.badge.plus"); Text("添加图片") }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }
        }
    }
    
    private var orderTotalSection: some View {
        Section(header: Text("订单总计")) {
            HStack {
                Text("商品总数:")
                Spacer()
                Text("\(order.totalOrderQuantity) 件").fontWeight(.bold)
            }
            // 这里也同步显示一下总金额
            HStack {
                Text("订单总额:")
                Spacer()
                let total = order.orderItems[0].unitPrice * Double(order.totalOrderQuantity)
                Text("¥\(String(format: "%.2f", total))").fontWeight(.bold)
            }
        }
    }

    private var factoryOrderButtonSection: some View {
        Section {
            ZStack {
                NavigationLink(destination: FactoryOrderDetailView(order: order, item: $order.orderItems[0])) { EmptyView() }.opacity(0)
                HStack { Spacer(); Image(systemName: "doc.text.fill"); Text("生成工厂订单").fontWeight(.semibold); Spacer() }
            }
            .buttonStyle(FactoryOrderButtonStyle())
            .listRowInsets(EdgeInsets())
        }
        .disabled(order.orderItems.isEmpty || isReadOnly || order.customerName.isEmpty)
    }
    
    // MARK: - 逻辑处理
    private func toggleSizeSelection(_ size: String) {
        var quantities = order.orderItems[0].sizeQuantities
        if quantities[size] != nil { quantities[size] = nil } else { quantities[size] = 1 }
        order.orderItems[0].sizeQuantities = quantities
    }
    
    private func updateQuantity(for size: String, value: Int) {
        var quantities = order.orderItems[0].sizeQuantities
        if value <= 0 { quantities[size] = nil } else { quantities[size] = value }
        order.orderItems[0].sizeQuantities = quantities
    }
    
    private func loadImages(from items: [PhotosPickerItem]) async {
        isImportingImages = true
        var newIdentifiers: [String] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data), let id = ImageStore.shared.saveImage(uiImage) {
                newIdentifiers.append(id)
            }
        }
        await MainActor.run {
            order.orderItems[0].productImageIdentifiers.append(contentsOf: newIdentifiers)
            selectedPhotoItems = []
            isImportingImages = false
        }
    }
    
    private func deleteImage(id: String) {
        if let index = order.orderItems[0].productImageIdentifiers.firstIndex(of: id) {
            order.orderItems[0].productImageIdentifiers.remove(at: index)
            ImageStore.shared.deleteImage(withIdentifier: id)
        }
    }
}
