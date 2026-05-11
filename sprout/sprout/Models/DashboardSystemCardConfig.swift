import Foundation
import SwiftData

@Model
final class DashboardSystemCardConfig {
    var id: UUID = UUID()
    var kind: String = ""
    var isEnabled: Bool = true
    var widthColumns: Int = 4
    var heightUnits: Int = 2
    var dashboardOrder: Double = -10_000

    init(
        kind: String = "",
        isEnabled: Bool = true,
        widthColumns: Int = 4,
        heightUnits: Int = 2,
        dashboardOrder: Double = -10_000
    ) {
        self.kind = kind
        self.isEnabled = isEnabled
        self.widthColumns = widthColumns
        self.heightUnits = heightUnits
        self.dashboardOrder = dashboardOrder
    }
}

extension DashboardSystemCardConfig {
    static let todayInHistoryKind = "today_in_history"

    var span: ContainerSpan {
        ContainerSpan(widthColumns: widthColumns, heightUnits: heightUnits)
    }

    func setSpan(_ span: ContainerSpan) {
        widthColumns = span.widthColumns
        heightUnits = span.heightUnits
    }
}
