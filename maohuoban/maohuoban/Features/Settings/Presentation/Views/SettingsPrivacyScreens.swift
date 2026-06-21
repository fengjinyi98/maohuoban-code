import SwiftUI
import MaohuobanDesignSystem

// SettingsPrivacySettingsScreen 隐私设置页面
// 核心职责：
// - 管理互动、关系、权限和个性化隐私入口
// - 提供旧项目隐私设置页的开关与导航行
struct SettingsPrivacySettingsScreen: View {
    let onOnlineStatus: () -> Void
    let onDMPrivacy: () -> Void
    let onCollectionPrivacy: () -> Void
    let onEvaluationPrivacy: () -> Void
    let onFindMeWay: () -> Void
    let onRelationshipPrivacy: () -> Void
    let onBlacklist: () -> Void
    let onSystemPermissions: () -> Void
    let onPersonalization: () -> Void

    @State private var isOneClickProtect = false
    @State private var isShowChatBadge = true
    @State private var isLimitComment = false
    @State private var isLimitBulletChat = false
    @State private var isLimitAt = false
    @State private var isRecommendContact = true

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                SettingsSectionHeader(title: "互动")
                SettingsSection {
                    SettingsToggleRow(title: "一键防护", subtitle: "开启后，7天内将不接收未关注人的私信/评论/分享", isOn: $isOneClickProtect)
                    SettingsDivider()
                    SettingsRow(title: "在线状态", value: "好友", action: onOnlineStatus)
                    SettingsDivider()
                    SettingsToggleRow(title: "展示聊天标识", isOn: $isShowChatBadge)
                    SettingsDivider()
                    SettingsToggleRow(title: "只允许我关注的人评论我", isOn: $isLimitComment)
                    SettingsDivider()
                    SettingsToggleRow(title: "只允许我关注的人给我发弹幕", isOn: $isLimitBulletChat)
                    SettingsDivider()
                    SettingsToggleRow(title: "只允许我关注的人 @ 我", isOn: $isLimitAt)
                    SettingsDivider()
                    SettingsRow(title: "谁可以私信我", value: "所有人", action: onDMPrivacy)
                    SettingsDivider()
                    SettingsRow(title: "我的收藏", value: "已公开", action: onCollectionPrivacy)
                    SettingsDivider()
                    SettingsRow(title: "我的评价", value: "已公开", action: onEvaluationPrivacy)
                }

                SettingsSectionHeader(title: "关系")
                SettingsSection {
                    SettingsRow(title: "找到我的方式", action: onFindMeWay)
                    SettingsDivider()
                    SettingsRow(title: "关注与粉丝列表", action: onRelationshipPrivacy)
                    SettingsDivider()
                    SettingsToggleRow(title: "给我推荐可能认识的人", isOn: $isRecommendContact)
                    SettingsDivider()
                    SettingsRow(title: "黑名单用户", action: onBlacklist)
                }

                SettingsSectionHeader(title: "权限")
                SettingsSection {
                    SettingsRow(title: "系统权限管理", subtitle: "APP 内使用的所有系统权限", action: onSystemPermissions)
                }

                SettingsSectionHeader(title: "广告与算法")
                SettingsSection {
                    SettingsRow(title: "个性化选项", action: onPersonalization)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("隐私设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// SettingsOnlineStatusScreen 在线状态设置页面
// 核心职责：
// - 设置在线状态可见范围
// - 用单选列表表达当前选择
struct SettingsOnlineStatusScreen: View {
    @State private var selectedStatus = "好友"
    private let options = ["所有人", "好友", "互相关注的人", "关闭"]

    var body: some View {
        SettingsOptionListScreen(
            title: "在线状态",
            options: options,
            selectedOption: $selectedStatus,
            footer: "关闭后，你的在线状态不会展示给其他人。"
        )
    }
}

// SettingsDMPrivacyScreen 私信隐私设置页面
// 核心职责：
// - 设置允许私信我的用户范围
// - 保持旧项目四档权限选择
struct SettingsDMPrivacyScreen: View {
    @State private var selectedPermission = "所有人"
    private let options = ["所有人", "我关注的人", "互相关注的人", "关闭"]

    var body: some View {
        SettingsOptionListScreen(
            title: "谁可以私信我",
            options: options,
            selectedOption: $selectedPermission,
            footer: "关闭后，未授权用户无法向你发送新的私信。"
        )
    }
}

// SettingsCollectionPrivacyScreen 收藏隐私设置页面
// 核心职责：
// - 管理收藏与相关内容公开状态
// - 提供旧项目收藏隐私的开关组合
struct SettingsCollectionPrivacyScreen: View {
    @State private var isPublicCollection = true
    @State private var isAllNotesPublic = true
    @State private var isCollectionSetPublic = true
    @State private var isInspirationPublic = true
    @State private var isMusicPublic = true
    @State private var isCommentPublic = true

    var body: some View {
        SettingsToggleListScreen(title: "收藏隐私设置") {
            SettingsToggleRow(title: "公开我的收藏", subtitle: "关闭后，其他人将无法查看你的收藏内容", isOn: $isPublicCollection)
            SettingsDivider()
            SettingsToggleRow(title: "所有动态", isOn: $isAllNotesPublic)
            SettingsDivider()
            SettingsToggleRow(title: "合集", isOn: $isCollectionSetPublic)
            SettingsDivider()
            SettingsToggleRow(title: "发布灵感", isOn: $isInspirationPublic)
            SettingsDivider()
            SettingsToggleRow(title: "音乐", isOn: $isMusicPublic)
            SettingsDivider()
            SettingsToggleRow(title: "评论", isOn: $isCommentPublic)
        }
    }
}

// SettingsEvaluationPrivacyScreen 评价隐私设置页面
// 核心职责：
// - 管理我的评价中地点信息公开状态
// - 保持设置页独立开关体验
struct SettingsEvaluationPrivacyScreen: View {
    @State private var isLocationPublic = true

    var body: some View {
        SettingsToggleListScreen(title: "评价隐私设置") {
            SettingsToggleRow(title: "地点", subtitle: "公开评价地点后，他人可以在评价中看到相关门店或服务点", isOn: $isLocationPublic)
        }
    }
}

// SettingsFindMeWayScreen 找到我的方式页面
// 核心职责：
// - 管理推荐、关系列表、附近和识图搜索曝光
// - 提供旧项目找到我的方式开关组合
struct SettingsFindMeWayScreen: View {
    @State private var recommendToKnown = true
    @State private var showInRelationshipList = true
    @State private var hideInNearby = true
    @State private var hideInImageSearch = false

    var body: some View {
        SettingsToggleListScreen(title: "找到我的方式") {
            SettingsToggleRow(title: "把我推荐给可能认识的人", isOn: $recommendToKnown)
            SettingsDivider()
            SettingsToggleRow(title: "把我展示在他人关系列表", isOn: $showInRelationshipList)
            SettingsDivider()
            SettingsToggleRow(title: "在「附近」页隐藏我的动态", isOn: $hideInNearby)
            SettingsDivider()
            SettingsToggleRow(title: "在「识图搜同款」中隐藏我的动态", isOn: $hideInImageSearch)
        }
    }
}

// SettingsRelationshipPrivacyScreen 关系隐私设置页面
// 核心职责：
// - 管理关注列表和粉丝列表可见性
// - 提供关系隐私独立设置入口
struct SettingsRelationshipPrivacyScreen: View {
    @State private var hideFollowingList = true
    @State private var hideFollowerList = true

    var body: some View {
        SettingsToggleListScreen(title: "关注与粉丝列表") {
            SettingsToggleRow(title: "隐藏我的关注列表", isOn: $hideFollowingList)
            SettingsDivider()
            SettingsToggleRow(title: "隐藏我的粉丝列表", isOn: $hideFollowerList)
        }
    }
}

// SettingsBlacklistScreen 黑名单页面
// 核心职责：
// - 展示被拉黑用户列表
// - 在 mock 阶段提供稳定空状态
struct SettingsBlacklistScreen: View {
    var body: some View {
        ContentUnavailableView(
            "暂无黑名单用户",
            systemImage: "person.crop.circle.badge.xmark",
            description: Text("被拉黑的用户会出现在这里。")
        )
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("黑名单")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// SettingsPersonalizationScreen 个性化选项页面
// 核心职责：
// - 管理内容推荐和广告推荐开关
// - 为算法类设置提供独立说明
struct SettingsPersonalizationScreen: View {
    @State private var contentRecommendation = true
    @State private var adRecommendation = true

    var body: some View {
        SettingsToggleListScreen(title: "个性化选项") {
            SettingsToggleRow(title: "个性化内容推荐", subtitle: "根据你的互动和浏览行为优化内容排序", isOn: $contentRecommendation)
            SettingsDivider()
            SettingsToggleRow(title: "个性化广告推荐", subtitle: "根据你的兴趣偏好展示更相关的广告", isOn: $adRecommendation)
        }
    }
}

// SettingsSystemPermissionsScreen 系统权限管理页面
// 核心职责：
// - 展示系统权限项和当前状态
// - 提供跳转 iOS 系统设置入口
struct SettingsSystemPermissionsScreen: View {
    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                Button(action: openSystemSettings) {
                    Label("系统权限设置", systemImage: "gearshape")
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(MHBTheme.ColorToken.primary.color)
                        .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
                }

                SettingsSection {
                    SettingsRow(title: "相机", value: "前往设置", action: openSystemSettings)
                    SettingsDivider()
                    SettingsRow(title: "照片", value: "前往设置", action: openSystemSettings)
                    SettingsDivider()
                    SettingsRow(title: "位置", value: "前往设置", action: openSystemSettings)
                    SettingsDivider()
                    SettingsRow(title: "通知", value: "前往设置", action: openSystemSettings)
                    SettingsDivider()
                    SettingsRow(title: "麦克风", value: "前往设置", action: openSystemSettings)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("系统权限管理")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// SettingsOptionListScreen 设置单选列表页面
// 核心职责：
// - 承载隐私范围类页面的通用单选布局
// - 将选中项写入页面本地状态
private struct SettingsOptionListScreen: View {
    let title: String
    let options: [String]
    @Binding var selectedOption: String
    let footer: String

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                SettingsSection {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        SettingsOptionRow(
                            title: option,
                            isSelected: selectedOption == option
                        ) {
                            selectedOption = option
                        }
                        if index < options.count - 1 {
                            SettingsDivider()
                        }
                    }
                }

                Text(footer)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s2)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// SettingsToggleListScreen 设置开关列表页面
// 核心职责：
// - 统一承载单分组开关页面
// - 保持普通设置页面滚动与导航样式一致
private struct SettingsToggleListScreen<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        MHBScreenScrollView {
            SettingsSection {
                content
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
