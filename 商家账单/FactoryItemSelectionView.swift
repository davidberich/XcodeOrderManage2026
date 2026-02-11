
//FactoryItemSelectionView.swift

import SwiftUI

struct FactoryItemSelectionView: View {
    @State var order: Order

    var body: some View {
        Form {
            Section(header: Text("为哪个商品生成订单？")) {
                ForEach($order.orderItems) { $item in
                    NavigationLink(destination: FactoryOrderDetailView(order: order, item: $item)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.productName).font(.headline)
                            Text("\(item.color) / \(item.leather)")
                                .font(.caption).foregroundColor(.secondary)
                            Text("数量: \(item.totalItemQuantity)")
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("选择商品")
        .navigationBarTitleDisplayMode(.inline)
    }
}
