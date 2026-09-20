import CoreGraphics

/// PM2.5 particle cluster density levels — the harmful, tap-to-clear target
/// type (work order §9 A). `EnvironmentalBoostKind` below covers the
/// helpful wind/rain targets added in Milestone 3.
enum ParticleDensity: CaseIterable {
    case light
    case medium
    case heavy

    /// Points awarded for clearing one cluster of this density (work order §11).
    var points: Int {
        switch self {
        case .light: return 50
        case .medium: return 75
        case .heavy: return 100
        }
    }

    /// Drawn radius in scene points. Kept well above typical "tiny target"
    /// sizes per the accessibility rule against small tap targets (§16).
    var radius: CGFloat {
        switch self {
        case .light: return 26
        case .medium: return 34
        case .heavy: return 44
        }
    }

    /// Fall-speed multiplier — heavy clusters are "larger, slightly slower" (§9).
    var speedMultiplier: CGFloat {
        switch self {
        case .light: return 1.15
        case .medium: return 1.0
        case .heavy: return 0.8
        }
    }
}

/// Environmental factors that can *help* remove PM2.5 in AirCast's own
/// forecast model — these correspond to real `ExplanationDriver.Kind`
/// cases (`.windSpeed`, `.precipitation`), which is what makes using them
/// here scientifically honest rather than an invented mechanic (work order
/// §2/§5). The two "protect, don't destroy" targets from work order §9 B/C.
///
/// Interaction (see `CleanAirDefenderScene`): drag through a boost to
/// activate/protect it (reward); a quick tap on it — treating it like a
/// harmful target — is the "incorrectly attacks a helpful factor" mistake
/// from work order §4 step 4 (small penalty + educational callout).
enum EnvironmentalBoostKind: CaseIterable {
    case wind
    case rain

    var symbolName: String {
        switch self {
        case .wind: return "wind"
        case .rain: return "cloud.rain.fill"
        }
    }

    /// Shown when the player drags through (activates/protects) this boost.
    /// "Can help" phrasing follows the statistical-honesty rule (§2) — never
    /// a guaranteed cause. Static fallback used only when no real
    /// contribution percentage is available; prefer
    /// `activationCallout(contributionPercent:)` at actual gameplay call
    /// sites.
    var activationCallout: GameCallout {
        activationCallout(contributionPercent: nil)
    }

    /// Same callout, optionally naming the driver's *real* relative
    /// contribution to removal in the round's actual forecast (from
    /// `GameScenario.windContributionPercent`/`precipitationContributionPercent`,
    /// computed by `GameScenarioMapper` straight from `ExplanationDriver` —
    /// never a second, invented number). This is what turns "wind can help"
    /// from a generic educational line into today's specific figure, shown
    /// at the exact moment the player earns it, not just on the result
    /// screen. Omitted (falls back to the generic line) whenever that data
    /// isn't available — the honesty rule is to never fabricate, not to
    /// always show a number.
    func activationCallout(contributionPercent: Int?) -> GameCallout {
        let suffix = contributionPercent.map { " In tomorrow's forecast, \(name) accounts for about \($0)% of expected removal." } ?? ""
        switch self {
        case .wind:
            return GameCallout(title: "WIND BOOST", message: "Dispersion increased — wind can help spread particles out.\(suffix)", tone: .positive)
        case .rain:
            return GameCallout(title: "RAIN BOOST", message: "Wet removal activated — rain can help remove airborne particles.\(suffix)", tone: .positive)
        }
    }

    private var name: String {
        switch self {
        case .wind: return "wind"
        case .rain: return "precipitation"
        }
    }

    /// Shown when the player taps this boost like a threat instead of
    /// dragging through it. `deducted` is the *actual* amount the score
    /// just dropped by (`CleanAirDefenderGameState.registerIncorrectHit`
    /// floors at zero, so a low-score player loses less than the nominal
    /// 25) — the title always matches what really happened rather than a
    /// fixed "-25" that could overstate the real penalty.
    func incorrectHitCallout(deducted: Int) -> GameCallout {
        switch self {
        case .wind:
            return GameCallout(title: "-\(deducted)", message: "Wind can help disperse particles — drag through it instead of tapping.", tone: .negative)
        case .rain:
            return GameCallout(title: "-\(deducted)", message: "Rain can help remove airborne particles — drag through it instead of tapping.", tone: .negative)
        }
    }
}

/// A short educational pop-up shown after a boost interaction (work order
/// §4 step 4, §19). Icon + title + text carry positive/negative meaning
/// together in `GameCalloutBannerView` — never color alone (§16).
struct GameCallout: Equatable {
    enum Tone {
        case positive
        case negative
        /// The round-opening mechanism framing (see
        /// `CleanAirDefenderGameState`'s `introCallout`) — neither a reward
        /// nor a mistake, just naming what the round represents.
        case info
    }

    let title: String
    let message: String
    let tone: Tone
}
