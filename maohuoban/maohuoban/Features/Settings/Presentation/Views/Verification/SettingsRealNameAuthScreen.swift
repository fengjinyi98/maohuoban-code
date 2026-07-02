import SwiftUI
import MaohuobanDesignSystem

// SettingsRealNameAuthScreen 个人实名认证页面
// 核心职责：
// - 提供姓名、证件号和协议勾选表单
// - 在 mock 阶段承接认证提交入口
struct SettingsRealNameAuthScreen: View {
    @State private var realName = ""
    @State private var idNumber = ""
    @State private var isAgreed = false

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsSection {
                    TextField("真实姓名", text: $realName)
                        .textContentType(.name)
                        .padding(MHBTheme.Spacing.s4)
                    SettingsDivider()
                    TextField("证件号码", text: $idNumber)
                        .keyboardType(.numbersAndPunctuation)
                        .padding(MHBTheme.Spacing.s4)
                }

                Toggle("我已阅读并同意实名认证服务协议", isOn: $isAgreed)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Button("开始人脸识别") { }
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MHBTheme.ColorToken.primary.color)
                    .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
                    .disabled(isAgreed == false)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("个人实名认证")
        .navigationBarTitleDisplayMode(.inline)
    }
}
