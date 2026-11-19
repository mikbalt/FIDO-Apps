import FIDOKit
import SwiftUI

/// The physical exchanges of a trace, in order. Meant to be placed inside a `List` section.
struct TraceListView: View {
    let exchanges: [ExchangeEvent]
    let hidesSensitive: Bool

    var body: some View {
        ForEach(exchanges) { exchange in
            ExchangeRowView(exchange: exchange, hidesSensitive: hidesSensitive)
        }
    }
}
