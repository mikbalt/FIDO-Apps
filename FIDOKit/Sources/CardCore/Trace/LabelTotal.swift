/// The total duration of every `command` or `hostStep` event with one label.
public struct LabelTotal: Sendable, Equatable, Identifiable {
    public var label: String
    public var count: Int
    /// Nanoseconds.
    public var total: Int64

    public init(label: String, count: Int, total: Int64) {
        self.label = label
        self.count = count
        self.total = total
    }

    public var id: String { label }

    /// Totals per label, in order of first appearance.
    static func totals(_ items: [(label: String, duration: Int64)]) -> [LabelTotal] {
        var totals: [LabelTotal] = []
        for item in items {
            if let index = totals.firstIndex(where: { $0.label == item.label }) {
                totals[index].count += 1
                totals[index].total += item.duration
            } else {
                totals.append(LabelTotal(label: item.label, count: 1, total: item.duration))
            }
        }
        return totals
    }
}
