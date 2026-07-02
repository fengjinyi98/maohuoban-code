import SwiftUI
import MaohuobanDesignSystem

// MerchantLitterParentsSection 窝次父母模块
// 核心职责：
// - 展示父母宠物摘要
// - 明确商家追溯的血缘起点
struct MerchantLitterParentsSection: View {
    let sirePet: MerchantManagedPet?
    let damPet: MerchantManagedPet?

    var body: some View {
        MerchantLitterSectionCard(title: "父母关系") {
            VStack(spacing: MHBTheme.Spacing.s3) {
                MerchantLitterPetRow(roleTitle: "父亲", pet: sirePet)
                MerchantLitterPetRow(roleTitle: "母亲", pet: damPet)
            }
        }
    }
}

// MerchantLitterChildrenSection 同窝幼宠模块
// 核心职责：
// - 展示同窝幼宠列表
// - 呈现每只幼宠当前经营状态
struct MerchantLitterChildrenSection: View {
    let children: [MerchantManagedPet]

    var body: some View {
        MerchantLitterSectionCard(title: "同窝幼宠") {
            if children.isEmpty {
                MerchantLitterEmptyText(text: "暂无同窝幼宠记录")
            } else {
                VStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(children) { pet in
                        MerchantLitterPetRow(roleTitle: pet.managedStatus.displayTitle, pet: pet)
                    }
                }
            }
        }
    }
}

// MerchantLitterEventsSection 窝次近期事件模块
// 核心职责：
// - 展示窝次最近关键事件
// - 让商家记录自然沉淀为买家可见时间线
struct MerchantLitterEventsSection: View {
    let events: [MerchantPetEventRecord]

    var body: some View {
        MerchantLitterSectionCard(title: "近期事件") {
            if events.isEmpty {
                MerchantLitterEmptyText(text: "暂无窝次事件")
            } else {
                VStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(events) { event in
                        MerchantLitterEventRow(event: event)
                    }
                }
            }
        }
    }
}

// MerchantLitterRelationshipsSection 窝次关系边模块
// 核心职责：
// - 展示系统当前已记录的关系边
// - 为后续图谱化血缘树保留清晰入口
struct MerchantLitterRelationshipsSection: View {
    let relationships: [MerchantPetRelationship]

    var body: some View {
        MerchantLitterSectionCard(title: "关系追溯") {
            if relationships.isEmpty {
                MerchantLitterEmptyText(text: "暂无关系记录")
            } else {
                VStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(relationships) { relationship in
                        MerchantLitterRelationshipRow(relationship: relationship)
                    }
                }
            }
        }
    }
}
