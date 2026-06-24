import SwiftUI
import UIKit

// MHBNavigationSearchBarInstaller 导航栏搜索框安装器
// 核心职责：
// - 在 UIKit 生命周期中把 UISearchController 安装到当前 UINavigationItem
// - 复用系统集成式搜索栏布局和原生 Liquid Glass 外观
struct MHBNavigationSearchBarInstaller: UIViewControllerRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    let dismissRequestNonce: Int
    let prompt: String
    let tintColor: UIColor
    let textColor: UIColor
    let accessibilityIdentifier: String
    let onSubmit: () -> Void

    func makeUIViewController(context: Context) -> InstallerViewController {
        InstallerViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(
        _ uiViewController: InstallerViewController,
        context: Context
    ) {
        context.coordinator.parent = self
        uiViewController.coordinator = context.coordinator
        uiViewController.scheduleInstallSearchBar()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleUIViewController(
        _ uiViewController: InstallerViewController,
        coordinator: Coordinator
    ) {
        coordinator.uninstall()
    }
}
