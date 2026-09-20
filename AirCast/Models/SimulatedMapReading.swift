import Foundation
import CoreLocation

/// A deterministic, clearly-illustrative PM2.5-like value derived from a
/// tapped map coordinate — shared by every screen so a tapped point always
/// produces the *same* number wherever it's shown (map pin, hero card,
/// background haze), never a different random value per view.
///
/// This is never a real measurement. AirCast has one demo station's worth
/// of real data; every other point on the map only ever gets this labeled
/// "simulated" estimate, purely so exploring the map feels reactive.
enum SimulatedMapReading {
    static func pm25(for coordinate: CLLocationCoordinate2D) -> Double {
        let seed = sin(coordinate.latitude * 12.9898 + coordinate.longitude * 78.233) * 43758.5453
        let fractional = seed - seed.rounded(.down)
        return 4 + fractional * 110
    }
}
