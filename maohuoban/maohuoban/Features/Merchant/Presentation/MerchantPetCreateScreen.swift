import SwiftUI
import MaohuobanDesignSystem

// MerchantPetCreateScreen 商家新增宠物页面
// 核心职责：
// - 收集商家在管宠物的最小档案
// - 通过 MerchantPetCreateStore 调用商家新增宠物接口
struct MerchantPetCreateScreen: View {
    let merchantID: String
    let currentUserID: String?
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var store = MerchantPetCreateStore()
    @State private var name = ""
    @State private var breed = ""
    @State private var species = PetSpecies.cat
    @State private var sex = PetSex.unknown
    @State private var birthday = Date()
    @State private var managedStatus = MerchantPetStatus.needsRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                MerchantPetCreateStatusSection(
                    phase: store.phase,
                    successMessage: store.successMessage
                )

                MerchantPetCreateIdentityFields(name: $name, breed: $breed)
                MerchantPetCreateClassificationFields(
                    species: $species,
                    sex: $sex,
                    birthday: $birthday
                )
                MerchantPetCreateStatusPicker(status: $managedStatus)

                PetWriteSubmitButton(
                    title: "保存商家宠物",
                    isSubmitting: store.isSubmitting
                ) {
                    Task { await submit() }
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("新增店内宠物")
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .accessibilityIdentifier("merchant.petCreate.screen")
    }

    // submit 提交商家宠物档案
    // 核心职责：
    // - 将表单状态转换为商家新增宠物草稿
    // - 成功后刷新首页聚合快照并返回上级页面
    private func submit() async {
        await store.create(
            merchantID: merchantID,
            draft: MerchantPetDraft(
                name: name,
                species: species,
                breed: breed,
                sex: sex,
                birthday: PetWriteFormatters.birthdayString(from: birthday),
                managedStatus: managedStatus
            ),
            currentUserID: currentUserID
        )
        if case .created = store.phase {
            onCreated()
            dismiss()
        }
    }
}

// MerchantPetCreateStatusSection 商家新增宠物状态反馈
// 核心职责：
// - 展示商家宠物提交成功或失败反馈
// - 保持页面提交反馈在表单顶部稳定呈现
private struct MerchantPetCreateStatusSection: View {
    let phase: MerchantPetCreatePhase
    let successMessage: String?

    var body: some View {
        switch phase {
        case .idle, .submitting:
            EmptyView()
        case .created:
            MerchantPetCreateFeedbackCard(
                systemImage: "checkmark.circle.fill",
                title: successMessage ?? "商家宠物已新增",
                tint: MHBTheme.ColorToken.success.color
            )
        case .failed(let message):
            MerchantPetCreateFeedbackCard(
                systemImage: "exclamationmark.triangle.fill",
                title: message,
                tint: MHBTheme.ColorToken.warning.color
            )
        }
    }
}

// MerchantPetCreateFeedbackCard 商家新增宠物反馈卡
// 核心职责：
// - 呈现提交结果图标和文案
// - 复用 DesignSystem token 保持表单视觉一致
private struct MerchantPetCreateFeedbackCard: View {
    let systemImage: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// MerchantPetCreateIdentityFields 商家宠物基础信息表单
// 核心职责：
// - 收集宠物名称和品种
// - 保持文本输入与提交逻辑分离
private struct MerchantPetCreateIdentityFields: View {
    @Binding var name: String
    @Binding var breed: String

    var body: some View {
        PetWriteFormSection(title: "基础档案") {
            PetWriteTextField(title: "名字", text: $name, prompt: "例如 奶糖")
                .accessibilityIdentifier("merchant.petCreate.nameInput")
            PetWriteTextField(title: "品种", text: $breed, prompt: "例如 布偶猫")
                .accessibilityIdentifier("merchant.petCreate.breedInput")
        }
    }
}

// MerchantPetCreateClassificationFields 商家宠物分类信息表单
// 核心职责：
// - 收集物种、性别和生日
// - 使用稳定枚举值映射后端契约
private struct MerchantPetCreateClassificationFields: View {
    @Binding var species: PetSpecies
    @Binding var sex: PetSex
    @Binding var birthday: Date

    var body: some View {
        PetWriteFormSection(title: "身份信息") {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("物种")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                Picker("物种", selection: $species) {
                    ForEach(PetSpecies.allCases) { item in
                        Text(item.displayTitle).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("性别")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                Picker("性别", selection: $sex) {
                    ForEach(PetSex.allCases) { item in
                        Text(item.displayTitle).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            DatePicker(
                "生日",
                selection: $birthday,
                displayedComponents: .date
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
    }
}

// MerchantPetCreateStatusPicker 商家宠物经营状态表单
// 核心职责：
// - 收集宠物初始经营状态
// - 避免商家写入家庭宠物等非经营状态
private struct MerchantPetCreateStatusPicker: View {
    @Binding var status: MerchantPetStatus

    private let statuses: [MerchantPetStatus] = [
        .needsRecord,
        .available,
        .needsExam,
        .retained,
        .inactive,
    ]

    var body: some View {
        PetWriteFormSection(title: "经营状态") {
            Picker("经营状态", selection: $status) {
                ForEach(statuses) { item in
                    Text(item.displayTitle).tag(item)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
