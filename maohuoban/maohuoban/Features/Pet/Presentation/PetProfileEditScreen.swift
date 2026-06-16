import SwiftUI
import MaohuobanDesignSystem

// PetProfileEditScreen 宠物资料编辑页
// 核心职责：
// - 按 row section 样式展示宠物资料编辑入口
// - 保持当前阶段只承载页面设计和导航入口
struct PetProfileEditScreen: View {
    let context: PetProfileEditContext
    @State private var selectedProfileID: String
    @State private var editedNames: [String: String] = [:]
    @State private var nameEditorProfileID: String?
    @State private var nameEditorDraft = ""
    @State private var isNameEditorPresented = false
    @State private var isNameEditorChevronExpanded = false

    init(context: PetProfileEditContext) {
        self.context = context
        _selectedProfileID = State(initialValue: context.selectedProfile.id)
    }

    private var selectedProfile: PetProfileEditProfile {
        context.profiles.first(where: { $0.id == selectedProfileID }) ?? context.selectedProfile
    }

    var body: some View {
        let profile = selectedProfile
        let profileName = displayName(for: profile)

        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s6) {
                PetProfileEditPetPickerHeader(
                    profiles: context.profiles,
                    selectedProfileID: profile.id,
                    displayName: { displayName(for: $0) },
                    onSelectProfile: { profileID in
                        selectedProfileID = profileID
                    },
                    onAddPet: {
                        // TODO: 接入添加宠物档案流程
                    }
                )

                VStack(spacing: MHBTheme.Spacing.s4) {
                    PetProfileEditSection {
                        PetProfileEditRow(
                            title: "宠物名字",
                            isAccessoryExpanded: isNameEditorChevronExpanded && nameEditorProfileID == profile.id,
                            action: {
                                nameEditorProfileID = profile.id
                                nameEditorDraft = profileName
                                isNameEditorChevronExpanded = true
                                isNameEditorPresented = true
                            }
                        ) {
                            PetProfileEditValueText(value: profileName)
                        }

                        PetProfileEditRow(title: "芯片号") {
                            PetProfileEditValueText(value: profile.chipNumber)
                        }

                        PetProfileEditRow(title: "背景", showsSeparator: false) {
                            PetProfileEditMediaThumbnail(media: profile.heroMedia)
                        }
                    }

                    PetProfileEditSection {
                        PetProfileEditRow(title: "性别") {
                            PetProfileEditValueText(value: profile.sexText)
                        }

                        PetProfileEditRow(title: "出生日期") {
                            PetProfileEditValueText(value: profile.birthDateText)
                        }

                        PetProfileEditRow(title: "体重") {
                            PetProfileEditValueText(value: profile.weightText)
                        }

                        PetProfileEditRow(title: "绝育状态", showsSeparator: false) {
                            PetProfileEditValueText(value: profile.neuterStatusText)
                        }
                    }

                    PetProfileEditSection {
                        PetProfileEditRow(title: "性格标签") {
                            PetProfileEditTagFlow(tags: profile.personalityTags)
                        }

                        PetProfileEditRow(title: "备注", showsSeparator: false) {
                            PetProfileEditValueText(value: profile.note)
                        }
                    }
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("预览") {}
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            }
        }
        .sheet(
            isPresented: $isNameEditorPresented,
            onDismiss: {
                isNameEditorChevronExpanded = false
                nameEditorProfileID = nil
            }
        ) {
            PetProfileNameEditorSheet(
                name: $nameEditorDraft,
                onWillDismiss: {
                    isNameEditorChevronExpanded = false
                },
                onSave: {
                    guard let profileID = nameEditorProfileID else { return }
                    editedNames[profileID] = nameEditorDraft
                    isNameEditorChevronExpanded = false
                    isNameEditorPresented = false
                }
            )
        }
        .accessibilityIdentifier("pet.profileEdit.screen")
    }

    private func displayName(for profile: PetProfileEditProfile) -> String {
        editedNames[profile.id] ?? profile.name
    }
}

// PetProfileEditPetPickerHeader 编辑资料宠物切换头部
// 核心职责：
// - 横向展示当前可编辑宠物头像入口
// - 承载宠物切换和添加宠物入口
private struct PetProfileEditPetPickerHeader: View {
    let profiles: [PetProfileEditProfile]
    let selectedProfileID: String
    let displayName: (PetProfileEditProfile) -> String
    let onSelectProfile: (String) -> Void
    let onAddPet: () -> Void

    private let avatarSize: CGFloat = 78

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: MHBTheme.Spacing.s2) {
                ForEach(profiles) { profile in
                    PetProfileEditPetPickerItem(
                        profile: profile,
                        displayName: displayName(profile),
                        isSelected: profile.id == selectedProfileID,
                        avatarSize: avatarSize,
                        action: { onSelectProfile(profile.id) }
                    )
                    .accessibilityIdentifier("pet.profileEdit.petPicker.\(profile.id)")
                }

                PetProfileEditAddPetItem(
                    avatarSize: avatarSize,
                    action: onAddPet
                )
                .accessibilityIdentifier("pet.profileEdit.addPet")
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
        }
        .padding(.horizontal, -MHBTheme.Spacing.s4)
        .padding(.top, MHBTheme.Spacing.s3)
    }
}

// PetProfileEditPetPickerItem 编辑资料宠物头像切换项
// 核心职责：
// - 展示单只宠物的头像和名称
// - 通过选中态表达当前正在编辑的宠物档案
private struct PetProfileEditPetPickerItem: View {
    let profile: PetProfileEditProfile
    let displayName: String
    let isSelected: Bool
    let avatarSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                avatar

                Text(displayName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: avatarSize + 12)
                    .opacity(isSelected ? 0 : 1)
                    .accessibilityHidden(isSelected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "正在编辑\(displayName)" : "切换到\(displayName)")
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            PetProfileEditAvatarImage(
                avatarURL: profile.avatarURL,
                species: profile.species,
                size: avatarSize
            )
            .overlay {
                Circle()
                    .strokeBorder(
                        isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separatorSoft.color,
                        lineWidth: isSelected ? 2.5 : 1
                    )
            }

            if isSelected {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.78))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color(uiColor: .systemGroupedBackground), lineWidth: 2)
                    }
                    .offset(x: 1, y: 1)
            }
        }
    }
}

// PetProfileEditAddPetItem 编辑资料添加宠物入口
// 核心职责：
// - 在宠物头像横滑区域展示添加入口
// - 为后续接入创建宠物流程保留点击边界
private struct PetProfileEditAddPetItem: View {
    let avatarSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                Circle()
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    }

                Text("添加宠物")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .frame(width: avatarSize + 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加宠物")
    }
}

// PetProfileEditSection 编辑资料分组卡片
// 核心职责：
// - 承载一组资料编辑行
// - 统一卡片背景、圆角和分割线策略
private struct PetProfileEditSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// PetProfileEditRow 编辑资料通用行
// 核心职责：
// - 展示左侧字段名、右侧字段值和可进入提示
// - 保持各字段行高与分割线一致
private struct PetProfileEditRow<Value: View>: View {
    let title: String
    let showsSeparator: Bool
    let isAccessoryExpanded: Bool
    let action: () -> Void
    @ViewBuilder let value: () -> Value

    init(
        title: String,
        showsSeparator: Bool = true,
        isAccessoryExpanded: Bool = false,
        action: @escaping () -> Void = {},
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.title = title
        self.showsSeparator = showsSeparator
        self.isAccessoryExpanded = isAccessoryExpanded
        self.action = action
        self.value = value
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    value()
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    MHBAnimatedDisclosureChevron(isExpanded: isAccessoryExpanded)
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(minHeight: 52)
                .contentShape(Rectangle())

                if showsSeparator {
                    Rectangle()
                        .fill(MHBTheme.ColorToken.separatorSoft.color)
                        .frame(height: 0.5)
                        .padding(.horizontal, MHBTheme.Spacing.s4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// PetProfileNameEditorSheet 宠物昵称编辑弹层
// 核心职责：
// - 承载宠物名字的临时编辑和字数提示
// - 统一保存校验、禁用态和关闭行为
private struct PetProfileNameEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    private let nameLimit = 24
    private let invalidCharacterSet = CharacterSet(charactersIn: "@<>/")

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        trimmedName.count >= 2
            && trimmedName.count <= nameLimit
            && trimmedName.rangeOfCharacter(from: invalidCharacterSet) == nil
    }

    private var saveColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(isNameValid ? 1 : 0.35)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                    TextField("请输入宠物名字", text: $name)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            saveIfNeeded()
                        }

                    Text("\(name.count)/\(nameLimit)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .monospacedDigit()
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(minHeight: 56)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

                // TODO: 昵称修改额度说明由后端返回，包含截止日期和剩余修改次数。
                Text("请设置 2-24 个字符，不包括 @<>/等无效字符。30 天内可修改 4 次昵称，07.17 前还可修改 4 次。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("编辑名字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onWillDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .accessibilityLabel("关闭")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveIfNeeded()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(saveColor)
                    .disabled(!isNameValid)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .onChange(of: name) { _, newValue in
            if newValue.count > nameLimit {
                name = String(newValue.prefix(nameLimit))
            }
        }
        .accessibilityIdentifier("pet.profileEdit.nameEditor.sheet")
    }

    private func saveIfNeeded() {
        guard isNameValid else { return }
        name = trimmedName
        onWillDismiss()
        onSave()
        dismiss()
    }
}

// PetProfileEditValueText 编辑资料行文本值
// 核心职责：
// - 统一资料行右侧文本样式
// - 处理长文本截断，避免挤压右侧箭头
private struct PetProfileEditValueText: View {
    let value: String

    var body: some View {
        let isPlaceholder = value.isEmpty || value.hasPrefix("选择") || value == "暂未设置" || value == "暂无"
        Text(value)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(isPlaceholder ? MHBTheme.ColorToken.labelTertiary.color : MHBTheme.ColorToken.labelPrimary.color)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// PetProfileEditAvatarImage 宠物头像图片
// 核心职责：
// - 优先展示远端头像
// - 在头像缺失时按物种提供稳定兜底
private struct PetProfileEditAvatarImage: View {
    let avatarURL: String?
    let species: PetProfileEditProfile.Species
    let size: CGFloat

    var body: some View {
        if let avatarURL, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackAvatar
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        Image(systemName: species.systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .frame(width: size, height: size)
            .background(MHBTheme.ColorToken.primaryBackground.color)
            .clipShape(Circle())
    }
}

// PetProfileEditMediaThumbnail 背景媒体缩略图
// 核心职责：
// - 展示当前宠物背景媒体的缩略预览
// - 兼容图片和本地视频 mock 资源
private struct PetProfileEditMediaThumbnail: View {
    let media: PetProfileEditProfile.HeroMedia

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mediaContent

            if case .video = media {
                Image(systemName: "play.fill")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 12, height: 12)
                    .background(Color.black.opacity(0.58))
                    .clipShape(Circle())
                    .padding(2)
            }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private var mediaContent: some View {
        switch media {
        case .image(let assetName):
            Image(assetName)
                .resizable()
                .scaledToFill()
        case .video(let resourceName, let fileExtension, let fallbackImageAssetName):
            if MHBLocalMediaResource.url(resourceName: resourceName, fileExtension: fileExtension) != nil {
                MHBMutedLoopingVideoView(
                    resourceName: resourceName,
                    fileExtension: fileExtension
                )
            } else if let fallbackImageAssetName {
                Image(fallbackImageAssetName)
                    .resizable()
                    .scaledToFill()
            } else {
                MHBTheme.ColorToken.primaryBackground.color
            }
        }
    }
}

// PetProfileEditTagFlow 性格标签展示
// 核心职责：
// - 在资料行内展示宠物性格标签
// - 支持标签数量变化时自动换行
private struct PetProfileEditTagFlow: View {
    let tags: [String]

    var body: some View {
        if tags.isEmpty {
            PetProfileEditValueText(value: "暂未设置")
        } else {
            HStack(spacing: MHBTheme.Spacing.s1) {
                ForEach(tags.prefix(3), id: \.self) { tag in
                    MHBTagView(tag, style: .neutral, size: .small)
                }
            }
        }
    }
}
