import SwiftUI

/// The cinematic hero region: a real, explorable 3D skyline — clear and
/// crisp on a good-air day, visibly dissolving into haze on a bad one —
/// alongside the current PM2.5/AQI, status, location, freshness, and trend.
/// The "understand it in 3 seconds, and feel a 'wow' doing it" core of Home.
///
/// When the user taps a different point on the map card below, `exploring`
/// carries that point's simulated value up here — the whole hero (skyline
/// haze, big number, pill) switches into an unmistakable "Simulated
/// preview" look so it's never confused with the real station reading.
struct HeroCard: View {
    let observation: AirQualityObservation
    let trend: PM25Trend
    var exploring: (pm25: Double, category: AQICategory)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var isExploring: Bool { exploring != nil }
    private var displayedPM25: Double { exploring?.pm25 ?? observation.pm25 }
    private var displayedCategory: AQICategory { exploring?.category ?? observation.category }
    private var severity: Double {
        AQICategory.normalizedSeverity(pm25: displayedPM25)
    }

    var body: some View {
        SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .top) {
                    SmogSkylineView(category: displayedCategory, severity: severity, reduceMotion: reduceMotion)
                        .frame(height: 200)
                        .opacity(appeared ? 1 : 0)
                        .animation(ACMotion.standardSpring, value: displayedCategory)

                    // A soft bottom fade gives the banner a premium "photo
                    // card" edge and guarantees the pill/badge above always
                    // read clearly regardless of sky brightness.
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.16)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    .allowsHitTesting(false)

                    HStack {
                        AQIStatusPill(category: displayedCategory)
                        Spacer()
                        if isExploring {
                            simulatedBadge
                        } else {
                            FreshnessBadge(provenance: observation.provenance)
                        }
                    }
                    .padding(ACSpacing.md)
                }
                .accessibilityHidden(true)

                VStack(spacing: ACSpacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: ACSpacing.xs) {
                        Text("\(isExploring ? "~" : "")\(Int(displayedPM25.rounded()))")
                            .font(ACFont.heroValue())
                            .contentTransition(.numericText())
                            .foregroundStyle(ACColor.textPrimary)
                        Text("µg/m³")
                            .font(ACFont.cardTitle())
                            .foregroundStyle(ACColor.textSecondary)
                    }

                    HStack(spacing: ACSpacing.xs) {
                        Image(systemName: isExploring ? "hand.tap" : trend.symbolName)
                            .font(.system(size: 13, weight: .bold))
                        Text(isExploring
                             ? "Simulated preview · tap Reset on the map to return"
                             : "\(trend.label) · PM2.5 · \(observation.locationName)")
                            .font(ACFont.caption())
                    }
                    .foregroundStyle(ACColor.textSecondary)
                    .accessibilityElement(children: .combine)
                }
                .frame(maxWidth: .infinity)
                .padding(ACSpacing.lg)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isExploring
            ? "Simulated preview: \(displayedCategory.label), \(Int(displayedPM25.rounded())) micrograms per cubic meter. Not the real station reading."
            : "Current air quality: \(observation.category.label), \(Int(observation.pm25.rounded())) micrograms per cubic meter, \(trend.label.lowercased())")
        .onAppear {
            withAnimation(reduceMotion ? .easeInOut(duration: ACMotion.quickDuration) : ACMotion.expressiveSpring.delay(0.1)) {
                appeared = true
            }
        }
    }

    private var simulatedBadge: some View {
        Label("Simulated preview", systemImage: "wand.and.stars")
            .font(ACFont.micro())
            .fontWeight(.semibold)
            .padding(.horizontal, ACSpacing.xs)
            .padding(.vertical, 3)
            .background(Capsule().fill(.black.opacity(0.55)))
            .foregroundStyle(.white)
    }
}

#Preview("HeroCard") {
    ZStack {
        AtmosphericBackground(category: SampleData.observation.category)
        HeroCard(observation: SampleData.observation, trend: .improving)
            .padding()
    }
}

#Preview("HeroCard — hazardous") {
    ZStack {
        AtmosphericBackground(category: .hazardous)
        HeroCard(
            observation: AirQualityObservation(timestamp: SampleData.now, pm25: 142, locationName: "Sample City", provenance: SampleData.observation.provenance),
            trend: .worsening
        )
        .padding()
    }
}

#Preview("HeroCard — exploring") {
    ZStack {
        AtmosphericBackground(category: .unhealthy)
        HeroCard(
            observation: SampleData.observation,
            trend: .improving,
            exploring: (pm25: 88, category: .unhealthy)
        )
        .padding()
    }
}
