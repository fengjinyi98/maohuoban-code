import SwiftUI
import MaohuobanDesignSystem

// SettingsGeneralSettingsScreen 通用设置页面
// 核心职责：
// - 管理深色模式、播放、流量和发布体验设置入口
// - 提供旧项目通用设置页的开关布局
struct SettingsGeneralSettingsScreen: View {
    let appAppearanceStore: AppAppearanceStore
    let onDarkMode: () -> Void

    @State private var isMuteDefault = false
    @State private var isWiFiOnlyVideo = false
    @State private var isMobileDataDownload = false
    @State private var isVideoHDR = false
    @State private var isImageHDR = true
    @State private var isBrowsingHistory = true
    @State private var isVideoInteractionButtons = true
    @State private var isMobileImproveExperience = true
    @State private var isDownloadAllNotes = true
    @State private var isAutoRefresh = true

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                SettingsSection {
                    SettingsRow(title: "深色模式", value: appAppearanceStore.displayText, action: onDarkMode)
                    SettingsDivider()
                    SettingsToggleRow(title: "默认播放图文动态声音", isOn: .constant(false))
                }

                SettingsSectionHeader(title: "播放设置")
                SettingsSection {
                    SettingsToggleRow(title: "打开视频时默认静音", isOn: $isMuteDefault)
                    SettingsDivider()
                    SettingsToggleRow(title: "只在WiFi下自动播放视频", isOn: $isWiFiOnlyVideo)
                    SettingsDivider()
                    SettingsToggleRow(title: "使用移动流量下载内容", isOn: $isMobileDataDownload)
                    SettingsDivider()
                    SettingsToggleRow(title: "视频开启HDR效果", isOn: $isVideoHDR)
                    SettingsDivider()
                    SettingsToggleRow(title: "图片开启HDR效果", isOn: $isImageHDR)
                }

                SettingsSectionHeader(title: "浏览体验")
                SettingsSection {
                    SettingsToggleRow(title: "浏览记录", subtitle: "关闭后将不再记录动态、帖子和商品浏览历史", isOn: $isBrowsingHistory)
                    SettingsDivider()
                    SettingsToggleRow(title: "视频互动按钮", isOn: $isVideoInteractionButtons)
                    SettingsDivider()
                    SettingsToggleRow(title: "使用移动网络改善播放体验", isOn: $isMobileImproveExperience)
                    SettingsDivider()
                    SettingsToggleRow(title: "下载全部动态", isOn: $isDownloadAllNotes)
                    SettingsDivider()
                    SettingsToggleRow(title: "自动刷新推荐内容", isOn: $isAutoRefresh)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("通用设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// SettingsNotificationSettingsScreen 通知设置页面
// 核心职责：
// - 管理互动、交易和免打扰通知开关
// - 保持系统通知提示文案完整
struct SettingsNotificationSettingsScreen: View {
    @State private var isLikeNotify = true
    @State private var isCommentNotify = true
    @State private var isFollowNotify = true
    @State private var isAtNotify = true
    @State private var isShoppingNotify = true
    @State private var isQuietMode = false

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                SettingsSectionHeader(title: "互动通知")
                SettingsSection {
                    SettingsToggleRow(title: "点赞", isOn: $isLikeNotify)
                    SettingsDivider()
                    SettingsToggleRow(title: "评论", isOn: $isCommentNotify)
                    SettingsDivider()
                    SettingsToggleRow(title: "新增粉丝", isOn: $isFollowNotify)
                    SettingsDivider()
                    SettingsToggleRow(title: "@ 我", isOn: $isAtNotify)
                }

                SettingsSectionHeader(title: "交易与服务")
                SettingsSection {
                    SettingsToggleRow(title: "订单、物流和售后通知", isOn: $isShoppingNotify)
                }

                SettingsSectionHeader(title: "免打扰设置")
                SettingsSection {
                    SettingsToggleRow(title: "夜间免打扰", subtitle: "开启后 22:00-8:00 仅保留重要系统通知", isOn: $isQuietMode)
                }

                Text("若要在手机上开启或关闭毛伙伴的通知，请在系统的“设置” - “通知”中进行修改。")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s2)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
