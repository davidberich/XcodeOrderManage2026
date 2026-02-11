// OrderApp.swift

import SwiftUI

@main
struct OrderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var viewModel = OrderViewModel()
    // <<< 修改点 1：创建 UserSettings 的 StateObject 实例 >>>
    @StateObject private var userSettings = UserSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                // <<< 修改点 2：将 userSettings 注入到环境中 >>>
                .environmentObject(userSettings)
        }
    }
}

