import SwiftUI
import MaohuobanDesignSystem

// PetTradeImportScreen 交易宠物导入页面
// 核心职责：
// - 收集交易完成后的宠物档案和来源证据
// - 通过 PetWriteStore 创建宠物并同步写入交易事件
struct PetTradeImportScreen: View {
    let currentUserID: String?
    let onImported: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var store = PetWriteStore()
    @State private var name = ""
    @State private var breed = ""
    @State private var species = PetSpecies.cat
    @State private var sex = PetSex.unknown
    @State private var birthday = Date()
    @State private var sellerName = ""
    @State private var tradeReference = ""
    @State private var summary = ""
    @State private var occurredAt = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                PetWriteStatusSection(
                    phase: store.phase,
                    successMessage: store.successMessage
                )

                PetTradeImportPetFields(name: $name, breed: $breed)
                PetTradeImportClassificationFields(
                    species: $species,
                    sex: $sex,
                    birthday: $birthday
                )
                PetTradeImportEvidenceFields(
                    sellerName: $sellerName,
                    tradeReference: $tradeReference,
                    summary: $summary,
                    occurredAt: $occurredAt
                )

                PetWriteSubmitButton(
                    title: "导入宠物档案",
                    isSubmitting: store.isSubmitting
                ) {
                    Task { await submit() }
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("导入交易宠物")
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .accessibilityIdentifier("pet.tradeImport.screen")
    }

    // submit 提交交易宠物导入
    // 核心职责：
    // - 将表单状态转换为交易导入草稿
    // - 成功后刷新首页聚合快照并返回上级页面
    private func submit() async {
        await store.importTradePet(
            draft: TradePetImportDraft(
                name: name,
                species: species,
                breed: breed,
                sex: sex,
                birthday: PetWriteFormatters.birthdayString(from: birthday),
                sellerName: sellerName,
                tradeReference: tradeReference,
                summary: summary,
                occurredAt: PetWriteFormatters.occurredAtString(from: occurredAt)
            ),
            currentUserID: currentUserID
        )
        if case .importedTradePet = store.phase {
            onImported()
            dismiss()
        }
    }
}

// PetTradeImportPetFields 交易导入宠物基础字段
// 核心职责：
// - 收集宠物名称和品种
// - 保持基础档案输入与提交逻辑分离
private struct PetTradeImportPetFields: View {
    @Binding var name: String
    @Binding var breed: String

    var body: some View {
        PetWriteFormSection(title: "基础档案") {
            PetWriteTextField(title: "名字", text: $name, prompt: "例如 奶盖")
                .accessibilityIdentifier("pet.tradeImport.nameInput")
            PetWriteTextField(title: "品种", text: $breed, prompt: "例如 布偶")
                .accessibilityIdentifier("pet.tradeImport.breedInput")
        }
    }
}

// PetTradeImportClassificationFields 交易导入宠物身份字段
// 核心职责：
// - 收集物种、性别和生日
// - 使用稳定枚举值映射后端契约
private struct PetTradeImportClassificationFields: View {
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

// PetTradeImportEvidenceFields 交易导入证据字段
// 核心职责：
// - 收集来源方、交易编号和摘要
// - 将导入时间作为交易事件发生时间
private struct PetTradeImportEvidenceFields: View {
    @Binding var sellerName: String
    @Binding var tradeReference: String
    @Binding var summary: String
    @Binding var occurredAt: Date

    var body: some View {
        PetWriteFormSection(title: "交易来源") {
            PetWriteTextField(title: "来源方", text: $sellerName, prompt: "例如 安心猫舍")
                .accessibilityIdentifier("pet.tradeImport.sellerInput")
            PetWriteTextField(title: "交易编号", text: $tradeReference, prompt: "合同或订单编号")
                .accessibilityIdentifier("pet.tradeImport.referenceInput")
            PetWriteTextField(title: "摘要", text: $summary, prompt: "例如 已完成基础体检")
                .accessibilityIdentifier("pet.tradeImport.summaryInput")

            DatePicker(
                "交易时间",
                selection: $occurredAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
    }
}
