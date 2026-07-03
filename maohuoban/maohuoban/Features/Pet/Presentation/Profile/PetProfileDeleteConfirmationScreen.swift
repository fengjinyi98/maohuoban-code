import SwiftUI
import MaohuobanDesignSystem

// PetProfileDeleteConfirmationScreen 宠物档案删除确认页
// 核心职责：
// - 使用全屏确认流程承载高风险删除操作
// - 要求用户输入指定确认文案后才允许执行删除
struct PetProfileDeleteConfirmationScreen: View {
    @Environment(\.dismiss) private var dismiss
    let petName: String
    let profileCode: String
    let confirmationPhrase: String
    let onDelete: () -> Void

    @State private var confirmationText = ""

    private var normalizedConfirmationText: String {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canDelete: Bool {
        normalizedConfirmationText == confirmationPhrase
    }

    private var deleteButtonColor: Color {
        MHBTheme.ColorToken.danger.color.opacity(canDelete ? 1 : 0.35)
    }

    var body: some View {
        NavigationStack {
            MHBScreenScrollView {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
                    PetProfileDeleteWarningSection(
                        petName: petName,
                        profileCode: profileCode
                    )

                    PetProfileDeleteConfirmationInputSection(
                        confirmationPhrase: confirmationPhrase,
                        confirmationText: $confirmationText
                    )
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, MHBTheme.Spacing.s6)
                .padding(.bottom, MHBTheme.Spacing.s8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("删除档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    guard canDelete else { return }
                    onDelete()
                } label: {
                    Text("永久删除")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(deleteButtonColor)
                        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
                }
                .disabled(!canDelete)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, MHBTheme.Spacing.s3)
                .padding(.bottom, MHBTheme.Spacing.s2)
                .background(.regularMaterial)
            }
        }
        .accessibilityIdentifier("pet.profileDeleteConfirmation.screen")
    }
}

// PetProfileDeleteWarningSection 删除风险说明区
// 核心职责：
// - 明确展示删除对象和不可逆风险
// - 为后续完善删除策略保留产品说明位置
private struct PetProfileDeleteWarningSection: View {
    let petName: String
    let profileCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("删除 \(petName) 的档案")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text("档案号 \(profileCode)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("删除说明")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.danger.color)
                    .padding(.bottom, MHBTheme.Spacing.s1)

                PetProfileDeleteWarningRow(text: "删除后，毛伙伴不会继续保留该宠物的档案数据。")
                PetProfileDeleteWarningRow(text: "该宠物关联的健康记录、日常记录、相册和相关内容也会一并删除。")
                PetProfileDeleteWarningRow(text: "后续会接入更完整的删除保护、备份和申诉流程。")
            }
        }
    }
}

// PetProfileDeleteWarningRow 删除风险说明行
// 核心职责：
// - 展示单条删除影响说明
// - 使用危险色圆点强化高风险语义
private struct PetProfileDeleteWarningRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s2) {
            Circle()
                .fill(MHBTheme.ColorToken.danger.color)
                .frame(width: 5, height: 5)
                .padding(.top, 7)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// PetProfileDeleteConfirmationInputSection 删除确认输入区
// 核心职责：
// - 展示必须输入的确认文案
// - 收集用户确认输入并交给外层控制删除按钮状态
private struct PetProfileDeleteConfirmationInputSection: View {
    let confirmationPhrase: String
    @Binding var confirmationText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("输入确认文案")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("请输入「\(confirmationPhrase)」继续。")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            TextField("请输入确认文案", text: $confirmationText)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(minHeight: 54)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
                .accessibilityIdentifier("pet.profileDeleteConfirmation.input")
        }
    }
}
