import Foundation

// TradePetImportResult 交易宠物导入结果
// 核心职责：
// - 承接导入后的宠物档案摘要
// - 承接同步生成的交易事件摘要
struct TradePetImportResult: Decodable, Equatable {
    let pet: PetProfileSummary
    let event: PetEventSummary
}
