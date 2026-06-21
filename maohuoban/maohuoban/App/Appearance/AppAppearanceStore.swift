import Foundation
import Observation
import SwiftUI

// AppAppearanceMode App 外观模式
// 核心职责：
// - 描述 App 可选择的系统、浅色和深色外观
// - 为设置页展示和 SwiftUI ColorScheme 映射提供稳定语义
enum AppAppearanceMode: String, CaseIterable, Equatable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            "跟随系统"
        case .light:
            "浅色模式"
        case .dark:
            "深色模式"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

// AppAppearanceStore App 外观偏好状态源
// 核心职责：
// - 从 UserDefaults 读取并持久化外观偏好
// - 向设置页和 App 壳层暴露当前 ColorScheme
@MainActor
@Observable
final class AppAppearanceStore {
    static let defaultsKey = "MHB_APP_APPEARANCE_MODE"

    private let defaults: UserDefaults
    private(set) var mode: AppAppearanceMode

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: Self.defaultsKey),
           let storedMode = AppAppearanceMode(rawValue: rawValue) {
            self.mode = storedMode
        } else {
            self.mode = .system
        }
    }

    var preferredColorScheme: ColorScheme? {
        mode.preferredColorScheme
    }

    var displayText: String {
        mode.title
    }

    var isDarkModeEnabled: Bool {
        mode == .dark
    }

    var followsSystem: Bool {
        mode == .system
    }

    func setMode(_ mode: AppAppearanceMode) {
        guard self.mode != mode else { return }

        self.mode = mode
        defaults.set(mode.rawValue, forKey: Self.defaultsKey)
    }

    func setDarkModeEnabled(_ isEnabled: Bool) {
        setMode(isEnabled ? .dark : .light)
    }

    func setFollowsSystem(_ followsSystem: Bool) {
        if followsSystem {
            setMode(.system)
        } else if mode == .system {
            setMode(.light)
        }
    }
}
