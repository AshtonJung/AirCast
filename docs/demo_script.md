# AirCast — 60–90s Demo Script & Screen-Recording Shot List

This is the CAC (Congressional App Challenge) demo path required by
Milestone 11. It is fully offline (Airplane Mode is safe — AirCast runs on
bundled demo data), repeatable via **Settings → Reset Demo**, and every
screen it visits has already been spot-checked this milestone for crashes,
placeholder copy, and internal data consistency.

## Before you hit record

1. Settings → **Reset Demo** (returns to the "Clean air, improving"
   scenario and clears any submitted prediction — a clean, judge-ready
   starting point).
2. Put the device/simulator in Airplane Mode. AirCast should look and
   behave identically — this is the point: it's a genuine offline demo, not
   a "please stay connected" one.
3. Light mode, standard Dynamic Type, Home tab selected, at rest (no
   in-flight animations) before pressing record.
4. Optional: Settings → Demo scenario lets you pre-stage a different
   scenario (e.g. "Unhealthy episode") for a second take if you want to show
   contrast — but the primary script below uses the default scenario so the
   story is coherent start to finish.

## The 60–90 second path

| # | Time | Shot | What to say / show |
|---|------|------|---------------------|
| 1 | 0:00–0:10 | **Launch impact** | Cold launch AirCast. Let the Home hero's animated sky/skyline render fully (color reflects the current AQI category — green/blue for "Good"). This is the "showcase" first impression. |
| 2 | 0:10–0:25 | **Home interaction** | Tap around the Satellite map in the "Where this data comes from" card. Tap a different point on the map — the PM2.5 number and hero background visibly respond (labeled "Simulated preview" since it's an illustrative, deterministic value, not a real sensor). This demonstrates the map and the hero are actually linked, not decorative. |
| 3 | 0:25–0:40 | **Forecast chart inspection** | Switch to the Forecast tab. Drag a finger across the interactive chart to inspect specific forecast points — callout shows exact value, timestamp, and (for day+1) the real validated 80% interval. Point out day+2/day+3 intentionally show a qualitative confidence label instead of a fabricated numeric interval. |
| 4 | 0:40–0:50 | **Why explanation** | Scroll to or tap into the Why card. Show the driver breakdown (recent persistence / wind / precipitation) with real relative-contribution percentages derived from the fitted model's coefficients — not hand-picked per scenario. |
| 5 | 0:50–1:10 | **Prediction Challenge interaction/reveal** | Switch to the Challenge tab. Drag the slider to set tomorrow's prediction, tap **Lock In Prediction**. Then scroll to the already-resolved historical example lower on the screen and show its reveal: your guess vs. the model's forecast vs. what was actually observed, plus the continuous score. |
| 6 | 1:10–1:35 | **Clean Air Defender** | Still on Challenge, scroll to and tap **Play Clean Air Defender**. Fast cut through: entry screen (shows the "How this connects to AirCast" persistence/removal card) → round-opening "TODAY'S PERSISTENCE" callout → a few seconds firing the Clean Air Blaster at particle clusters (visible water-shot streak, splash, floating score) against the real city skyline → drag through one wind or rain boost (callout names the real driver contribution %, e.g. "wind accounts for about 40% of expected removal") → HUD's "Persistence N%" visibly dropping → cut to the result card (score, "Persistence vs. removal — how AirCast forecasts tomorrow" recap with this round's real numbers, the same forecast figure from step 5) → **Back to Forecast**. This is the "it's not decoration, it's a playable version of the forecast model" beat — keep this segment tight (15–20s of actual gameplay, not a full round) since the mechanic reads within 5 seconds. |
| 7 | 1:35–1:50 | **Model Lab proof of statistical depth** | Profile tab → Statistics / Model Lab. Show the Observed-vs-Predicted diagnostic scatter (drag to inspect any of the 1,052 real held-out test points), and the MAE/RMSE metrics card with the persistence-baseline comparison — proof this isn't a fabricated "it works" claim. |
| 8 | 1:50–1:55 | **Close** | Return to Home (tap the Home tab) to end on the cinematic hero shot. |

Total: ~110–115 seconds at a natural pace with Clean Air Defender included;
trim to fit a stricter time cap by cutting the second map tap in step 2,
shortening the Why dwell time, or cutting step 6 down to just the wind/rain
boost + result-card beat (skip a few of the particle-clearing taps) — the
game segment is designed to compress well since its core "tap clears,
drag-through boosts, sky visibly clears" idea reads in under 20 seconds on
camera. If the format has a hard 60–90s cap, drop step 6 to a single
still-frame cutaway of the result card ("Great run" score + recap text +
forecast figure) rather than showing live gameplay.

## Screen-recording shot list (for editing / B-roll)

- Cold launch → Home hero full render (sky gradient + procedural skyline
  animating in), 3–4s static hold, no narration needed — this is the
  "silent 15-second" showcase moment the guide calls for.
- Map tap → hero/pin value change, captured as a tight crop on just the
  hero number and the map badge so the linkage reads clearly even at small
  export sizes.
- Forecast chart drag-to-inspect, one continuous unbroken drag gesture
  (avoid stop-start scrubbing — it reads better on camera).
- Challenge slider drag + "Lock In Prediction" tap + reveal card, as one
  continuous take.
- Clean Air Defender: entry screen tap-in (hold 1–2s on the "How this
  connects to AirCast" card), 4–6 blaster shots at particle clusters (the
  water-streak + splash reads clearly even in a quick cut), one wind/rain
  boost drag-through with its callout banner, then a hold on the result card
  (score + "persistence vs. removal" recap + forecast figure) — this whole
  cutaway can be its own short take and trimmed in the edit, so don't worry
  about hitting an exact in-camera duration.
- Model Lab diagnostic chart drag-to-inspect, 3–5 points sampled.
- Settings → Reset Demo → confirmation dialog → back to a clean Home, as a
  short closing "and it's fully repeatable" cutaway if the presentation
  format allows a second clip.

## Repeatability note

Every step above was re-verified this milestone directly against
`xcodebuild test` (11/11 passing, including new `resetDemo()` coverage) and
simulator screenshots across 5 demo scenarios (Clean/Improving,
Moderate/Rising, Unhealthy/Low-confidence, Stale/Offline, Challenge-Reveal-
Ready), light and dark appearance, and an accessibility-large Dynamic Type
size — no crashes, no clipped text, no placeholder copy found. Model Lab's
"validated sample metrics" scenario isn't a separate switch: it's the
always-on, real bundled 1,052-point test set, so it's present regardless of
which demo scenario is active.

Clean Air Defender (added after Milestone 12) inherits the same offline
guarantee: if the forecast snapshot it reads from Challenge hasn't loaded
yet or the demo scenario has no data, `GameScenarioMapper` falls back to
`GameScenario.standard` rather than failing to launch, so the round always
plays in Airplane Mode. `xcodebuild test` currently reports 42/42 passing
(the original 11 plus 31 covering the game's scoring/callout-accuracy,
forecast mapping, and local persistence). All Clean Air Defender sound
effects are synthesized procedurally at runtime — there is no bundled audio
asset for the offline guarantee to depend on.
