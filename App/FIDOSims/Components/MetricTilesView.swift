import FIDOKit
import SwiftUI

/// The session-level timing metrics of a trace.
struct MetricTilesView: View {
    let metrics: TraceMetrics

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            MetricTileView(title: "Session total", value: Self.format(metrics.sessionTotal))
            MetricTileView(title: "Card wait", value: Self.format(metrics.cardWait))
            MetricTileView(title: "APDU total", value: TimingFormat.milliseconds(metrics.apduTotal))
            MetricTileView(title: "Host overhead", value: Self.format(metrics.hostOverhead))
            MetricTileView(title: "Exchanges", value: "\(metrics.exchangeCount)", caption: Self.caption(commands: metrics.commands.count))
        }
    }

    /// Explains the APDU count next to the logical command count shown in Decoded.
    static func caption(commands: Int) -> String {
        "APDUs, \(commands) \(commands == 1 ? "command" : "commands")"
    }

    private static func format(_ nanoseconds: Int64?) -> String {
        nanoseconds.map(TimingFormat.milliseconds) ?? "—"
    }
}
