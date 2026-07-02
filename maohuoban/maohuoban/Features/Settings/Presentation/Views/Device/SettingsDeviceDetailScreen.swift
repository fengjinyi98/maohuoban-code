import SwiftUI
import MaohuobanDesignSystem

// SettingsDeviceDetailScreen 设备详情页面
// 核心职责：
// - 展示单个登录设备详细信息
// - 提供移除非当前设备的操作入口
struct SettingsDeviceDetailScreen: View {
    let sessionID: String
    let store: SettingsDeviceSessionStore

    private var details: SettingsDeviceSessionDetails? {
        store.deviceDetails[sessionID]
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                if store.loadingDetailDeviceID == sessionID {
                    ProgressView("加载设备详情...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, MHBTheme.Spacing.s8)
                } else if let details {
                    SettingsSection {
                        SettingsRow(title: "设备名称", value: details.summary.deviceName, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "设备型号", value: details.summary.deviceModel, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "系统版本", value: details.osVersion, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "App 版本", value: details.appVersion, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "登录地点", value: details.summary.locationText, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "首次登录", value: details.firstLoginText, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "最近活跃", value: details.summary.lastActiveText, showChevron: false)
                    }

                    if details.summary.isCurrentDevice == false {
                        Button(role: .destructive, action: removeDevice) {
                            Text(store.removingDeviceID == sessionID ? "移除中..." : "移除此设备")
                                .font(MHBTheme.Typography.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(MHBTheme.ColorToken.danger.color)
                                .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
                        }
                    }
                } else {
                    ContentUnavailableView("设备详情不可用", systemImage: "iphone.slash")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("设备详情")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sessionID) {
            await store.loadDetails(sessionID: sessionID)
        }
    }

    private func removeDevice() {
        Task {
            await store.removeDevice(sessionID: sessionID)
            showDeviceToast()
        }
    }

    private func showDeviceToast() {
        guard let message = store.toastMessage else { return }
        if store.lastErrorMessage == nil {
            MHBToastPresenter().success(message)
        } else {
            MHBToastPresenter().danger(message)
        }
    }
}
