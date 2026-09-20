import SwiftUI
import MapKit

/// One card, one interactive way to explore where this data comes from.
///
/// - **Tap the map** anywhere → the pin moves there immediately and its
///   badge updates right away. You stay on the Satellite tab — nothing
///   auto-switches on you.
/// - **Tap the Street View segment yourself** → *then* it loads the real,
///   live Apple Look Around panorama for whatever point is currently
///   selected on the map.
///
/// Tapping a new point *does* change the badge's number and color — but
/// AirCast only ever measured PM2.5 at one real demo station, so anywhere
/// else is honestly labeled a **simulated illustrative estimate** (a
/// deterministic, clearly-tagged placeholder), never presented as a real
/// reading. Only the actual station pin says "Live demo station."
struct LocationExplorerCard: View {
    let category: AQICategory
    let pm25: Double
    /// Shared with the parent screen (e.g. Home's hero) so tapping the map
    /// here can drive that screen's visuals too — one source of truth for
    /// "what point are we currently looking at," not a copy trapped inside
    /// this card.
    @Binding var exploredCoordinate: CLLocationCoordinate2D?

    enum Mode: String, CaseIterable, Identifiable {
        case satellite = "Satellite"
        case streetView = "Street View"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .satellite
    @State private var pulse = false
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var lookAroundState: LookAroundLoadState = .loading
    /// The coordinate the Look Around scene currently on screen was fetched
    /// for — lets us tell "still valid" apart from "map moved on, need a refetch."
    @State private var lookAroundCoordinate: CLLocationCoordinate2D?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let stationCoordinate = CLLocationCoordinate2D(latitude: 33.6553, longitude: -118.0006)
    static let stationName = "Huntington Beach, CA"

    private var activeCoordinate: CLLocationCoordinate2D { exploredCoordinate ?? Self.stationCoordinate }
    private var isAtStation: Bool { exploredCoordinate == nil }

    /// The value shown on the badge for whatever point is currently
    /// selected — the real reading at the station, or a clearly-labeled
    /// simulated estimate elsewhere.
    private var displayedPM25: Double {
        isAtStation ? pm25 : SimulatedMapReading.pm25(for: activeCoordinate)
    }
    private var displayedCategory: AQICategory {
        isAtStation ? category : AQICategory.classify(pm25: displayedPM25)
    }

    @State private var cameraPosition = MapCameraPosition.camera(
        MapCamera(centerCoordinate: LocationExplorerCard.stationCoordinate, distance: 1400, heading: 30, pitch: 62)
    )

    var body: some View {
        SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Where this data comes from")
                        .font(ACFont.cardTitle())
                        .foregroundStyle(ACColor.textPrimary)
                    Text(isAtStation
                         ? "Tap the map to explore · switch tabs for street view"
                         : "Simulated point — tap Reset for the real demo station")
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                        .lineLimit(2)
                }
                .padding(ACSpacing.md)
                .padding(.bottom, ACSpacing.xs)

                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, ACSpacing.md)
                .padding(.bottom, ACSpacing.sm)

                ZStack {
                    switch mode {
                    case .satellite:
                        satelliteContent
                    case .streetView:
                        streetViewContent
                    }
                }
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: ACRadius.md, style: .continuous))
                .padding(.horizontal, ACSpacing.md)
                .animation(ACMotion.quickSpring, value: mode)

                HStack(spacing: ACSpacing.xxs) {
                    Image(systemName: mode == .satellite ? "hand.tap" : "arrow.left.and.right")
                    Text(mode == .satellite
                         ? "Tap anywhere to explore · drag to orbit"
                         : "Drag to look around, like Street View")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    if !isAtStation {
                        Button("Reset") { resetToStation() }
                            .font(ACFont.micro())
                            .fontWeight(.semibold)
                            .foregroundStyle(ACColor.accent)
                    }
                }
                .font(ACFont.micro())
                .foregroundStyle(ACColor.textTertiary)
                .padding(ACSpacing.md)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: mode) { _, newMode in
            guard newMode == .streetView else { return }
            refreshLookAroundIfNeeded()
        }
    }

    // MARK: Satellite mode

    private var satelliteContent: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                Annotation(isAtStation ? Self.stationName : "Tapped point", coordinate: activeCoordinate) {
                    pinWithReading
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .gesture(
                SpatialTapGesture().onEnded { value in
                    guard let tapped = proxy.convert(value.location, from: .local) else { return }
                    explore(coordinate: tapped)
                }
            )
        }
    }

    private var pinWithReading: some View {
        VStack(spacing: 4) {
            readingBadge
            ZStack {
                Circle()
                    .fill(displayedCategory.color.opacity(0.35))
                    .frame(width: pulse ? 46 : 22, height: pulse ? 46 : 22)
                    .opacity(pulse ? 0 : 0.8)
                Circle()
                    .fill(displayedCategory.color)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: displayedCategory.color.opacity(0.6), radius: 6)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isAtStation
            ? "Live demo station near \(Self.stationName): \(Int(pm25.rounded())) micrograms per cubic meter, \(category.label)"
            : "Simulated estimate at tapped point: \(Int(displayedPM25.rounded())) micrograms per cubic meter, \(displayedCategory.label). Not a real reading.")
    }

    // MARK: Street View mode

    private var streetViewContent: some View {
        ZStack {
            switch lookAroundState {
            case .loading:
                Rectangle().fill(ACColor.surfaceSecondary)
                ProgressView()
            case .loaded:
                if let lookAroundScene {
                    LookAroundPreview(initialScene: lookAroundScene, allowsNavigation: true, showsRoadLabels: true, badgePosition: .bottomTrailing)
                }
            case .unavailable, .failed:
                Rectangle().fill(ACColor.surfaceSecondary)
                VStack(spacing: ACSpacing.xs) {
                    Image(systemName: "binoculars")
                        .font(.system(size: 26))
                        .foregroundStyle(ACColor.textTertiary)
                    Text(lookAroundState == .unavailable
                         ? "Street-level view isn't available at this exact point."
                         : "Couldn't load street-level view.")
                        .font(ACFont.caption())
                        .foregroundStyle(ACColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ACSpacing.lg)
                    if !isAtStation {
                        Button("Back to station", action: resetToStation)
                            .buttonStyle(.acSecondary)
                            .frame(maxWidth: 180)
                    }
                }
            }

            if lookAroundState == .loaded {
                VStack {
                    HStack {
                        readingBadge
                        Spacer()
                        Label("Live", systemImage: "dot.radiowaves.left.and.right")
                            .font(ACFont.micro())
                            .fontWeight(.semibold)
                            .padding(.horizontal, ACSpacing.xs)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.55)))
                            .foregroundStyle(.white)
                    }
                    .padding(ACSpacing.sm)
                    Spacer()
                }
            }
        }
    }

    /// Real station reading: solid pill, plain number. Simulated point:
    /// tilde-prefixed number, outlined pill, "Simulated" tag — visually
    /// distinct at a glance so the two are never confused.
    private var readingBadge: some View {
        HStack(spacing: 4) {
            Text("\(isAtStation ? "" : "~")\(Int(displayedPM25.rounded())) µg/m³")
            if !isAtStation {
                Text("· Simulated")
                    .fontWeight(.regular)
            }
        }
        .font(ACFont.micro())
        .fontWeight(.bold)
        .padding(.horizontal, ACSpacing.xs)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(.black.opacity(isAtStation ? 0.65 : 0.45))
        )
        .overlay(
            Capsule().strokeBorder(.white.opacity(isAtStation ? 0 : 0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        )
        .foregroundStyle(.white)
    }

    // MARK: Actions

    private func explore(coordinate: CLLocationCoordinate2D) {
        exploredCoordinate = coordinate
        withAnimation {
            cameraPosition = .camera(MapCamera(centerCoordinate: coordinate, distance: 1400, heading: 30, pitch: 62))
        }
        // Deliberately stay on the Satellite tab and don't touch Street
        // View state here — it only refreshes when the user taps that tab.
    }

    private func resetToStation() {
        exploredCoordinate = nil
        withAnimation {
            cameraPosition = .camera(MapCamera(centerCoordinate: Self.stationCoordinate, distance: 1400, heading: 30, pitch: 62))
        }
        if mode == .streetView {
            refreshLookAroundIfNeeded()
        }
    }

    private func refreshLookAroundIfNeeded() {
        if let lookAroundCoordinate, coordinatesMatch(lookAroundCoordinate, activeCoordinate), lookAroundState == .loaded {
            return // already showing the right spot
        }
        let target = activeCoordinate
        lookAroundState = .loading
        Task { await loadLookAroundScene(for: target) }
    }

    private func loadLookAroundScene(for coordinate: CLLocationCoordinate2D) async {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        do {
            if let result = try await request.scene {
                guard coordinatesMatch(coordinate, activeCoordinate) else { return }
                lookAroundScene = result
                lookAroundCoordinate = coordinate
                lookAroundState = .loaded
            } else {
                guard coordinatesMatch(coordinate, activeCoordinate) else { return }
                lookAroundCoordinate = coordinate
                lookAroundState = .unavailable
            }
        } catch {
            guard coordinatesMatch(coordinate, activeCoordinate) else { return }
            lookAroundCoordinate = coordinate
            lookAroundState = .failed
        }
    }

    private func coordinatesMatch(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 0.0001 && abs(a.longitude - b.longitude) < 0.0001
    }
}

enum LookAroundLoadState: Equatable {
    case loading, loaded, unavailable, failed
}

#Preview("LocationExplorerCard") {
    LocationExplorerCard(category: .moderate, pm25: 24, exploredCoordinate: .constant(nil))
        .padding()
        .background(ACColor.background)
}
