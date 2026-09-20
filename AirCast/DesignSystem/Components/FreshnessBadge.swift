import SwiftUI

/// Shows when a value was last updated and whether it's stale/cached/demo.
/// Every data-bearing screen should surface one of these near its primary
/// value so provenance is never hidden.
struct FreshnessBadge: View {
    let provenance: DataProvenance
    var now: Date = Date()

    private var isStale: Bool { provenance.isStale(asOf: now) }

    private var symbolName: String {
        switch provenance.kind {
        case .observed: return isStale ? "clock.badge.exclamationmark" : "checkmark.circle"
        case .predicted: return "sparkles"
        case .cached: return "arrow.triangle.2.circlepath"
        case .demo: return "wand.and.stars"
        }
    }

    private var text: String {
        // RelativeDateTimeFormatter rounds sub-minute gaps to whole seconds
        // and can flip to future-tense ("in 0 sec") on a near-zero gap purely
        // from rounding noise between when `provenance` and `now` were each
        // constructed. Anything under a minute reads as "Just now" instead —
        // simpler, always correct, and avoids the formatter's edge case.
        let secondsAgo = now.timeIntervalSince(provenance.observedOrGeneratedAt)
        let relative = secondsAgo < 60 ? "just now" : Self.relativeFormatter.localizedString(for: provenance.observedOrGeneratedAt, relativeTo: now)
        switch provenance.kind {
        case .observed: return isStale ? "Stale · updated \(relative)" : "Updated \(relative)"
        case .predicted: return "Forecast · generated \(relative)"
        case .cached: return "Cached · from \(relative)"
        case .demo: return "Demo data · \(relative)"
        }
    }

    private var tint: Color {
        isStale ? ACColor.warning : ACColor.textSecondary
    }

    var body: some View {
        HStack(spacing: ACSpacing.xxs) {
            Image(systemName: symbolName)
            Text(text)
        }
        .font(ACFont.micro())
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

#Preview("FreshnessBadge") {
    VStack(alignment: .leading, spacing: ACSpacing.sm) {
        FreshnessBadge(provenance: DataProvenance(source: "Demo", kind: .observed, observedOrGeneratedAt: Date().addingTimeInterval(-300)))
        FreshnessBadge(provenance: DataProvenance(source: "Demo", kind: .observed, observedOrGeneratedAt: Date().addingTimeInterval(-4 * 3600)))
        FreshnessBadge(provenance: DataProvenance(source: "Demo", kind: .demo, observedOrGeneratedAt: Date()))
    }
    .padding()
    .background(ACColor.background)
}
