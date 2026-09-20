# AirCast — project memory

CAC (Congressional App Challenge) submission. PM2.5 air-quality forecasting
iOS app. Built by following the 14-part guide in
`/Users/femcman/Documents/CAC_2027/AirCast_CAC_Claude_Development_Prompt_Pack/`
(`01_MASTER_CONTEXT.md` ... `14_VISUAL_POLISH_REVIEW_TEMPLATE.md`).

## Status: all 12 build milestones complete (01–12) + Clean Air Defender mini-game

The full milestone sequence (repo audit → scaffold → design system → Home →
Forecast → Why → Prediction Challenge → Model Lab → data/forecast engine →
Profile/Settings/Accessibility → testing/demo mode → final polish &
submission) is done. On top of that, a second work order (
`AirCast_CAC_Clean_Air_Defender_Claude_Code_Work_Order.md`, originally in
`~/Downloads`) added **Clean Air Defender**, a SpriteKit mini-game reachable
from the Challenge tab ("Play Clean Air Defender" button below the
prediction form). Milestones 0–6 of that work order are implemented — see
`AirCast/Features/CleanAirDefender/`. Current build: `BUILD SUCCEEDED`,
45/45 tests passing (was 11; +34 for the game: `CleanAirDefenderGameStateTests`
(15), `GameScenarioMapperTests` (11), `GameProgressServiceTests` (5),
`GameEducationFactsTests` (3)).

The game went through several iterations beyond the base work order, driven
by direct user feedback (not spec — keep this in mind if the work order text
and the actual code disagree on these points, the code is newer/correct):

- **"Persistence vs. removal" framing** — the round explicitly plays out
  AirCast's real forecast mechanism (today's PM2.5 persistence, minus
  wind/rain removal) in the model's own vocabulary, not generic "tap the
  bubbles" copy. See `CleanAirDefenderEntryView`'s "How this connects to
  AirCast" card, the round-opening `GameCallout` (tone `.info`, built in
  `CleanAirDefenderGameView.init` from `scenario.currentPM25`), the HUD's
  "Persistence N%" (= `hazeLevel * 100`, not inverted into a "Clarity"
  score), and `GameScienceRecap.mechanismSummary(for:)` on the result screen.
- **Real 3D skyline as the gameplay backdrop** — `CleanAirDefenderGameView`
  uses `SmogSkylineView(showSkyline: true, showGround: false)`, the same
  buildings shown on Home's hero, not just ambient sky — so clearing haze
  visibly sharpens *the specific skyline the rest of the app already
  established as "AirCast's city."* Severity tracks `gameState.hazeLevel`
  live. Confirmed via UI test that `SmogSkylineView`'s own pan gesture
  recognizer never steals gameplay touches (the `SpriteView` sits on top and
  consumes them first).
- **"Clean Air Blaster" water-shot mechanic** — tapping a cluster no longer
  clears it instantly; `BlasterNode` (a fixed nozzle at scene-bottom) fires
  a fast (`WaterShotNode`, 50–130ms travel) water streak at the target,
  which freezes in place until the shot arrives, then the existing splash/
  score/sound land. Reduce Motion skips the travel animation and resolves
  immediately. Stronger dirty→clean payoff: an ambient `ParticleFieldOverlay`
  grime layer (independent of the tap targets) now tracks `hazeLevel`, the
  flat haze tint's max opacity went 0.35→0.55, and a one-time white "clarity
  flash" + success haptic plays the first time `hazeLevel` drops below 0.15.
- **Procedural sound** — `GameSoundPlayer` synthesizes every SFX (sine-wave
  tones with an attack/decay envelope) at runtime; no bundled audio assets
  (avoids licensing questions for a CAC submission). Toggle on Entry screen,
  `@AppStorage` key `GameSoundPlayer.preferenceKey` (single source of truth
  — don't reintroduce the raw string literal in a new call site).
- **Real forecast/contribution numbers reach `GameScenario`** —
  `forecastPM25`, `currentPM25`, `windContributionPercent`,
  `precipitationContributionPercent` all flow from `GameScenarioMapper`
  straight from `ForecastScenario`/`ExplanationDriver`, nil (never
  fabricated) whenever the underlying data doesn't support them.
- **`GameEducationFacts`** (Services/) surfaces two pieces of real content
  that already existed elsewhere in AirCast but were displayed *nowhere at
  all* before this: `AQICategory.guidance` (the real EPA-style health text —
  shown on both Entry and Result, answering "what does this number mean for
  me," not just "what moves it") and a "did you know" sentence built from
  `BundledResearchData.forecastModel.dataset`'s real fields (day-pair count,
  geography, date range) on the Result screen. Both are read-only reuses of
  existing bundled data, not new claims — see `GameEducationFactsTests`.

See `docs/submission.md` for the final feature list, technical/statistics
explanations, honest limitations, and files judges should notice — both it
and `docs/demo_script.md` were updated in the same pass as the earlier
bullet points (blaster/water-shot mechanic, persistence/removal framing)
but **predate** the `GameEducationFacts` addition directly above — reconcile
before demo narration if that gap matters.

## How to build/test/run

```
xcodegen generate   # regenerates AirCast.xcodeproj from project.yml — run after any file add/move
xcodebuild -project AirCast.xcodeproj -scheme AirCast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project AirCast.xcodeproj -scheme AirCast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
Install/launch on simulator: `xcrun simctl install <device-id> <path-to-AirCast.app>` then
`xcrun simctl launch <device-id> com.aircast.cac.AirCast`.

**Important:** SourceKit "Cannot find X in scope" diagnostics shown after editing a single file in
isolation are unreliable loose-file artifacts — they are NOT a real signal.
Trust only actual `xcodebuild`/`xcodebuild test` output.

## Architecture

- SwiftUI, MVVM, `@Observable`, async/await, iOS 17+ deployment target.
- `AirCastApp.swift` owns the single `DemoAirQualityRepository` (actor). Swapping this for a
  live-data repository behind the same `AirQualityRepository` protocol is the only change needed
  to move off demo data — nothing else in the app should need to know.
- 4 tabs (`AppTab`): Home, Forecast, Challenge, Profile — owned by `AppRootView`/`TabRouter`.
- Real fitted OLS regression (`AirCast/research/fit_forecast_model.py`, run on real Orange County
  EPA/NOAA data) is bundled as `AirCast/Resources/ResearchData/ForecastModel.json` and applied at
  runtime in `DemoAirQualityRepository.regressionPredict`. Never invent stats — every displayed
  number traces back to either this bundled fit or a `DataProvenance`-labeled demo/simulated value.
- 5 curated `DemoScenario` cases in `AppDataMode.swift`, switchable in Settings, each internally
  consistent (timestamps/values/drivers/intervals/categories all agree with each other).
- `LocationExplorerCard.swift` is the single unified map component (Satellite via MapKit
  `.imagery(elevation: .realistic)` + Street View via `MKLookAroundSceneRequest`). Tapping the map
  updates a `@Binding var exploredCoordinate` shared with the parent view, which drives both the
  map pin and the Home hero's PM2.5 visualization — deliberately does NOT auto-switch to Street
  View (user must tap that segment manually). Values away from the real demo station are
  deterministic (hash-based, not random) and labeled "Simulated preview" — never presented as real.
- `SmogSkylineView.swift` (SceneKit) is the animated Home hero background — sky color/fog respond
  to live AQI category/severity.
- `Features/CleanAirDefender/` is the Clean Air Defender mini-game, launched from a button on
  `ChallengeView`. `CleanAirDefenderContainerView` owns the entry → SpriteKit round → result flow;
  `GameScenarioMapper` turns a `ForecastScenario` (built from the same `AirQualityRepository`
  types every other screen uses) into `GameScenario` spawn-rate knobs — a game-representation
  layer only, never fed back into the forecast model. `GameProgressService` (`Repositories/`, not
  under `Features/CleanAirDefender/` — both the game and `ProfileViewModel`'s achievements read it)
  is the app's only on-device persistence (`UserDefaults`, capped at 50 results); everything else
  in AirCast stays in-memory so `resetDemo()` returns to a clean state.

## Known non-issues / things not to "fix" again

- The repo **is** a git repository now (initialized 2026-08-10, `main` branch, private — pushed to
  origin). The project.yml/xcodeproj is regenerated via `xcodegen generate`, so run that after any
  file add/move before building, same as always.
- `AirCastApp.swift`'s repository line must stay `DemoAirQualityRepository()` (default scenario)
  and `TabRouter.swift`'s `selectedTab` must stay `.home` — both get temporarily overridden during
  scenario/tab verification screenshots and must always be reverted afterward.
- A few icon-glyph `.font(.system(size:...))` calls bypass the `ACFont` token set — logged as a
  known, non-blocking style nit in `docs/submission.md`, not worth touching without a reason.
