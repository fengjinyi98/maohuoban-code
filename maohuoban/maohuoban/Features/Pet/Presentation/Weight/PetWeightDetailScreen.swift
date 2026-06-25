import Foundation
import SwiftUI
import MaohuobanDesignSystem

// PetWeightDetailContext 体重详情入口上下文
// 核心职责：
// - 承载体重详情页首屏展示所需的宠物和体重摘要
// - 保留新增体重记录所需的记录入口上下文
struct PetWeightDetailContext: Hashable, Sendable {
    let petID: String
    let petName: String
    let currentWeightText: String
    let weightChangeText: String
    let recordContext: PetRecordEntryContext
}

// PetWeightDetailRoute 体重详情内部路由
// 核心职责：
// - 定义体重详情页内的二级推进目标
private enum PetWeightDetailRoute: Hashable, Identifiable {
    case history

    var id: Self { self }
}

// PetWeightDetailScreen 宠物体重详情页面
// 核心职责：
// - 展示当前体重、趋势图和近期记录
// - 通过底部悬浮 CTA 进入新增体重记录流程
struct PetWeightDetailScreen: View {
    let context: PetWeightDetailContext

    @State private var selectedRange: PetWeightRange = .sixMonths
    @State private var selectedPet: PetRecordSwitchPet?
    @State private var isAddRecordSheetPresented = false
    @State private var pathRoute: PetWeightDetailRoute?

    private let records = PetWeightRecord.mockRecords

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                        PetWeightHeroCard(
                            currentWeightText: context.currentWeightText,
                            changeText: context.weightChangeText
                        )
                        .padding(.top, MHBTheme.Spacing.s4)

                        PetWeightChartCard(
                            selectedRange: $selectedRange,
                            records: records
                        )

                        PetWeightHistorySection(
                            records: Array(records.prefix(6)),
                            onOpenHistory: {
                                pathRoute = .history
                            }
                        )
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                }

                MHBBottomFloatingActionCTA(
                    title: "新增记录",
                    systemImage: "plus",
                    bottomInset: bottomInset,
                    action: {
                        isAddRecordSheetPresented = true
                    }
                )
                .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("体重")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pathRoute) { route in
            switch route {
            case .history:
                PetWeightHistoryScreen(
                    context: context.recordContext,
                    fallbackPetName: currentPetName,
                    records: records
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PetWeightDetailPetSwitcherMenu(
                    selectedItem: currentPetSwitcherItem,
                    items: petSwitcherItems,
                    isDisabled: petSwitcherItems.count <= 1,
                    onSelect: selectPet
                )
            }
        }
        .sheet(isPresented: $isAddRecordSheetPresented) {
            PetWeightRecordSheet(
                petName: currentPetName,
                initialWeightText: context.currentWeightText
            )
        }
        .onAppear {
            selectedPet = selectedPet ?? context.recordContext.selectedSwitchPet
        }
        .accessibilityIdentifier("pet.weightDetail")
    }

    private var currentPetID: String {
        selectedPet?.id ?? context.petID
    }

    private var currentPetName: String {
        selectedPet?.name ?? context.petName
    }

    private var availablePets: [PetRecordSwitchPet] {
        if context.recordContext.availablePets.isEmpty == false {
            return context.recordContext.availablePets
        }

        return context.recordContext.selectedSwitchPet.map { [$0] } ?? []
    }

    private var currentPetSwitcherItem: MHBPetSwitcherItem? {
        petSwitcherItems.first(where: \.isSelected)
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        availablePets.map { pet in
            MHBPetSwitcherItem(weightRecordPet: pet, isSelected: pet.id == currentPetID)
        }
    }

    private func selectPet(_ petID: String) {
        guard let pet = availablePets.first(where: { $0.id == petID }) else { return }
        selectedPet = PetRecordSwitchPet(
            id: pet.id,
            name: pet.name,
            species: pet.species,
            breed: pet.breed,
            avatarURL: pet.avatarURL,
            sex: pet.sex,
            isSelected: true
        )
    }
}

// PetWeightRange 体重趋势周期
// 核心职责：
// - 定义体重趋势图的可选时间范围
// - 为周期切换控件提供稳定展示文案
private enum PetWeightRange: String, CaseIterable, Hashable {
    case week
    case month
    case sixMonths
    case year

    var title: String {
        switch self {
        case .week: "1周"
        case .month: "1个月"
        case .sixMonths: "6个月"
        case .year: "1年"
        }
    }
}

// PetWeightRecord 体重记录展示模型
// 核心职责：
// - 承载体重详情页 mock 记录数据
// - 为趋势图和近期记录列表提供统一输入
struct PetWeightRecord: Identifiable, Hashable {
    let id: String
    let dateText: String
    let monthText: String
    let note: String
    let weight: Double
    let deltaText: String
    let deltaKind: DeltaKind

    enum DeltaKind: Hashable {
        case up
        case down
        case none

        var color: Color {
            switch self {
            case .up:
                MHBTheme.ColorToken.danger.color
            case .down:
                MHBTheme.ColorToken.success.color
            case .none:
                MHBTheme.ColorToken.labelTertiary.color
            }
        }
    }

    static let mockRecords: [PetWeightRecord] = [
        PetWeightRecord(
            id: "weight-2026-06",
            dateText: "6月24日",
            monthText: "6月",
            note: "例行称重",
            weight: 4.20,
            deltaText: "- 0.15 kg",
            deltaKind: .down
        ),
        PetWeightRecord(
            id: "weight-2026-05",
            dateText: "5月20日",
            monthText: "5月",
            note: "驱虫前记录",
            weight: 4.35,
            deltaText: "+ 0.10 kg",
            deltaKind: .up
        ),
        PetWeightRecord(
            id: "weight-2026-04",
            dateText: "4月15日",
            monthText: "4月",
            note: "医院体检",
            weight: 4.25,
            deltaText: "--",
            deltaKind: .none
        ),
        PetWeightRecord(
            id: "weight-2026-03",
            dateText: "3月18日",
            monthText: "3月",
            note: "晨间称重",
            weight: 4.18,
            deltaText: "+ 0.08 kg",
            deltaKind: .up
        ),
        PetWeightRecord(
            id: "weight-2026-02",
            dateText: "2月16日",
            monthText: "2月",
            note: "饮食调整后",
            weight: 4.10,
            deltaText: "+ 0.12 kg",
            deltaKind: .up
        ),
        PetWeightRecord(
            id: "weight-2026-01",
            dateText: "1月12日",
            monthText: "1月",
            note: "月度记录",
            weight: 3.98,
            deltaText: "--",
            deltaKind: .none
        )
    ]
}

// PetWeightHeroCard 当前体重卡片
// 核心职责：
// - 突出展示当前体重数值
// - 展示来自首页 state 的最近变化摘要
private struct PetWeightHeroCard: View {
    let currentWeightText: String
    let changeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("当前记录")
                .font(MHBTheme.Typography.caption.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s1) {
                Text(currentWeightText)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("kg")
                    .font(MHBTheme.Typography.title.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            PetWeightTrendTag(text: normalizedChangeText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var normalizedChangeText: String {
        let trimmedText = changeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? "较上次暂无变化" : trimmedText
    }
}

// PetWeightTrendTag 体重趋势标签
// 核心职责：
// - 以轻量标签展示体重变化
// - 根据文案方向映射趋势颜色
private struct PetWeightTrendTag: View {
    let text: String

    private var isIncrease: Bool {
        text.contains("+") || text.contains("增加") || text.contains("上升")
    }

    private var foregroundColor: Color {
        isIncrease ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.success.color
    }

    var body: some View {
        Label(text, systemImage: isIncrease ? "arrow.up" : "arrow.down")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, MHBTheme.Spacing.s1)
            .background(foregroundColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
    }
}

// PetWeightChartCard 体重趋势图卡片
// 核心职责：
// - 承载周期切换和折线趋势图
// - 将图表和轴标签组合为独立卡片
private struct PetWeightChartCard: View {
    @Binding var selectedRange: PetWeightRange
    let records: [PetWeightRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            PetWeightRangePicker(selectedRange: $selectedRange)

            PetWeightLineChart(records: records)
                .frame(height: 172)

            HStack {
                ForEach(records.reversed()) { record in
                    Text(record.monthText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, MHBTheme.Spacing.s6)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 16, y: 4)
    }
}

// PetWeightRangePicker 周期切换控件
// 核心职责：
// - 展示体重趋势的时间范围
// - 维护轻量选中状态
private struct PetWeightRangePicker: View {
    @Binding var selectedRange: PetWeightRange

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s5) {
            ForEach(PetWeightRange.allCases, id: \.self) { range in
                Button {
                    selectedRange = range
                } label: {
                    VStack(spacing: MHBTheme.Spacing.s1) {
                        Text(range.title)
                            .font(.system(size: 13, weight: selectedRange == range ? .semibold : .regular))
                            .foregroundStyle(
                                selectedRange == range
                                    ? MHBTheme.ColorToken.labelPrimary.color
                                    : MHBTheme.ColorToken.labelSecondary.color
                            )

                        Capsule()
                            .fill(
                                selectedRange == range
                                    ? MHBTheme.ColorToken.labelPrimary.color
                                    : Color.clear
                            )
                            .frame(width: 12, height: 3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, MHBTheme.Spacing.s1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
        }
    }
}

// PetWeightLineChart 体重折线图
// 核心职责：
// - 使用本地路径绘制 mock 体重趋势
// - 展示末次记录数值标签
private struct PetWeightLineChart: View {
    let records: [PetWeightRecord]

    private var orderedRecords: [PetWeightRecord] {
        Array(records.reversed())
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let plotRect = CGRect(
                x: MHBTheme.Spacing.s6,
                y: MHBTheme.Spacing.s3,
                width: max(size.width - MHBTheme.Spacing.s6, 1),
                height: max(size.height - MHBTheme.Spacing.s6, 1)
            )
            let points = chartPoints(in: plotRect)

            ZStack {
                PetWeightGridLines(plotRect: plotRect)

                if points.count > 1 {
                    PetWeightAreaShape(points: points, bottomY: plotRect.maxY)
                        .fill(
                            LinearGradient(
                                colors: [
                                    MHBTheme.ColorToken.primary.color.opacity(0.16),
                                    MHBTheme.ColorToken.primary.color.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    PetWeightLineShape(points: points)
                        .stroke(
                            MHBTheme.ColorToken.primary.color,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                    if let lastPoint = points.last,
                       let lastRecord = orderedRecords.last {
                        Circle()
                            .fill(MHBTheme.ColorToken.cardSolid.color)
                            .overlay {
                                Circle()
                                    .strokeBorder(MHBTheme.ColorToken.primary.color, lineWidth: 2.5)
                            }
                            .frame(width: 9, height: 9)
                            .position(lastPoint)

                        Text(String(format: "%.2fkg", lastRecord.weight))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, MHBTheme.Spacing.s2)
                            .frame(height: 18)
                            .background(MHBTheme.ColorToken.primary.color, in: Capsule())
                            .position(x: min(lastPoint.x - 20, plotRect.maxX - 28), y: max(lastPoint.y - 18, 12))
                    }
                }
            }
        }
    }

    private func chartPoints(in rect: CGRect) -> [CGPoint] {
        let values = orderedRecords.map(\.weight)
        guard let minValue = values.min(),
              let maxValue = values.max(),
              values.count > 1 else {
            return []
        }

        let valueRange = max(maxValue - minValue, 0.1)
        return values.enumerated().map { index, value in
            let xProgress = CGFloat(index) / CGFloat(values.count - 1)
            let yProgress = CGFloat((value - minValue) / valueRange)
            return CGPoint(
                x: rect.minX + rect.width * xProgress,
                y: rect.maxY - rect.height * yProgress
            )
        }
    }
}

// PetWeightGridLines 体重图表网格线
// 核心职责：
// - 绘制纵向刻度和横向参考线
// - 保持图表读数层次克制
private struct PetWeightGridLines: View {
    let plotRect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(gridRows, id: \.label) { row in
                Text(row.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .position(x: 14, y: plotRect.minY + plotRect.height * row.progress)

                Path { path in
                    let y = plotRect.minY + plotRect.height * row.progress
                    path.move(to: CGPoint(x: plotRect.minX, y: y))
                    path.addLine(to: CGPoint(x: plotRect.maxX, y: y))
                }
                .stroke(
                    MHBTheme.ColorToken.separator.color,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }
        }
    }

    private var gridRows: [(label: String, progress: CGFloat)] {
        [
            ("4.50", 0),
            ("4.20", 0.5),
            ("3.90", 1)
        ]
    }
}

// PetWeightLineShape 体重折线路径
// 核心职责：
// - 通过二次曲线连接图表点位
private struct PetWeightLineShape: Shape {
    let points: [CGPoint]

    nonisolated func path(in _: CGRect) -> Path {
        Path { path in
            guard let firstPoint = points.first else { return }
            path.move(to: firstPoint)

            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let control = CGPoint(
                    x: (previous.x + current.x) / 2,
                    y: previous.y
                )
                path.addQuadCurve(to: current, control: control)
            }
        }
    }
}

// PetWeightAreaShape 体重图表面积路径
// 核心职责：
// - 为折线下方绘制渐隐填充区域
private struct PetWeightAreaShape: Shape {
    let points: [CGPoint]
    let bottomY: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        var path = PetWeightLineShape(points: points).path(in: rect)
        if let lastPoint = points.last,
           let firstPoint = points.first {
            path.addLine(to: CGPoint(x: lastPoint.x, y: bottomY))
            path.addLine(to: CGPoint(x: firstPoint.x, y: bottomY))
            path.closeSubpath()
        }
        return path
    }
}

// PetWeightHistorySection 近期体重记录
// 核心职责：
// - 展示最近几条体重记录
// - 提供完整历史入口占位
private struct PetWeightHistorySection: View {
    let records: [PetWeightRecord]
    let onOpenHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("近期记录")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: 0) {
                ForEach(records) { record in
                    PetWeightHistoryRow(record: record)

                    if record.id != records.last?.id {
                        Rectangle()
                            .fill(MHBTheme.ColorToken.separatorSoft.color)
                            .frame(height: 1)
                    }
                }

                Button {
                    onOpenHistory()
                } label: {
                    HStack(spacing: MHBTheme.Spacing.s1) {
                        Text("查看完整历史数据")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MHBTheme.Spacing.s4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 16, y: 4)
        }
    }
}

// PetWeightHistoryRow 体重历史记录行
// 核心职责：
// - 展示单次体重记录日期、备注、数值和变化
private struct PetWeightHistoryRow: View {
    let record: PetWeightRecord

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(record.dateText)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(record.note)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f kg", record.weight))
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(record.deltaText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(record.deltaKind.color)
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}

// PetWeightDetailPetSwitcherMenu 体重详情宠物切换菜单
// 核心职责：
// - 在系统导航栏右侧展示当前宠物胶囊
// - 使用原生 Menu 承载多宠切换动作
private struct PetWeightDetailPetSwitcherMenu: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(items) { item in
                Button {
                    onSelect(item.id)
                } label: {
                    Label(item.name, systemImage: item.isSelected ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            MHBPetSwitcherCapsule(
                item: selectedItem,
                isDisabled: isDisabled
            )
        }
        .disabled(isDisabled)
        .accessibilityIdentifier("pet.weightDetail.petSwitcherButton")
    }
}

private extension MHBPetSwitcherItem {
    init(weightRecordPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名宠物",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(weightRecordSpecies: pet.species),
            sex: MHBPetSwitcherSex(weightRecordSex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(weightRecordSpecies species: PetRecordPetSpecies) {
        switch species {
        case .dog:
            self = .dog
        case .cat:
            self = .cat
        case .other:
            self = .other
        }
    }
}

private extension MHBPetSwitcherSex {
    init(weightRecordSex sex: PetRecordPetSex) {
        switch sex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown:
            self = .unknown
        }
    }
}
