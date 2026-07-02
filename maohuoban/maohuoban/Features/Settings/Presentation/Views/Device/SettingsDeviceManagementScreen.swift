import SwiftUI
import MaohuobanDesignSystem

// SettingsDeviceManagementScreen 登录设备管理页面
// 核心职责：
// - 展示当前账号已登录设备列表
// - 将设备详情点击交给 Profile 路由推进
struct SettingsDeviceManagementScreen: View {
    let store: SettingsDeviceSessionStore
    let onDeviceDetail: (String) -> Void

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                if store.isLoadingDevices {
                    ProgressView("加载设备中...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, MHBTheme.Spacing.s8)
                } else if store.devices.isEmpty {
                    ContentUnavailableView("暂无登录设备", systemImage: "iphone")
                } else {
                    SettingsSection {
                        ForEach(Array(store.devices.enumerated()), id: \.element.sessionID) { index, device in
                            SettingsDeviceRow(device: device) {
                                onDeviceDetail(device.sessionID)
                            }
                            if index < store.devices.count - 1 {
                                SettingsDivider()
                            }
                        }
                    }
                }

                if let error = store.lastErrorMessage {
                    Text(error)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.danger.color)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("登录设备管理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadDevices()
        }
    }
}

// SettingsDeviceRow 登录设备列表行
// 核心职责：
// - 展示设备图标、名称、是否当前设备和最近活跃信息
// - 点击后由上层路由推进设备详情
struct SettingsDeviceRow: View {
    let device: SettingsDeviceSessionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: device.deviceModel.lowercased().contains("ipad") ? "ipad" : "iphone")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        Text(device.deviceName)
                            .font(MHBTheme.Typography.body)
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        if device.isCurrentDevice {
                            Text("当前设备")
                                .font(MHBTheme.Typography.section)
                                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        }
                    }
                    Text("\(device.locationText) · \(device.lastActiveText)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .padding(MHBTheme.Spacing.s4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
