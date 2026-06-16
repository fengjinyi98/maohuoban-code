import SwiftUI
import MaohuobanDesignSystem

// PetProfileEditScreen 宠物资料编辑页
// 核心职责：
// - 按 row section 样式展示宠物资料编辑入口
// - 保持当前阶段只承载页面设计和导航入口
struct PetProfileEditScreen: View {
    let context: PetProfileEditContext
    let currentUserID: String?
    let onPetCreated: () -> Void
    @State private var selectedProfileID: String
    @State private var editedNames: [String: String] = [:]
    @State private var editedChipNumbers: [String: String] = [:]
    @State private var editedSexTexts: [String: String] = [:]
    @State private var editedNeuterStatusTexts: [String: String] = [:]
    @State private var editedBirthDates: [String: Date] = [:]
    @State private var editedArrivalDates: [String: Date] = [:]
    @State private var editedWeights: [String: String] = [:]
    @State private var editedPersonalityTags: [String: [String]] = [:]
    @State private var editedNotes: [String: String] = [:]
    @State private var nameEditorProfileID: String?
    @State private var nameEditorDraft = ""
    @State private var isNameEditorPresented = false
    @State private var isNameEditorChevronExpanded = false
    @State private var chipEditorProfileID: String?
    @State private var chipEditorDraft = ""
    @State private var isChipEditorPresented = false
    @State private var isChipEditorChevronExpanded = false
    @State private var isProfileCodeInfoPresented = false
    @State private var sexPickerProfileID: String?
    @State private var isSexPickerPresented = false
    @State private var sexRowFrame = CGRect.zero
    @State private var neuterStatusPickerProfileID: String?
    @State private var isNeuterStatusPickerPresented = false
    @State private var neuterStatusRowFrame = CGRect.zero
    @State private var birthDateEditorProfileID: String?
    @State private var birthDateEditorDraft = Date.now
    @State private var isBirthDateEditorPresented = false
    @State private var isBirthDateEditorChevronExpanded = false
    @State private var arrivalDateEditorProfileID: String?
    @State private var arrivalDateEditorDraft = Date.now
    @State private var isArrivalDateEditorPresented = false
    @State private var isArrivalDateEditorChevronExpanded = false
    @State private var weightEditorProfileID: String?
    @State private var weightEditorDraft = ""
    @State private var isWeightEditorPresented = false
    @State private var isWeightEditorChevronExpanded = false
    @State private var tagsEditorProfileID: String?
    @State private var tagsEditorDraft: [String] = []
    @State private var isTagsEditorPresented = false
    @State private var isTagsEditorChevronExpanded = false
    @State private var noteEditorProfileID: String?
    @State private var noteEditorDraft = ""
    @State private var isNoteEditorPresented = false
    @State private var isNoteEditorChevronExpanded = false
    @State private var isAddPetPresented = false
    @State private var deleteConfirmationProfileID: String?
    @State private var isDeleteConfirmationPresented = false
    @State private var homePreviewSession: PetProfileHomePreviewSession?
    @State private var homePreviewPreparationID: UUID?
    @State private var isHomePreviewPreparing = false
    @State private var homePreviewHeroImageWidth: CGFloat = 393

    init(
        context: PetProfileEditContext,
        currentUserID: String? = nil,
        onPetCreated: @escaping () -> Void = {}
    ) {
        self.context = context
        self.currentUserID = currentUserID
        self.onPetCreated = onPetCreated
        _selectedProfileID = State(initialValue: context.selectedProfile.id)
    }

    private var selectedProfile: PetProfileEditProfile {
        context.profiles.first(where: { $0.id == selectedProfileID }) ?? context.selectedProfile
    }

    private var deleteConfirmationProfile: PetProfileEditProfile {
        guard let deleteConfirmationProfileID,
              let profile = context.profiles.first(where: { $0.id == deleteConfirmationProfileID })
        else {
            return selectedProfile
        }

        return profile
    }

    var body: some View {
        let profile = selectedProfile
        let profileName = displayName(for: profile)
        let profileCode = formattedProfileCode(profile.profileCode)
        let chipNumber = displayChipNumber(for: profile)
        let sexText = displaySexText(for: profile)
        let neuterStatusText = displayNeuterStatusText(for: profile)
        let birthDateText = displayBirthDateText(for: profile)
        let arrivalDateText = displayArrivalDateText(for: profile)
        let weightText = displayWeightText(for: profile)
        let personalityTags = displayPersonalityTags(for: profile)
        let noteText = displayNoteText(for: profile)

        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MHBScreenScrollView {
                    VStack(spacing: MHBTheme.Spacing.s6) {
                        PetProfileEditPetPickerHeader(
                            profiles: context.profiles,
                            selectedProfileID: profile.id,
                            displayName: { displayName(for: $0) },
                            onSelectProfile: { profileID in
                                dismissSelectionMenus()
                                selectedProfileID = profileID
                            },
                            onAddPet: {
                                isAddPetPresented = true
                            }
                        )

                        VStack(spacing: MHBTheme.Spacing.s4) {
                            PetProfileEditSection {
                                PetProfileEditRow(
                                    title: "宠物名字",
                                    isAccessoryExpanded: isNameEditorChevronExpanded && nameEditorProfileID == profile.id,
                                    action: {
                                        dismissSelectionMenus()
                                        nameEditorProfileID = profile.id
                                        nameEditorDraft = profileName
                                        isNameEditorChevronExpanded = true
                                        isNameEditorPresented = true
                                    }
                                ) {
                                    PetProfileEditValueText(value: profileName)
                                }

                                PetProfileEditRow(
                                    title: "宠物档案号",
                                    action: {
                                        dismissSelectionMenus()
                                        isProfileCodeInfoPresented = true
                                    }
                                ) {
                                    PetProfileEditValueText(value: profileCode)
                                }

                                PetProfileEditRow(
                                    title: "芯片号",
                                    isAccessoryExpanded: isChipEditorChevronExpanded && chipEditorProfileID == profile.id,
                                    action: {
                                        dismissSelectionMenus()
                                        chipEditorProfileID = profile.id
                                        chipEditorDraft = chipNumber
                                        isChipEditorChevronExpanded = true
                                        isChipEditorPresented = true
                                    }
                                ) {
                                    PetProfileEditValueText(value: chipNumber.isEmpty ? "未添加" : chipNumber)
                                }

                                PetProfileEditRow(title: "背景", showsSeparator: false) {
                                    PetProfileEditMediaThumbnail(media: profile.heroMedia)
                                }
                            }

                            PetProfileEditSection {
                                PetProfileEditRow(
                                    title: "性别",
                                    isAccessoryExpanded: isSexPickerPresented && sexPickerProfileID == profile.id,
                                    action: {
                                        showSexPicker(for: profile.id)
                                    }
                                ) {
                                    PetProfileEditValueText(value: sexText)
                                }
                                .petProfileEditRowFrame(.sex)

                                PetProfileEditRow(
                                    title: "出生日期",
                                    isAccessoryExpanded: isBirthDateEditorChevronExpanded && birthDateEditorProfileID == profile.id,
                                    action: {
                                        showBirthDateEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditValueText(value: birthDateText)
                                }

                                PetProfileEditRow(
                                    title: "到家时间",
                                    isAccessoryExpanded: isArrivalDateEditorChevronExpanded && arrivalDateEditorProfileID == profile.id,
                                    action: {
                                        showArrivalDateEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditValueText(value: arrivalDateText)
                                }

                                PetProfileEditRow(
                                    title: "体重",
                                    isAccessoryExpanded: isWeightEditorChevronExpanded && weightEditorProfileID == profile.id,
                                    action: {
                                        showWeightEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditValueText(value: weightText)
                                }

                                PetProfileEditRow(
                                    title: "绝育状态",
                                    showsSeparator: false,
                                    isAccessoryExpanded: isNeuterStatusPickerPresented && neuterStatusPickerProfileID == profile.id,
                                    action: {
                                        showNeuterStatusPicker(for: profile.id)
                                    }
                                ) {
                                    PetProfileEditValueText(value: neuterStatusText)
                                }
                                .petProfileEditRowFrame(.neuterStatus)
                            }

                            PetProfileEditSection {
                                PetProfileEditRow(
                                    title: "性格标签",
                                    isAccessoryExpanded: isTagsEditorChevronExpanded && tagsEditorProfileID == profile.id,
                                    action: {
                                        showTagsEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditTagFlow(tags: personalityTags)
                                }

                                PetProfileEditRow(
                                    title: "备注",
                                    showsSeparator: false,
                                    isAccessoryExpanded: isNoteEditorChevronExpanded && noteEditorProfileID == profile.id,
                                    action: {
                                        showNoteEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditValueText(value: noteText)
                                }
                            }

                            PetProfileEditSection {
                                PetProfileEditRow(
                                    title: "删除宠物档案",
                                    showsSeparator: false,
                                    titleColor: MHBTheme.ColorToken.danger.color,
                                    action: {
                                        dismissSelectionMenus()
                                        deleteConfirmationProfileID = profile.id
                                        isDeleteConfirmationPresented = true
                                    }
                                ) {
                                    EmptyView()
                                }
                                .accessibilityIdentifier("pet.profileEdit.deleteEntry")
                            }
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s8)
                }
                .coordinateSpace(name: PetProfileEditCoordinateSpace.name)
                .onPreferenceChange(PetProfileEditRowFramePreferenceKey.self) { frames in
                    sexRowFrame = frames[.sex] ?? .zero
                    neuterStatusRowFrame = frames[.neuterStatus] ?? .zero
                }

                if isSexPickerPresented || isNeuterStatusPickerPresented {
                    MHBOutsideTapDismissLayer(onDismiss: dismissSelectionMenus)
                        .zIndex(1)
                }

                PetProfileEditSelectionMenuOverlay(
                    isPresented: isSexPickerPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: sexRowFrame,
                    selectedValue: sexText,
                    options: ["公", "母"],
                    onSelect: updateSexText
                )
                .zIndex(2)

                PetProfileEditSelectionMenuOverlay(
                    isPresented: isNeuterStatusPickerPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: neuterStatusRowFrame,
                    selectedValue: neuterStatusText,
                    options: ["已绝育", "未绝育"],
                    onSelect: updateNeuterStatusText
                )
                .zIndex(2)
            }
            .onAppear {
                updateHomePreviewHeroImageWidth(proxy.size.width)
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                updateHomePreviewHeroImageWidth(newWidth)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("编辑档案")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isAddPetPresented) {
            PetProfileAddScreen(
                currentUserID: currentUserID,
                onCreated: onPetCreated
            )
        }
        .fullScreenCover(
            isPresented: $isDeleteConfirmationPresented,
            onDismiss: {
                deleteConfirmationProfileID = nil
            }
        ) {
            let deletionProfile = deleteConfirmationProfile
            let deletionName = displayName(for: deletionProfile)

            PetProfileDeleteConfirmationScreen(
                petName: deletionName,
                profileCode: formattedProfileCode(deletionProfile.profileCode),
                confirmationPhrase: deleteConfirmationPhrase(for: deletionName),
                onDelete: {
                    // TODO: 接入后端宠物删除接口后，在这里提交删除请求并刷新宠物档案列表。
                    isDeleteConfirmationPresented = false
                    deleteConfirmationProfileID = nil
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("预览") {
                    showHomePreview(for: profile)
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .disabled(isHomePreviewPreparing)
            }
        }
        .background {
            HomePreviewUIKitPresenter(
                session: homePreviewSession,
                onDidDismiss: {
                    homePreviewPreparationID = nil
                    isHomePreviewPreparing = false
                }
            ) { session in
                HomePreviewAnimatedPresentationContent {
                    PetProfileHomePreviewScreen(
                        context: session.context,
                        initialThemeSnapshot: session.initialThemeSnapshot,
                        topSafeAreaInset: session.topSafeAreaInset,
                        onDismiss: {
                            homePreviewSession = nil
                        }
                    )
                }
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
        .alert(
            "宠物档案号",
            isPresented: $isProfileCodeInfoPresented
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("宠物档案号是毛伙伴为每只宠物生成的平台内唯一身份编码。它不是芯片号，不需要植入芯片，也不可自行修改。当前档案号：\(profileCode)")
        }
        .sheet(
            isPresented: $isChipEditorPresented,
            onDismiss: {
                isChipEditorChevronExpanded = false
                chipEditorProfileID = nil
            }
        ) {
            PetProfileChipEditorSheet(
                chipNumber: $chipEditorDraft,
                existingChipNumber: chipEditorProfileID.flatMap { profileID in
                    context.profiles.first(where: { $0.id == profileID }).map(displayChipNumber)
                } ?? "",
                onWillDismiss: {
                    isChipEditorChevronExpanded = false
                },
                onSave: {
                    guard let profileID = chipEditorProfileID else { return }
                    editedChipNumbers[profileID] = chipEditorDraft
                    isChipEditorChevronExpanded = false
                    isChipEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isBirthDateEditorPresented,
            onDismiss: {
                isBirthDateEditorChevronExpanded = false
                birthDateEditorProfileID = nil
            }
        ) {
            PetProfileDateEditorSheet(
                title: "出生日期",
                date: $birthDateEditorDraft,
                onWillDismiss: {
                    isBirthDateEditorChevronExpanded = false
                },
                onSave: {
                    guard let profileID = birthDateEditorProfileID else { return }
                    editedBirthDates[profileID] = birthDateEditorDraft
                    isBirthDateEditorChevronExpanded = false
                    isBirthDateEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isArrivalDateEditorPresented,
            onDismiss: {
                isArrivalDateEditorChevronExpanded = false
                arrivalDateEditorProfileID = nil
            }
        ) {
            PetProfileDateEditorSheet(
                title: "到家时间",
                date: $arrivalDateEditorDraft,
                onWillDismiss: {
                    isArrivalDateEditorChevronExpanded = false
                },
                onSave: {
                    guard let profileID = arrivalDateEditorProfileID else { return }
                    editedArrivalDates[profileID] = arrivalDateEditorDraft
                    isArrivalDateEditorChevronExpanded = false
                    isArrivalDateEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isWeightEditorPresented,
            onDismiss: {
                isWeightEditorChevronExpanded = false
                weightEditorProfileID = nil
            }
        ) {
            PetProfileWeightEditorSheet(
                weight: $weightEditorDraft,
                onWillDismiss: {
                    isWeightEditorChevronExpanded = false
                },
                onSave: {
                    guard let profileID = weightEditorProfileID else { return }
                    editedWeights[profileID] = weightEditorDraft
                    isWeightEditorChevronExpanded = false
                    isWeightEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isTagsEditorPresented,
            onDismiss: {
                isTagsEditorChevronExpanded = false
                tagsEditorProfileID = nil
            }
        ) {
            PetProfileTagsEditorSheet(
                tags: $tagsEditorDraft,
                suggestions: suggestedPersonalityTags,
                onWillDismiss: {
                    isTagsEditorChevronExpanded = false
                },
                onSave: {
                    guard let profileID = tagsEditorProfileID else { return }
                    editedPersonalityTags[profileID] = tagsEditorDraft
                    isTagsEditorChevronExpanded = false
                    isTagsEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isNoteEditorPresented,
            onDismiss: {
                isNoteEditorChevronExpanded = false
                noteEditorProfileID = nil
            }
        ) {
            PetProfileNoteEditorSheet(
                note: $noteEditorDraft,
                onWillDismiss: {
                    isNoteEditorChevronExpanded = false
                },
                onSave: {
                    guard let profileID = noteEditorProfileID else { return }
                    editedNotes[profileID] = noteEditorDraft
                    isNoteEditorChevronExpanded = false
                    isNoteEditorPresented = false
                }
            )
        }
        .accessibilityIdentifier("pet.profileEdit.screen")
    }

    private func displayName(for profile: PetProfileEditProfile) -> String {
        editedNames[profile.id] ?? profile.name
    }

    private func displayChipNumber(for profile: PetProfileEditProfile) -> String {
        let chipNumber = editedChipNumbers[profile.id] ?? profile.chipNumber
        let trimmedChipNumber = chipNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedChipNumber.isEmpty || trimmedChipNumber == "暂未录入" || trimmedChipNumber == "未添加" {
            return ""
        }

        return trimmedChipNumber
    }

    private func displaySexText(for profile: PetProfileEditProfile) -> String {
        let sexText = editedSexTexts[profile.id] ?? profile.sexText

        return switch sexText {
        case "男", "公": "公"
        case "女", "母": "母"
        default: "未知"
        }
    }

    private func displayNeuterStatusText(for profile: PetProfileEditProfile) -> String {
        let neuterStatusText = editedNeuterStatusTexts[profile.id] ?? profile.neuterStatusText

        return switch neuterStatusText {
        case "已绝育": "已绝育"
        default: "未绝育"
        }
    }

    private func displayBirthDateText(for profile: PetProfileEditProfile) -> String {
        if let date = editedBirthDates[profile.id] {
            return formattedDate(date)
        }

        return normalizedDateText(profile.birthDateText)
    }

    private func displayArrivalDateText(for profile: PetProfileEditProfile) -> String {
        if let date = editedArrivalDates[profile.id] {
            return formattedDate(date)
        }

        return normalizedDateText(profile.arrivalDateText)
    }

    private func displayWeightText(for profile: PetProfileEditProfile) -> String {
        let weightText = editedWeights[profile.id] ?? profile.weightText
        let trimmedWeightText = weightText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedWeightText.isEmpty || trimmedWeightText == "暂未记录" || trimmedWeightText == "暂未设置" {
            return "暂未记录"
        }

        if trimmedWeightText.lowercased().hasSuffix("kg") {
            return trimmedWeightText
        }

        return "\(trimmedWeightText) kg"
    }

    private func displayPersonalityTags(for profile: PetProfileEditProfile) -> [String] {
        editedPersonalityTags[profile.id] ?? profile.personalityTags
    }

    private func displayNoteText(for profile: PetProfileEditProfile) -> String {
        let noteText = editedNotes[profile.id] ?? profile.note
        let trimmedNoteText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedNoteText.isEmpty || trimmedNoteText == "暂未设置" {
            return "暂无"
        }

        return trimmedNoteText
    }

    private func homePreviewContext(for profile: PetProfileEditProfile) -> PetProfileHomePreviewContext {
        PetProfileHomePreviewContext(
            profile: profile,
            name: displayName(for: profile),
            sexText: displaySexText(for: profile),
            birthDateText: displayBirthDateText(for: profile),
            arrivalDateText: displayArrivalDateText(for: profile),
            weightText: displayWeightText(for: profile),
            noteText: displayNoteText(for: profile)
        )
    }

    private func showHomePreview(for profile: PetProfileEditProfile) {
        guard !isHomePreviewPreparing else {
            return
        }

        dismissSelectionMenus()

        let sessionID = UUID()
        let context = homePreviewContext(for: profile)
        let heroImageWidth = max(homePreviewHeroImageWidth, 1)
        let topSafeAreaInset = HomePreviewSafeAreaMetrics.currentWindowTopSafeAreaInset()
        homePreviewPreparationID = sessionID
        isHomePreviewPreparing = true

        Task { @MainActor in
            let themeStore = HomeDashboardThemeStore()
            let themeSize = CGSize(
                width: heroImageWidth,
                height: HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight
            )

            await themeStore.update(
                selectedPet: context.pet,
                heroImageSize: themeSize
            )

            let snapshot = themeStore.snapshot

            guard homePreviewPreparationID == sessionID else {
                return
            }

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                homePreviewSession = PetProfileHomePreviewSession(
                    id: sessionID,
                    context: context,
                    initialThemeSnapshot: snapshot,
                    heroImageWidth: heroImageWidth,
                    topSafeAreaInset: topSafeAreaInset
                )
            }
            isHomePreviewPreparing = false
        }
    }

    private func updateHomePreviewHeroImageWidth(_ width: CGFloat) {
        let normalizedWidth = max(width, 1)
        guard abs(homePreviewHeroImageWidth - normalizedWidth) > 0.5 else { return }

        homePreviewHeroImageWidth = normalizedWidth
    }

    private var suggestedPersonalityTags: [String] {
        ["亲人", "爱撒娇", "安静", "好奇", "活跃", "胆小", "黏人", "独立", "贪吃", "爱玩", "夜间活动多", "怕生"]
    }

    private func showBirthDateEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        birthDateEditorProfileID = profile.id
        birthDateEditorDraft = editedBirthDates[profile.id] ?? date(from: profile.birthDateText) ?? Date.now
        isBirthDateEditorChevronExpanded = true
        isBirthDateEditorPresented = true
    }

    private func showArrivalDateEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        arrivalDateEditorProfileID = profile.id
        arrivalDateEditorDraft = editedArrivalDates[profile.id] ?? date(from: profile.arrivalDateText) ?? Date.now
        isArrivalDateEditorChevronExpanded = true
        isArrivalDateEditorPresented = true
    }

    private func showWeightEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        weightEditorProfileID = profile.id
        weightEditorDraft = draftWeightText(from: editedWeights[profile.id] ?? profile.weightText)
        isWeightEditorChevronExpanded = true
        isWeightEditorPresented = true
    }

    private func showTagsEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        tagsEditorProfileID = profile.id
        tagsEditorDraft = displayPersonalityTags(for: profile)
        isTagsEditorChevronExpanded = true
        isTagsEditorPresented = true
    }

    private func showNoteEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        noteEditorProfileID = profile.id
        let noteText = editedNotes[profile.id] ?? profile.note
        noteEditorDraft = noteText == "暂未设置" ? "" : noteText
        isNoteEditorChevronExpanded = true
        isNoteEditorPresented = true
    }

    private func showSexPicker(for profileID: String) {
        let isOpeningSamePicker = isSexPickerPresented && sexPickerProfileID == profileID
        dismissSelectionMenus()

        if !isOpeningSamePicker {
            sexPickerProfileID = profileID
            isSexPickerPresented = true
        }
    }

    private func showNeuterStatusPicker(for profileID: String) {
        let isOpeningSamePicker = isNeuterStatusPickerPresented && neuterStatusPickerProfileID == profileID
        dismissSelectionMenus()

        if !isOpeningSamePicker {
            neuterStatusPickerProfileID = profileID
            isNeuterStatusPickerPresented = true
        }
    }

    private func dismissSelectionMenus() {
        isSexPickerPresented = false
        sexPickerProfileID = nil
        isNeuterStatusPickerPresented = false
        neuterStatusPickerProfileID = nil
    }

    private func normalizedDateText(_ dateText: String) -> String {
        let trimmedDateText = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDateText.isEmpty ? "暂未设置" : trimmedDateText
    }

    private func date(from dateText: String) -> Date? {
        let components = dateText.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else {
            return nil
        }

        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: .gregorian)
        dateComponents.year = components[0]
        dateComponents.month = components[1]
        dateComponents.day = components[2]

        return dateComponents.date
    }

    private func formattedDate(_ date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return "暂未设置"
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func draftWeightText(from weightText: String) -> String {
        let trimmedWeightText = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedWeightText.isEmpty || trimmedWeightText == "暂未记录" || trimmedWeightText == "暂未设置" {
            return ""
        }

        return trimmedWeightText
            .replacingOccurrences(of: "kg", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateSexText(_ sexText: String) {
        guard let profileID = sexPickerProfileID else { return }
        editedSexTexts[profileID] = sexText
        isSexPickerPresented = false
        sexPickerProfileID = nil
    }

    private func updateNeuterStatusText(_ neuterStatusText: String) {
        guard let profileID = neuterStatusPickerProfileID else { return }
        editedNeuterStatusTexts[profileID] = neuterStatusText
        isNeuterStatusPickerPresented = false
        neuterStatusPickerProfileID = nil
    }

    private func formattedProfileCode(_ profileCode: String) -> String {
        let digits = profileCode.filter { character in
            character.unicodeScalars.count == 1
                && character.unicodeScalars.first.map { (48...57).contains($0.value) } == true
        }

        guard digits.count == 16 else {
            return profileCode
        }

        let first = digits.prefix(3)
        let secondStart = digits.index(digits.startIndex, offsetBy: 3)
        let secondEnd = digits.index(secondStart, offsetBy: 3)
        let thirdEnd = digits.index(secondEnd, offsetBy: 2)
        let fourthEnd = digits.index(thirdEnd, offsetBy: 7)

        return [
            String(first),
            String(digits[secondStart..<secondEnd]),
            String(digits[secondEnd..<thirdEnd]),
            String(digits[thirdEnd..<fourthEnd]),
            String(digits[fourthEnd...])
        ].joined(separator: "-")
    }

    private func deleteConfirmationPhrase(for petName: String) -> String {
        "我确认删除\(petName)"
    }

}

private enum PetProfileEditCoordinateSpace {
    static let name = "PetProfileEditScreen"
}

private enum PetProfileEditRowAnchor: Hashable {
    case sex
    case neuterStatus
}

private struct PetProfileEditRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PetProfileEditRowAnchor: CGRect] = [:]

    static func reduce(
        value: inout [PetProfileEditRowAnchor: CGRect],
        nextValue: () -> [PetProfileEditRowAnchor: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private extension View {
    func petProfileEditRowFrame(_ anchor: PetProfileEditRowAnchor) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PetProfileEditRowFramePreferenceKey.self,
                    value: [anchor: proxy.frame(in: .named(PetProfileEditCoordinateSpace.name))]
                )
            }
        }
    }
}

// PetProfileEditSelectionMenuOverlay 编辑资料锚点选择菜单浮层
// 核心职责：
// - 使用统一锚点浮动面板承载资料字段选择项
// - 根据 row 位置将菜单放置在触发入口附近
private struct PetProfileEditSelectionMenuOverlay: View {
    let isPresented: Bool
    let containerWidth: CGFloat
    let rowFrame: CGRect
    let selectedValue: String
    let options: [String]
    let onSelect: (String) -> Void

    private let menuWidth: CGFloat = 168

    private var offset: CGSize {
        let horizontalMargin = MHBTheme.Spacing.s4
        let x = min(
            max(rowFrame.maxX - menuWidth, horizontalMargin),
            max(horizontalMargin, containerWidth - menuWidth - horizontalMargin)
        )
        let y = rowFrame.maxY + MHBTheme.Spacing.s1

        return CGSize(width: x, height: y)
    }

    var body: some View {
        MHBAnchoredFloatingPanel(
            isPresented: isPresented && rowFrame != .zero,
            offset: offset,
            scaleAnchor: .topTrailing
        ) {
            PetProfileEditSelectionMenu(
                selectedValue: selectedValue,
                options: options,
                onSelect: onSelect
            )
        }
        .animation(.snappy(duration: 0.22), value: isPresented)
    }
}

// PetProfileEditSelectionMenu 编辑资料选择菜单
// 核心职责：
// - 展示字段可选值
// - 使用勾选标识表达当前值
private struct PetProfileEditSelectionMenu: View {
    let selectedValue: String
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    PetProfileEditSelectionMenuRow(
                        title: option,
                        isSelected: option == selectedValue
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MHBTheme.Spacing.s2)
        .frame(width: 168)
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.large))
        .accessibilityElement(children: .contain)
    }
}

// PetProfileEditSelectionMenuRow 编辑资料选择菜单行
// 核心职责：
// - 展示单个选择项标题
// - 为当前选中项展示勾选标识
private struct PetProfileEditSelectionMenuRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Image(systemName: "checkmark")
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color.opacity(isSelected ? 1 : 0))
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
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
    let titleColor: Color
    let isAccessoryExpanded: Bool
    let action: () -> Void
    @ViewBuilder let value: () -> Value

    init(
        title: String,
        showsSeparator: Bool = true,
        titleColor: Color = MHBTheme.ColorToken.labelSecondary.color,
        isAccessoryExpanded: Bool = false,
        action: @escaping () -> Void = {},
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.title = title
        self.showsSeparator = showsSeparator
        self.titleColor = titleColor
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
                        .foregroundStyle(titleColor)

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
struct PetProfileNameEditorSheet: View {
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

// PetProfileChipEditorSheet 宠物芯片号编辑弹层
// 核心职责：
// - 校验 ISO 11784 / ISO 11785 FDX-B 的 15 位纯数字编码
// - 在保存前要求用户二次确认不可修改的芯片号
struct PetProfileChipEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var chipNumber: String
    let existingChipNumber: String
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    @State private var isConfirmingSave = false

    private let chipNumberLength = 15

    private var isExistingChipNumberLocked: Bool {
        !existingChipNumber.isEmpty
    }

    private var trimmedChipNumber: String {
        chipNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isChipNumberValid: Bool {
        trimmedChipNumber.count == chipNumberLength
            && normalizedChipNumber(from: trimmedChipNumber) == trimmedChipNumber
    }

    private var saveColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(isChipNumberValid ? 1 : 0.35)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                if isExistingChipNumberLocked {
                    lockedChipNumberContent
                } else {
                    editableChipNumberContent
                }

                Text("宠物芯片号采用 ISO 11784 / ISO 11785 FDX-B 标准，为 15 位纯数字编码。芯片号添加后不可自行修改，如需变更需通过申诉渠道处理。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(isExistingChipNumberLocked ? "芯片号" : "添加芯片号")
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

                if !isExistingChipNumberLocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("保存") {
                            isConfirmingSave = true
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(saveColor)
                        .disabled(!isChipNumberValid)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .onChange(of: chipNumber) { _, newValue in
            let normalizedDigits = normalizedChipNumber(from: newValue)

            if normalizedDigits != newValue {
                chipNumber = normalizedDigits
            }
        }
        .alert(
            "确认芯片号",
            isPresented: $isConfirmingSave
        ) {
            Button("返回检查", role: .cancel) {}

            Button("确认添加") {
                saveConfirmedChipNumber()
            }
        } message: {
            Text("请确认芯片号 \(trimmedChipNumber) 准确无误。添加后不可自行修改，如需变更需通过申诉渠道处理。")
        }
        .accessibilityIdentifier("pet.profileEdit.chipEditor.sheet")
    }

    private var editableChipNumberContent: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            TextField("请输入 15 位芯片号", text: $chipNumber)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Text("\(chipNumber.count)/\(chipNumberLength)")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .monospacedDigit()
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(minHeight: 56)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }

    private var lockedChipNumberContent: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Text(existingChipNumber)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .monospacedDigit()

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text("已添加")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(minHeight: 56)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }

    private func saveConfirmedChipNumber() {
        guard isChipNumberValid else { return }
        chipNumber = trimmedChipNumber
        onWillDismiss()
        onSave()
        dismiss()
    }

    private func normalizedChipNumber(from value: String) -> String {
        let digits = value.compactMap { character -> Character? in
            guard character.unicodeScalars.count == 1,
                  let scalar = character.unicodeScalars.first,
                  (48...57).contains(scalar.value) else {
                return nil
            }

            return character
        }

        return String(digits.prefix(chipNumberLength))
    }
}

// PetProfileEditValueText 编辑资料行文本值
// 核心职责：
// - 统一资料行右侧文本样式
// - 处理长文本截断，避免挤压右侧箭头
private struct PetProfileEditValueText: View {
    let value: String

    var body: some View {
        let isPlaceholder = value.isEmpty || value.hasPrefix("选择") || value == "暂未设置" || value == "暂无" || value == "未添加"
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
