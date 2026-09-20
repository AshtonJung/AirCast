# AirCast — project memory

CAC (Congressional App Challenge) submission. PM2.5 air-quality forecasting
iOS app. Built by following the 14-part guide in
`/Users/femcman/Documents/CAC_2027/AirCast_CAC_Claude_Development_Prompt_Pack/`
(`01_MASTER_CONTEXT.md` ... `14_VISUAL_POLISH_REVIEW_TEMPLATE.md`).

## Status: all 12 build milestones complete (01–12)

The full milestone sequence (repo audit → scaffold → design system → Home →
Forecast → Why → Prediction Challenge → Model Lab → data/forecast engine →
Profile/Settings/Accessibility → testing/demo mode → final polish &
submission) is done. Final build: `BUILD SUCCEEDED`, 11/11 tests passing.
See `docs/submission.md` for the final feature list, technical/statistics
explanations, honest limitations, and files judges should notice. See
`docs/demo_script.md` for the 60–90s demo script and shot list.

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

## Known non-issues / things not to "fix" again

- Project is intentionally not a git repository (no `.git` here) — do not initialize one unless
  explicitly asked.
- `AirCastApp.swift`'s repository line must stay `DemoAirQualityRepository()` (default scenario)
  and `TabRouter.swift`'s `selectedTab` must stay `.home` — both get temporarily overridden during
  scenario/tab verification screenshots and must always be reverted afterward.
- A few icon-glyph `.font(.system(size:...))` calls bypass the `ACFont` token set — logged as a
  known, non-blocking style nit in `docs/submission.md`, not worth touching without a reason.
