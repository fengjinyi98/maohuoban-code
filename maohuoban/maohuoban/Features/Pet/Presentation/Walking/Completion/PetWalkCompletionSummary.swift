import CoreLocation
import Foundation

// PetWalkCompletionSummary 遛弯结束页摘要
// 核心职责：
// - 冻结结束遛弯时的宠物、轨迹和指标数据
// - 提供结束页所需的稳定展示文案
struct PetWalkCompletionSummary: Identifiable {
    let id = UUID()
    let petName: String?
    let petAvatarURL: URL?
    let petSex: PetRecordPetSex
    let metrics: PetWalkMetrics
    let routePoints: [CLLocationCoordinate2D]

    var displayPetName: String {
        guard let petName, petName.isEmpty == false else {
            return "毛伙伴"
        }

        return petName
    }

    var defaultTitle: String {
        "\(displayPetName)的遛弯"
    }

    var distanceValueText: String {
        String(format: "%.2f", max(0, metrics.distanceKilometers))
    }

    var elapsedText: String {
        let totalSeconds = max(0, Int(metrics.elapsedSeconds.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var caloriesValueText: String {
        "\(metrics.estimatedCalories)"
    }

    var caloriesText: String {
        "\(metrics.estimatedCalories) 千卡"
    }
}
