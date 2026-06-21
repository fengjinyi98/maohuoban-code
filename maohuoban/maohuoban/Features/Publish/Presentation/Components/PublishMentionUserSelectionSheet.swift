import SwiftUI
import MaohuobanDesignSystem

// PublishMentionUserOption 发布提及用户候选
// 核心职责：
// - 承载发布页 @ 用户选择的本地候选数据
// - 为正文插入提及文本提供稳定用户名称
struct PublishMentionUserOption: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
}

// PublishMentionUserSelectionSheet 发布提及用户选择弹层
// 核心职责：
// - 复用旧发布模块的粉丝与关注分组选择形态
// - 管理搜索、分组展开和多选确认状态
struct PublishMentionUserSelectionSheet: View {
    let onCancel: () -> Void
    let onConfirm: ([PublishMentionUserOption]) -> Void

    @State private var searchText = ""
    @State private var isFansExpanded = true
    @State private var isFollowsExpanded = true
    @State private var selectedUserIDs = Set<String>()
    @FocusState private var isSearchFocused: Bool

    private let fans = PublishMentionUserMockOptions.fans
    private let follows = PublishMentionUserMockOptions.follows

    var body: some View {
        VStack(spacing: 0) {
            PublishMentionUserSheetHeader(
                title: "@用户",
                canConfirm: selectedUserIDs.isEmpty == false,
                isSearchFocused: isSearchFocused,
                onCancel: onCancel,
                onConfirm: {
                    onConfirm(selectedUsersInDisplayOrder)
                }
            )

            PublishMentionUserSearchBar(
                searchText: $searchText,
                isSearchFocused: $isSearchFocused,
                onClear: clearSearch,
                onCancelSearch: cancelSearch
            )

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    if isSearchFocused, searchText.isEmpty == false {
                        ForEach(filteredUsers) { user in
                            PublishMentionUserSelectorRow(
                                user: user,
                                isSelected: selectedUserIDs.contains(user.id),
                                action: { toggleUserSelection(user.id) }
                            )
                        }
                    } else {
                        PublishMentionUserGroupHeader(
                            title: "我的粉丝 (\(fans.count))",
                            isExpanded: isFansExpanded,
                            toggleExpansion: toggleFansExpanded,
                            toggleSelectAll: { toggleSelectAllUsers(in: fans) }
                        )

                        if isFansExpanded {
                            ForEach(fans) { user in
                                PublishMentionUserSelectorRow(
                                    user: user,
                                    isSelected: selectedUserIDs.contains(user.id),
                                    action: { toggleUserSelection(user.id) }
                                )
                            }
                        }

                        Divider()
                            .padding(.horizontal, MHBTheme.Spacing.s4)

                        PublishMentionUserGroupHeader(
                            title: "关注的人 (\(follows.count))",
                            isExpanded: isFollowsExpanded,
                            toggleExpansion: toggleFollowsExpanded,
                            toggleSelectAll: { toggleSelectAllUsers(in: follows) }
                        )

                        if isFollowsExpanded {
                            ForEach(follows) { user in
                                PublishMentionUserSelectorRow(
                                    user: user,
                                    isSelected: selectedUserIDs.contains(user.id),
                                    action: { toggleUserSelection(user.id) }
                                )
                            }
                        }
                    }
                }
                .padding(.bottom, MHBTheme.Spacing.s6)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var filteredUsers: [PublishMentionUserOption] {
        (fans + follows).filter { user in
            user.name.localizedCaseInsensitiveContains(searchText)
                || user.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedUsersInDisplayOrder: [PublishMentionUserOption] {
        (fans + follows).filter { selectedUserIDs.contains($0.id) }
    }

    private func clearSearch() {
        searchText = ""
    }

    private func cancelSearch() {
        isSearchFocused = false
        searchText = ""
    }

    private func toggleFansExpanded() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isFansExpanded.toggle()
        }
    }

    private func toggleFollowsExpanded() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isFollowsExpanded.toggle()
        }
    }

    private func toggleUserSelection(_ id: String) {
        if selectedUserIDs.contains(id) {
            selectedUserIDs.remove(id)
            return
        }
        selectedUserIDs.insert(id)
    }

    private func toggleSelectAllUsers(in users: [PublishMentionUserOption]) {
        let userIDs = Set(users.map(\.id))
        if selectedUserIDs.isSuperset(of: userIDs) {
            selectedUserIDs.subtract(userIDs)
            return
        }
        selectedUserIDs.formUnion(userIDs)
    }
}

// PublishMentionUserSheetHeader 提及用户弹层头部
// 核心职责：
// - 承载取消、标题和确认动作
private struct PublishMentionUserSheetHeader: View {
    let title: String
    let canConfirm: Bool
    let isSearchFocused: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack {
            Button("取消", action: onCancel)
                .font(MHBTheme.Typography.body)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .opacity(isSearchFocused ? 0 : 1)
                .allowsHitTesting(isSearchFocused == false)

            Spacer()

            Text(title)
                .font(MHBTheme.Typography.body.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            Button("确定", action: onConfirm)
                .font(MHBTheme.Typography.body.weight(.semibold))
                .foregroundStyle(
                    canConfirm
                        ? MHBTheme.ColorToken.primary.color
                        : MHBTheme.ColorToken.labelTertiary.color
                )
                .opacity(isSearchFocused ? 0 : 1)
                .allowsHitTesting(isSearchFocused == false && canConfirm)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.top, MHBTheme.Spacing.s2)
        .padding(.bottom, MHBTheme.Spacing.s3)
    }
}

// PublishMentionUserSearchBar 提及用户搜索栏
// 核心职责：
// - 提供用户昵称与伙伴号搜索输入
private struct PublishMentionUserSearchBar: View {
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    let onClear: () -> Void
    let onCancelSearch: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

                TextField("搜索用户昵称或伙伴号", text: $searchText)
                    .focused(isSearchFocused)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                if searchText.isEmpty == false {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, 10)
            .background(MHBTheme.ColorToken.separatorSoft.color, in: .rect(cornerRadius: 20))

            Button("取消", action: onCancelSearch)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .opacity(isSearchFocused.wrappedValue ? 1 : 0)
                .allowsHitTesting(isSearchFocused.wrappedValue)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, MHBTheme.Spacing.s3)
    }
}

// PublishMentionUserSelectorRow 提及用户选择行
// 核心职责：
// - 展示用户信息与勾选状态
// - 处理单个用户的选中切换
private struct PublishMentionUserSelectorRow: View {
    let user: PublishMentionUserOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Circle()
                    .fill(MHBTheme.ColorToken.separatorSoft.color)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    }

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(user.name)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    if user.subtitle.isEmpty == false {
                        Text(user.subtitle)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                            .lineLimit(1)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected
                                ? Color.clear
                                : MHBTheme.ColorToken.separator.color,
                            lineWidth: 1
                        )
                        .background(
                            Circle()
                                .fill(isSelected ? MHBTheme.ColorToken.primary.color : .clear)
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// PublishMentionUserGroupHeader 提及用户分组头部
// 核心职责：
// - 展示分组标题与展开状态
// - 提供分组全选入口
private struct PublishMentionUserGroupHeader: View {
    let title: String
    let isExpanded: Bool
    let toggleExpansion: () -> Void
    let toggleSelectAll: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Button(action: toggleExpansion) {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text(title)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button("全选", action: toggleSelectAll)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .contentShape(Rectangle())
    }
}

// PublishMentionUserMockOptions 提及用户本地候选
// 核心职责：
// - 为前端 UI 阶段提供粉丝与关注用户候选
private enum PublishMentionUserMockOptions {
    static let fans: [PublishMentionUserOption] = [
        PublishMentionUserOption(id: "fan-clawpilot", name: "ClawPilot", subtitle: "最近互动"),
        PublishMentionUserOption(id: "fan-jiuwo", name: "自由设计酒窝姐", subtitle: "关注你的用户"),
        PublishMentionUserOption(id: "fan-huangdapiao", name: "黄大飘V2.0", subtitle: "同城宠友"),
        PublishMentionUserOption(id: "fan-offer", name: "Offer行动+（带作品集）", subtitle: "关注你的用户"),
    ]

    static let follows: [PublishMentionUserOption] = [
        PublishMentionUserOption(id: "follow-linxi", name: "林夕 | UI设计师", subtitle: "关注的人"),
        PublishMentionUserOption(id: "follow-qisimeow", name: "奇思喵想", subtitle: "宠物内容作者"),
        PublishMentionUserOption(id: "follow-twilight", name: "Twilight Studio", subtitle: "宠物摄影"),
    ]
}
