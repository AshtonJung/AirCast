# AirCast — CAC Submission Package (Milestone 12 + Clean Air Defender)

## Final punch list (as reviewed this milestone)

| Priority | Item | Status |
|---|---|---|
| Blocker | Crashes, dead taps, placeholder copy, force-unwraps | None found — swept the full 65-file source tree; zero `TODO`/`FIXME`/placeholder strings, zero force-unwraps, zero stray `print()` debug statements. |
| Blocker | Reset-demo repeatability | Verified via 3 new automated tests (`DemoAirQualityRepositoryTests`) — scenario + user predictions reliably return to a known state. |
| Blocker | Offline reliability | All 5 demo scenarios re-screenshotted this pass: no crashes, internally consistent values across hero/map/badges in each. |
| High impact | Dead/unused component (`tiltInteractive()` modifier existed but was never applied anywhere) | Fixed — applied to the Achievement badge tiles on Profile, where a Wallet-card-style tilt-on-touch reads as a natural "collectible badge" interaction rather than a gimmick. |
| High impact | Dynamic Type / dark mode spot check before final review | Verified — accessibility-extra-large text reflows cleanly with no clipping; dark mode has correct contrast throughout Home. |
| Optional (not fixed) | A handful of small icon-glyph font sizes (`.font(.system(size:...))`) bypass the `ACFont` token set | Left as-is — these are one-off icon glyph sizings (13–26pt), not body text styles, and touching them risks visual regressions for no judge-visible benefit. Noted for future cleanup, not a submission blocker. |

No large new features were added, per the guide's Milestone 12 scope rule — only the two items above (a test file and applying an already-built, already-tested interaction modifier to static badge tiles).

**Milestone 12 build/test status:** `BUILD SUCCEEDED`, `Executed 11 tests, with 0 failures (0 unexpected)`.

**Current build/test status (with Clean Air Defender added):** `BUILD SUCCEEDED`,
`Executed 42 tests, with 0 failures (0 unexpected)` — the original 11 plus 31 new tests:
`CleanAirDefenderGameStateTests` (15 — scoring, combo, haze, the intro callout, and the
incorrect-hit callout naming the *actual* floored deduction rather than a fixed "-25"),
`GameScenarioMapperTests` (11 — forecast-to-difficulty mapping, clamping, determinism,
missing-data fallbacks, and pass-through of the real forecast/current PM2.5 and driver
contribution percentages), and `GameProgressServiceTests` (5 — local result persistence
round-trip, cap, malformed-data handling).

---

## Final feature list

- **Home** — cinematic animated hero (3D sky/skyline scene via SceneKit, color and fog respond to live AQI category and severity) showing the current PM2.5 reading with full data provenance (source, freshness, demo/real label).
- **Explore map** — Apple MapKit satellite/3D imagery and Apple Look Around (live street-level panoramas), unified in one card with a Satellite/Street View picker. Tapping the map updates a clearly-labeled "Simulated preview" PM2.5 value and visibly drives the Home hero's color — a real, functioning link between exploration and the data visualization, not decoration.
- **Forecast** — 3-day PM2.5 forecast from a real fitted regression model. Day+1 carries a real, validated 80% empirical uncertainty interval; day+2/3 intentionally show a qualitative confidence label instead of a fabricated numeric interval, because they were never separately validated. Interactive Swift Charts with drag-to-inspect.
- **Why** — plain-language explanation of what's driving the forecast (recent persistence, wind, precipitation), with relative-contribution percentages computed directly from the fitted model's coefficient magnitudes — not hand-picked per scenario.
- **Prediction Challenge** — users predict tomorrow's PM2.5 against the model with a continuous (never all-or-nothing) scoring system, plus a resolved historical example built from one real day in the bundled dataset (real inputs, real model forecast, real observed outcome).
- **Model Lab (Statistics)** — the full research case: dataset description, real train/test split methodology, MAE/RMSE vs. a naive persistence baseline, an Observed-vs-Predicted diagnostic scatter and residuals-over-time chart built from all 1,052 real held-out test points (drag-to-inspect), stated model limitations, and a summary of a related peer-reviewed-style Cox proportional-hazards survival study (JEI PM2.5 Episode-Recovery) that motivated the feature choices.
- **Profile** — prediction accuracy trend over time, best score/error, a small transparent achievement set computed from real submitted-prediction history (no arbitrary/inflated badges).
- **Settings** — appearance (light/dark/system), demo scenario picker (5 curated, internally-consistent scenarios), Reset Demo, data sources & acknowledgments, model limitations, privacy statement, about.
- **Runs fully offline** on bundled, deterministic demo data — no accounts, no network dependency, no backend.
- **Clean Air Defender** — an optional 30–45s SpriteKit mini-game reachable from a "Play Clean Air Defender" button on the Challenge tab, built as a *playable version of AirCast's own forecast mechanism* rather than a decorative arcade reskin. The round plays out "today's PM2.5 **persistence** minus **removal** from wind and rain" — AirCast's actual accumulation/removal framework — explicitly, in that vocabulary: the entry screen states the mechanism up front, a round-opening callout names today's real persistence value before a single target spawns, the in-game HUD shows a live "Persistence N%" readout (not an abstract game score), and the result screen's recap states this specific round's real numbers ("you cleared N clusters (persistence ↓) and protected M boosts (removal ↑)"). The player fires a "Clean Air Blaster" — a visible on-screen nozzle that shoots a fast water streak at each tapped PM2.5 cluster (travel time capped under 0.13s so it stays snappy; skipped entirely under Reduce Motion) — and drags through wind/rain boosts to protect them, with an educational callout on both correct and incorrect interactions that names the *real* driver contribution percentage from that day's forecast when available. The whole round plays out against the same 3D city skyline shown on Home's hero (not just ambient sky), visibly clearing as persistence drops, with an added ambient haze layer and a one-time "clarity flash" the first time the air genuinely clears. Round difficulty and every displayed number (forecast PM2.5, current PM2.5, wind/precipitation contribution %) are derived from the same forecast data shown elsewhere in the app via a one-way `ForecastScenario → GameScenario` mapper that never writes back to the statistical model — missing data always omits the claim rather than fabricating one. All sound effects are procedurally synthesized at runtime (no bundled audio assets, avoiding licensing questions), with an on/off toggle. Results persist locally and unlock 3 one-time Profile badges (Particle Defender, Clean Sweep, Forecast Scientist) — the same achievement list `ProfileViewModel` already renders, not a second progress system. Respects Reduce Motion, has VoiceOver labels throughout its SwiftUI chrome, and never blocks on sound or haptics (every cue has a visual equivalent).

---

## 60–90 second demo script

See `docs/demo_script.md` for the full script and screen-recording shot list (unchanged from Milestone 11; re-verified this milestone against the current build). Summary of the path:

launch impact → Home map interaction (tap changes hero + map value) → Forecast chart drag-to-inspect → Why driver breakdown → Prediction Challenge slider + resolved reveal → Model Lab diagnostic chart & metrics → back to Home.

---

## Concise technical explanation

AirCast is a native SwiftUI iOS app (iOS 17+, MVVM, async/await, Swift's `Observation` framework). All data — including the "live" satellite imagery and Look Around panoramas — is either bundled with the app or served by Apple's on-device MapKit frameworks, so the entire demo runs with no network connection and no backend. The regression model that powers the forecast is not computed on-device from scratch each run; it was fit offline in Python (`numpy.linalg.lstsq`, scripts archived in `AirCast/research/`) against real historical Orange County EPA/NOAA data, and only its four fitted coefficients are bundled into the app as JSON and applied via straightforward arithmetic at runtime (`DemoAirQualityRepository.regressionPredict`). This keeps the app fast, fully offline-capable, and auditable — anyone can check the shipped coefficients against the archived fitting script and the shipped 1,052-point test set.

## Concise statistics/research explanation

The forecast model is an ordinary least squares regression predicting next-day mean PM2.5 from today's PM2.5, wind speed, and precipitation, fit on 3,276 day-pairs (2014–2022) and evaluated on a held-out, chronologically later 1,052 day-pairs (2023–2025) — a time-based split specifically chosen so no future information leaks into training. On that untouched test set it achieves a mean absolute error of 2.46 µg/m³, versus 2.65 µg/m³ for a naive "tomorrow equals today" persistence baseline — a real but modest improvement, reported honestly as such rather than oversold. The day-ahead uncertainty band shown in the app is not an assumed-normal interval; it is the empirical 10th–90th percentile of the model's actual residuals on that same held-out test set. A separate, more rigorous piece of research — a Cox proportional-hazards survival analysis of 143 real PM2.5 pollution episodes — is presented distinctly in Model Lab as the study that motivated using wind and precipitation as forecast inputs in the first place; it is never conflated with the regression's own forecast numbers.

## Known limitations (stated honestly)

- The forecast model is a simple 4-parameter linear regression, not the more sophisticated survival model described alongside it — it exists specifically to power a demonstrable next-day forecast, and beats the naive baseline by a modest, not dramatic, margin.
- It is trained on Orange County, CA data only (two monitoring sites) and daily resolution only; it may not generalize to other geographies and does not support true hourly forecasting.
- Day+2 and day+3 forecasts reuse the model's own prior-day prediction as their input (a recursive rollout) and were never separately validated against real outcomes at that horizon — the app is explicit about this by showing a qualitative confidence label instead of a fabricated numeric interval for those days.
- The app currently runs entirely on bundled demo data; connecting a live EPA/NOAA feed is a deliberately separate, not-yet-built next step (the repository layer is already structured behind a protocol specifically to make that swap contained).
- Map-tap PM2.5 values away from the one real demo station are clearly labeled "Simulated preview" (deterministic, not random, but illustrative) — they are a UI/interaction device, not a claim of real sensor coverage at every point on Earth.

## Files/components judges should notice

- `AirCast/AirCast/DesignSystem/Backgrounds/SmogSkylineView.swift` — the SceneKit-driven animated hero background; color/fog respond live to AQI severity.
- `AirCast/AirCast/Features/Forecast/Components/LocationExplorerCard.swift` — the unified satellite/Look Around map card and its link back into the Home hero.
- `AirCast/research/fit_forecast_model.py` + `AirCast/AirCast/Resources/ResearchData/ForecastModel.json` — the real model fitting code and its output, bundled verbatim into the app.
- `AirCast/AirCast/Repositories/DemoAirQualityRepository.swift` — where the real fitted coefficients are applied; the single place a live data source would eventually replace demo generation.
- `AirCast/AirCast/Features/ModelLab/Components/DiagnosticChart.swift` — the 1,052-real-point Observed-vs-Predicted / residuals chart.
- `AirCast/AirCastTests/BundledResearchDataTests.swift` — the automated test that verifies the bundled residuals' statistics actually match the reported MAE, so the "real data" claim is machine-checked, not just asserted.
- `AirCast/docs/demo_script.md` and `AirCast/docs/submission.md` — this package.
- `AirCast/AirCast/Features/CleanAirDefender/SpriteKit/CleanAirDefenderScene.swift` — the SpriteKit
  round: spawning, tap/drag hit-testing, the blaster/water-shot firing sequence, wind/rain effects,
  pooled-node cleanup (no unbounded emitters).
- `AirCast/AirCast/Features/CleanAirDefender/SpriteKit/BlasterNode.swift` and `WaterShotNode.swift`
  — the "Clean Air Blaster" tool and its fast (<0.13s) water-shot projectile, added specifically so
  clearing a cluster reads as aiming and firing a tool rather than an abstract tap-and-vanish.
- `AirCast/AirCast/Features/CleanAirDefender/Services/GameScenarioMapper.swift` — the isolated,
  documented, one-way forecast→game-difficulty conversion (work order's "not a new scientific
  forecast" rule), fully unit-tested (`GameScenarioMapperTests`, 11 tests: clamping, determinism,
  missing-data fallbacks, and pass-through of real forecast/contribution numbers).
- `AirCast/AirCast/Features/CleanAirDefender/Services/GameScienceRecap.swift` — builds the result
  screen's "persistence vs. removal" summary from this specific round's real `GameResult` numbers,
  never a fixed/generic sentence.
- `AirCast/AirCast/Features/CleanAirDefender/Services/GameSoundPlayer.swift` — every sound effect
  is a synthesized tone (sine waves + an attack/decay envelope) rendered at runtime, not a bundled
  audio asset — sidesteps licensing questions for a CAC submission entirely.
