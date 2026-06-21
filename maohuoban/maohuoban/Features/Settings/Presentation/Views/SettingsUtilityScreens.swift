import SwiftUI
import MaohuobanDesignSystem

// SettingsDarkModeScreen 深色模式设置页面
// 核心职责：
// - 提供深色模式和跟随系统开关
// - 在 mock 阶段将选择保存在页面本地状态
struct SettingsDarkModeScreen: View {
    @State private var isDarkMode = false
    @State private var followsSystem = true

    var body: some View {
        MHBScreenScrollView {
            SettingsSection {
                SettingsToggleRow(title: "深色模式", isOn: $isDarkMode)
                SettingsDivider()
                SettingsToggleRow(title: "跟随系统设置", subtitle: "开启后根据系统设置同步切换深/浅模式", isOn: $followsSystem)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("深色模式")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// SettingsStorageSpaceScreen 存储空间页面
// 核心职责：
// - 展示设备和 App 沙盒存储占用
// - 提供清理缓存的 mock 可执行入口
struct SettingsStorageSpaceScreen: View {
    @State private var snapshot: SettingsStorageCalculator.StorageSnapshot?
    @State private var isClearing = false

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsStorageOverviewCard(snapshot: snapshot)

                SettingsSection {
                    SettingsRow(title: "缓存", value: snapshot?.appCaches.settingsStorageFormatted ?? "计算中...", showChevron: false)
                    SettingsDivider()
                    SettingsRow(title: "文稿与数据", value: snapshot?.appDocuments.settingsStorageFormatted ?? "计算中...", showChevron: false)
                    SettingsDivider()
                    SettingsRow(title: "临时文件", value: snapshot?.appTemporary.settingsStorageFormatted ?? "计算中...", showChevron: false)
                }

                Button(action: clearCaches) {
                    Text(isClearing ? "清理中..." : "清理缓存")
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(MHBTheme.ColorToken.primary.color)
                        .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
                }
                .disabled(isClearing)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("存储空间")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            snapshot = await SettingsStorageCalculator.calculate()
        }
    }

    private func clearCaches() {
        guard isClearing == false else { return }
        isClearing = true
        Task {
            snapshot = await SettingsStorageCalculator.clearCaches()
            isClearing = false
        }
    }
}

// SettingsDeviceManagementScreen 登录设备管理页面
// 核心职责：
// - 展示当前账号已登录设备列表
// - 将设备详情点击交给 Profile 路由推进
struct SettingsDeviceManagementScreen: View {
    let store: SettingsDeviceSessionStore
    let onDeviceDetail: (String) -> Void

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                if store.isLoadingDevices {
                    ProgressView("加载设备中...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, MHBTheme.Spacing.s8)
                } else if store.devices.isEmpty {
                    ContentUnavailableView("暂无登录设备", systemImage: "iphone")
                } else {
                    SettingsSection {
                        ForEach(Array(store.devices.enumerated()), id: \.element.deviceID) { index, device in
                            SettingsDeviceRow(device: device) {
                                onDeviceDetail(device.deviceID)
                            }
                            if index < store.devices.count - 1 {
                                SettingsDivider()
                            }
                        }
                    }
                }

                if let error = store.lastErrorMessage {
                    Text(error)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.danger.color)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("登录设备管理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadDevices()
        }
    }
}

// SettingsDeviceDetailScreen 设备详情页面
// 核心职责：
// - 展示单个登录设备详细信息
// - 提供移除非当前设备的操作入口
struct SettingsDeviceDetailScreen: View {
    let deviceID: String
    let store: SettingsDeviceSessionStore

    private var details: SettingsDeviceSessionDetails? {
        store.deviceDetails[deviceID]
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                if store.loadingDetailDeviceID == deviceID {
                    ProgressView("加载设备详情...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, MHBTheme.Spacing.s8)
                } else if let details {
                    SettingsSection {
                        SettingsRow(title: "设备名称", value: details.summary.deviceName, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "设备型号", value: details.summary.deviceModel, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "系统版本", value: details.osVersion, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "App 版本", value: details.appVersion, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "登录地点", value: details.summary.locationText, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "首次登录", value: details.firstLoginText, showChevron: false)
                        SettingsDivider()
                        SettingsRow(title: "最近活跃", value: details.summary.lastActiveText, showChevron: false)
                    }

                    if details.summary.isCurrentDevice == false {
                        Button(role: .destructive, action: removeDevice) {
                            Text(store.removingDeviceID == deviceID ? "移除中..." : "移除此设备")
                                .font(MHBTheme.Typography.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(MHBTheme.ColorToken.danger.color)
                                .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
                        }
                    }
                } else {
                    ContentUnavailableView("设备详情不可用", systemImage: "iphone.slash")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("设备详情")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: deviceID) {
            await store.loadDetails(deviceID: deviceID)
        }
    }

    private func removeDevice() {
        Task {
            await store.removeDevice(deviceID: deviceID)
        }
    }
}

// SettingsSetPasswordScreen 设置密码页面
// 核心职责：
// - 根据密码状态展示首次设置、旧密码修改和短信重置表单
// - 通过 SettingsPasswordStore 管理 mock 提交状态
struct SettingsSetPasswordScreen: View {
    @State private var store: SettingsPasswordStore
    @State private var isCurrentPasswordVisible = false
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false

    init(store: SettingsPasswordStore) {
        self._store = State(initialValue: store)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                if store.showsModeTabs {
                    Picker("设置密码模式", selection: $store.selectedMode) {
                        ForEach([SettingsPasswordMode.currentPassword, .smsCode]) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                SettingsPasswordInputCard(
                    store: store,
                    isCurrentPasswordVisible: $isCurrentPasswordVisible,
                    isNewPasswordVisible: $isNewPasswordVisible,
                    isConfirmPasswordVisible: $isConfirmPasswordVisible
                )

                if let error = store.errorMessage {
                    Text(error)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.danger.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    Text(store.isSubmitting ? "提交中..." : "完成")
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(MHBTheme.ColorToken.primary.color)
                        .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
                }
                .disabled(store.isSubmitting)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("设置密码")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        Task {
            await store.submit()
        }
    }
}

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

// SettingsOfficialVerificationScreen 官方认证页面
// 核心职责：
// - 展示个人职业、机构和企业认证入口
// - 保持官方认证页面的分流布局
struct SettingsOfficialVerificationScreen: View {
    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsVerificationCard(title: "个人职业认证", subtitle: "医生、训练师、救助人等职业资质认证", systemImage: "person.badge.shield.checkmark")
                SettingsVerificationCard(title: "机构认证", subtitle: "宠物医院、救助站、门店等机构主体认证", systemImage: "building.2")
                SettingsVerificationCard(title: "企业认证", subtitle: "品牌、供应链和服务商企业认证", systemImage: "briefcase")
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("官方认证")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// SettingsAddressListScreen 收货地址页面
// 核心职责：
// - 展示 mock 地址列表和默认地址
// - 提供添加与编辑地址入口占位
struct SettingsAddressListScreen: View {
    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsSection {
                    SettingsRow(title: "阿毛", value: "155****4195", subtitle: "上海市 浦东新区 世纪大道 100 号", showChevron: true)
                    SettingsDivider()
                    SettingsRow(title: "公司地址", value: "默认", subtitle: "杭州市 西湖区 文三路 88 号", showChevron: true)
                }

                Button("新增收货地址") { }
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MHBTheme.ColorToken.primary.color)
                    .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("收货地址")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// SettingsAccountManagementScreen 账号管理页面
// 核心职责：
// - 展示当前账号和可切换账号列表
// - 在后端未接入时提供添加账号与移除账号占位入口
struct SettingsAccountManagementScreen: View {
    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsSection {
                    SettingsRow(
                        title: SettingsMockData.username,
                        value: "当前账号",
                        subtitle: "+86 \(SettingsMockData.phoneMasked)",
                        showChevron: false
                    )
                    SettingsDivider()
                    SettingsRow(
                        title: "家人账号",
                        value: "可切换",
                        subtitle: "+86 188****0291",
                        showChevron: false
                    )
                }

                SettingsSection {
                    SettingsRow(title: "添加或注册新账号", showChevron: false, alignment: .center)
                    SettingsDivider()
                    SettingsRow(title: "管理已保存账号", showChevron: false, alignment: .center)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("切换账号")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsStorageOverviewCard: View {
    let snapshot: SettingsStorageCalculator.StorageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("毛伙伴占用")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text(snapshot?.appTotal.settingsStorageFormatted ?? "计算中...")
                .font(MHBTheme.Typography.largeTitle)
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
            Text("约占设备容量 \(snapshot?.appPercentageText ?? "--")")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s5)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(.rect(cornerRadius: MHBTheme.Radius.extraLarge))
    }
}

private struct SettingsDeviceRow: View {
    let device: SettingsDeviceSessionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: device.deviceModel.lowercased().contains("ipad") ? "ipad" : "iphone")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        Text(device.deviceName)
                            .font(MHBTheme.Typography.body)
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        if device.isCurrentDevice {
                            Text("当前设备")
                                .font(MHBTheme.Typography.section)
                                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        }
                    }
                    Text("\(device.locationText) · \(device.lastActiveText)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .padding(MHBTheme.Spacing.s4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsPasswordInputCard: View {
    @Bindable var store: SettingsPasswordStore
    @Binding var isCurrentPasswordVisible: Bool
    @Binding var isNewPasswordVisible: Bool
    @Binding var isConfirmPasswordVisible: Bool

    var body: some View {
        SettingsSection {
            if store.selectedMode == .currentPassword {
                passwordField("当前密码", text: $store.currentPassword, isVisible: $isCurrentPasswordVisible)
                SettingsDivider()
            }
            if store.selectedMode == .smsCode {
                HStack {
                    TextField("短信验证码", text: $store.smsCode)
                        .keyboardType(.numberPad)
                    Button(store.sendCodeButtonTitle) {
                        store.sendResetCode()
                    }
                    .disabled(store.isSendCodeDisabled)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
                .padding(MHBTheme.Spacing.s4)
                SettingsDivider()
            }
            passwordField("新密码", text: $store.newPassword, isVisible: $isNewPasswordVisible)
            SettingsDivider()
            passwordField("确认新密码", text: $store.confirmPassword, isVisible: $isConfirmPasswordVisible)
        }
    }

    private func passwordField(
        _ placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack {
            if isVisible.wrappedValue {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
            }
            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(MHBTheme.Spacing.s4)
    }
}

private struct SettingsVerificationCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            Spacer()
        }
        .padding(MHBTheme.Spacing.s5)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(.rect(cornerRadius: MHBTheme.Radius.extraLarge))
    }
}
