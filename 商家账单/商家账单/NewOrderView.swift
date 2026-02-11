// NewOrderView.swift

import SwiftUI
import PhotosUI

struct NewOrderView: View {
    @StateObject private var viewModel = NewOrderViewModel()
    @EnvironmentObject var mainViewModel: OrderViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var showingFactoryOrderSheet = false
    
    // 1. 焦点状态管理
    @FocusState private var focusedField: FocusField?
    
    enum FocusField: Hashable {
        case customerName, productName, colorAndLeather, quantity(String), unitPrice
    }
    
    private let allSizes = (33...42).map { "\($0)码" }
    private let columns = [GridItem(.adaptive(minimum: 70))]
    private let imageGridColumns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        NavigationView {
            Form {
                // 1. 客户信息
                customerInfoSection
                
                // 2. 商品规格
                productSpecsSection
                
                // 3. 尺码选择
                sizeSelectionSection
                
                // 4. 尺码数量微调
                if !viewModel.sizeQuantities.isEmpty {
                    sizeQuantityAdjustmentSection
                }
                
                // 5. 价格信息 (数字键盘)
                priceSection
                
                // 6. 图片选择
                imageSelectionSection
                
                // 7. 总览
                orderSummarySection
                
                // 8. 按钮
                factoryOrderButtonSection
            }
            .navigationTitle("创建新订单")
            .toolbar {
                // --- 顶部导航栏按钮 ---
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: deleteOrder) {
                        Text("删除").foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        viewModel.autoSave(in: mainViewModel)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.bold)
                }
                
                // --- 核心修复：数字键盘上方的“完成”按钮 ---
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer() // 把按钮推到最右边
                    Button("完成") {
                        focusedField = nil // 收起键盘
                    }
                    .fontWeight(.bold)
                }
            }
            // --- 实时保存监听 ---
            .onChange(of: viewModel.customerName) { _ in triggerAutoSave() }
            .onChange(of: viewModel.urgency) { _ in triggerAutoSave() }
            .onChange(of: viewModel.trademark) { _ in triggerAutoSave() }
            .onChange(of: viewModel.productName) { _ in triggerAutoSave() }
            .onChange(of: viewModel.color) { _ in triggerAutoSave() }
            .onChange(of: viewModel.sizeQuantities) { _ in triggerAutoSave() }
            .onChange(of: viewModel.unitPrice) { _ in triggerAutoSave() }
            .onChange(of: viewModel.loadedImages.map { $0.id }) { _ in triggerAutoSave() }
            
            .onChange(of: viewModel.selectedPhotoItems) { _, newItems in
                if !newItems.isEmpty {
                    Task {
                        await viewModel.loadImages(from: newItems)
                        triggerAutoSave()
                    }
                }
            }
            // --- 详情页预览 ---
            .sheet(isPresented: $showingFactoryOrderSheet) {
                if let orderID = viewModel.currentOrderID,
                   let index = mainViewModel.orders.firstIndex(where: { $0.id == orderID }) {
                    NavigationView {
                        FactoryOrderDetailView(
                            order: mainViewModel.orders[index],
                            item: $mainViewModel.orders[index].orderItems[0]
                        )
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("关闭") { showingFactoryOrderSheet = false }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 逻辑函数
    private func triggerAutoSave() {
        viewModel.autoSave(in: mainViewModel)
    }
    
    private func deleteOrder() {
        viewModel.deleteCurrentOrder(in: mainViewModel)
        presentationMode.wrappedValue.dismiss()
    }
    
    // MARK: - 界面模块
    private var customerInfoSection: some View {
        Section(header: Text("客户信息")) {
            TextField("客户名称", text: $viewModel.customerName)
                .focused($focusedField, equals: .customerName)
            
            Picker("订单速度", selection: $viewModel.urgency) {
                ForEach(OrderUrgency.allCases) { Text($0.displayTitle).tag($0) }
            }.pickerStyle(.segmented)
            
            Picker("商标", selection: $viewModel.trademark) {
                ForEach(TrademarkOption.allCases) { Text($0.displayTitle).tag($0) }
            }.pickerStyle(.segmented)
        }
    }
    
    private var productSpecsSection: some View {
        Section(header: Text("商品规格")) {
            TextField("商品名称 (必填)", text: $viewModel.productName)
                .focused($focusedField, equals: .productName)
            TextField("颜色和皮料 (必填)", text: $viewModel.color)
                .focused($focusedField, equals: .colorAndLeather)
        }
    }
    
    private var sizeSelectionSection: some View {
        Section(header: Text("选择尺码")) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(allSizes, id: \.self) { size in
                    let isSelected = viewModel.sizeQuantities[size] != nil
                    Button(action: { viewModel.toggleSizeSelection(size) }) {
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
    }
    
    private var sizeQuantityAdjustmentSection: some View {
        Section(header: Text("尺码数量")) {
            ForEach(viewModel.sizeQuantities.keys.sorted(), id: \.self) { size in
                HStack {
                    Text(size)
                        .fontWeight(.medium)
                        .frame(width: 60, alignment: .leading)
                    
                    TextField("数量", text: Binding(
                        get: { String(viewModel.sizeQuantities[size] ?? 0) },
                        set: { if let val = Int($0) { viewModel.updateQuantity(for: size, value: val) } }
                    ))
                    .keyboardType(.numberPad)
                    // 绑定焦点，以便键盘工具栏生效
                    .focused($focusedField, equals: .quantity(size))
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    
                    Stepper("", value: Binding(
                        get: { viewModel.sizeQuantities[size] ?? 1 },
                        set: { viewModel.updateQuantity(for: size, value: $0) }
                    ), in: 0...999)
                }
            }
        }
    }
    
    private var priceSection: some View {
        Section(header: Text("价格信息")) {
            HStack {
                Text("单价")
                Spacer()
                TextField("0", text: $viewModel.unitPrice)
                    .keyboardType(.decimalPad) // 使用小数键盘
                    // 核心：绑定焦点
                    .focused($focusedField, equals: .unitPrice)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.blue)
                    .frame(width: 100)
                Text("元")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("本单总金额")
                Spacer()
                Text("¥\(String(format: "%.2f", viewModel.calculatedTotalPrice))")
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var imageSelectionSection: some View {
        Section(header: Text("商品图片")) {
            if !viewModel.loadedImages.isEmpty {
                LazyVGrid(columns: imageGridColumns, spacing: 12) {
                    ForEach(viewModel.loadedImages) { wrapper in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: wrapper.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                .clipped()
                            
                            Button(action: { viewModel.deleteImage(id: wrapper.id) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .red)
                            }
                            .offset(x: 5, y: -5)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            PhotosPicker(selection: $viewModel.selectedPhotoItems, maxSelectionCount: 5, matching: .images) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text("添加图片")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    private var orderSummarySection: some View {
        Section(header: Text("订单总览")) {
            HStack {
                Text("商品总数:")
                Spacer()
                Text("\(viewModel.totalQuantity) 件").fontWeight(.bold)
            }
        }
    }
    
    private var factoryOrderButtonSection: some View {
        Section {
            Button(action: {
                viewModel.autoSave(in: mainViewModel)
                DispatchQueue.main.async { showingFactoryOrderSheet = true }
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "doc.text.fill")
                    Text("生成工厂订单").fontWeight(.semibold)
                    Spacer()
                }
            }
            .buttonStyle(FactoryOrderButtonStyle())
            .disabled(viewModel.currentOrderID == nil)
            .listRowInsets(EdgeInsets())
        }
    }
}
