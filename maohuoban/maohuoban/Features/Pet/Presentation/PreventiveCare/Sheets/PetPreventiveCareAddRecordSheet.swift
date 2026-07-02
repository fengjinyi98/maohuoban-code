import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareAddRecordSheet 新增疫苗驱虫记录弹层
// 核心职责：
// - 通过原生 sheet 收集疫苗或驱虫记录的核心字段
// - 在快速 UI 阶段提供可交互表单，保存后关闭并等待后续接入真实写入
struct PetPreventiveCareAddRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    @State private var selectedKind: PetPreventiveCareKind = .vaccine
    @State private var nameText = ""
    @State private var completedAt = Date()
    @State private var reminderEnabled = true
    @State private var reminderAt = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var executionMethod = PetPreventiveCareExecutionMethod.hospital
    @State private var executionName = ""
    @State private var note = ""
    @State private var photoAssetNames: [String] = []

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let bottomInset = proxy.safeAreaInsets.bottom

                ZStack(alignment: .topLeading) {
                    MHBTheme.ColorToken.background.color
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                            PetPreventiveCareTypeSection(selectedKind: $selectedKind)

                            PetPreventiveCareNameSection(
                                selectedKind: selectedKind,
                                nameText: $nameText,
                                isNameFocused: $isNameFocused
                            )

                            PetPreventiveCareDateSection(
                                title: "完成日期",
                                date: $completedAt
                            )

                            PetPreventiveCareExecutionSection(
                                selectedMethod: $executionMethod,
                                executionName: $executionName
                            )

                            PetPreventiveCareReminderSection(
                                isEnabled: $reminderEnabled,
                                reminderAt: $reminderAt
                            )

                            PetPreventiveCareNoteSection(note: $note)

                            PetPreventiveCarePhotoSection(photoAssetNames: $photoAssetNames)
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s5)
                        .padding(.top, topContentPadding)
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    MHBBottomFloatingActionCTA(
                        title: "保存记录",
                        systemImage: "checkmark",
                        bottomInset: bottomInset,
                        action: saveRecord
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                    .zIndex(2)

                    PetPreventiveCareAddRecordTopChrome(
                        onClose: { dismiss() }
                    )
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s4)
                    .zIndex(3)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onChange(of: selectedKind) { _, newKind in
            applyDefaults(for: newKind)
        }
        .accessibilityIdentifier("pet.preventiveCare.addRecordSheet")
    }

    private var topContentPadding: CGFloat {
        MHBTheme.Spacing.s8 + MHBTheme.Spacing.s5
    }

    private func applyDefaults(for kind: PetPreventiveCareKind) {
        switch kind {
        case .vaccine:
            executionMethod = .hospital
            reminderAt = Calendar.current.date(byAdding: .year, value: 1, to: completedAt) ?? reminderAt
        case .deworming:
            executionMethod = .selfCompleted
            reminderAt = Calendar.current.date(byAdding: .month, value: 1, to: completedAt) ?? reminderAt
        case .all:
            break
        }
        executionName = ""
    }

    private func saveRecord() {
        dismiss()
    }
}

// PetPreventiveCareAddRecordTopChrome 新增记录弹层顶部控件
// 核心职责：
// - 在原生 sheet 内固定标题和关闭入口
// - 保持底部 CTA 与喂食 sheet 使用一致的全屏布局模型
private struct PetPreventiveCareAddRecordTopChrome: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text("新增记录")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("关闭")
            }
        }
        .frame(height: 48)
    }
}

// PetPreventiveCareExecutionMethod 疫苗驱虫执行方式
// 核心职责：
// - 表达记录由用户、医院、商家或其他来源完成
// - 控制是否需要补充执行主体名称
enum PetPreventiveCareExecutionMethod: String, CaseIterable, Identifiable {
    case selfCompleted
    case hospital
    case merchant
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selfCompleted: "自己完成"
        case .hospital: "医院完成"
        case .merchant: "商家完成"
        case .other: "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .selfCompleted: "person.fill.checkmark"
        case .hospital: "cross.case.fill"
        case .merchant: "storefront.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var subjectTitle: String {
        switch self {
        case .selfCompleted: "执行说明"
        case .hospital: "医院名称"
        case .merchant: "商家名称"
        case .other: "来源说明"
        }
    }

    var subjectPrompt: String {
        switch self {
        case .selfCompleted: "例如 家里口服"
        case .hospital: "例如 瑞派宠物医院"
        case .merchant: "例如 小鹿猫舍"
        case .other: "例如 原主人提供"
        }
    }

    var needsSubjectInput: Bool {
        self != .selfCompleted
    }
}
