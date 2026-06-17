import SwiftUI
import MaohuobanDesignSystem

// PetCreateScreen 创建宠物页面
// 核心职责：
// - 收集普通用户创建宠物所需最小档案
// - 通过 PetWriteStore 调用宠物档案创建接口
struct PetCreateScreen: View {
    let currentUserID: String?
    let onCreated: () -> Void

    @State private var store = PetWriteStore()
    @State private var name = ""
    @State private var breed = ""
    @State private var species = PetSpecies.dog
    @State private var sex = PetSex.unknown
    @State private var birthday = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                PetWriteStatusSection(
                    phase: store.phase,
                    successMessage: store.successMessage,
                    derivativeMessage: nil
                )

                PetCreateIdentityFields(name: $name, breed: $breed)
                PetCreateClassificationFields(
                    species: $species,
                    sex: $sex,
                    birthday: $birthday
                )

                PetWriteSubmitButton(
                    title: "保存宠物",
                    isSubmitting: store.isSubmitting
                ) {
                    Task { await submit() }
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("创建宠物")
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .accessibilityIdentifier("pet.create.screen")
    }

    // submit 提交宠物档案
    // 核心职责：
    // - 将表单状态转换为创建草稿
    // - 成功后通知首页刷新聚合快照
    private func submit() async {
        await store.createPet(
            draft: PetProfileDraft(
                name: name,
                species: species,
                breed: breed,
                sex: sex,
                birthday: PetWriteFormatters.birthdayString(from: birthday)
            ),
            currentUserID: currentUserID
        )
        if case .createdPet = store.phase {
            onCreated()
        }
    }
}

// PetCreateIdentityFields 宠物基础信息表单
// 核心职责：
// - 收集宠物名称和品种
// - 保持文本输入区域独立于提交逻辑
private struct PetCreateIdentityFields: View {
    @Binding var name: String
    @Binding var breed: String

    var body: some View {
        PetWriteFormSection(title: "基础档案") {
            PetWriteTextField(title: "名字", text: $name, prompt: "例如 糯米")
                .accessibilityIdentifier("pet.create.nameInput")
            PetWriteTextField(title: "品种", text: $breed, prompt: "例如 比熊犬")
                .accessibilityIdentifier("pet.create.breedInput")
        }
    }
}

// PetCreateClassificationFields 宠物分类信息表单
// 核心职责：
// - 收集物种、性别和生日
// - 使用稳定枚举值映射后端契约
private struct PetCreateClassificationFields: View {
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
