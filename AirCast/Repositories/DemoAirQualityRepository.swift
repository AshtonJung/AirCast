import Foundation

/// Deterministic, bundled data source. This is what powers previews, the
/// guaranteed-offline CAC demo, and (for now, until the Data & Forecast
/// Engine milestone lands live integration) the whole app.
///
/// The forecast math is **not** arbitrary: it applies the real regression
/// coefficients fitted in `fit_forecast_model.py` against the cleaned Orange
/// County PM2.5 + weather dataset (see `Resources/ResearchData/ForecastModel.json`
/// and `BundledResearchData`). Only the *current inputs* fed into that real
/// model (today's PM2.5/wind/precip for each interactive scenario) are
/// illustrative — every displayed number still carries a `DataProvenance`
/// labeled `.demo`, so the UI never pretends this is a live measurement.
actor DemoAirQualityRepository: AirQualityRepository {
    private var scenario: DemoScenario
    private var storedChallenges: [PredictionChallenge]

    init(scenario: DemoScenario = .cleanAirImproving) {
        self.scenario = scenario
        self.storedChallenges = []
    }

    func setScenario(_ scenario: DemoScenario) {
        self.scenario = scenario
    }

    var currentScenario: DemoScenario { scenario }

    /// Returns the app to a known, repeatable state for judging: default
    /// scenario, and every locally-stored prediction cleared so
    /// `seedChallenges()` reseeds fresh (the one real historical example)
    /// on next access. Nothing here touches bundled research data — that's
    /// fixed, not user state.
    func resetDemo() {
        scenario = .cleanAirImproving
        storedChallenges = []
    }

    // MARK: AirQualityRepository

    func recentObservations(limit: Int) async throws -> [AirQualityObservation] {
        Array(makeObservations().prefix(limit))
    }

    func latestObservation() async throws -> AirQualityObservation {
        guard let latest = makeObservations().first else {
            throw AirQualityRepositoryError.noData
        }
        return latest
    }

    func forecast() async throws -> PM25Forecast {
        makeForecast()
    }

    func modelCard() async throws -> ModelCard {
        ResearchModelCard.card
    }

    func predictionChallenges() async throws -> [PredictionChallenge] {
        if storedChallenges.isEmpty {
            storedChallenges = seedChallenges()
        }
        return storedChallenges
    }

    func submitPrediction(pm25: Double, for date: Date) async throws -> PredictionChallenge {
        let calendar = Calendar.current
        if storedChallenges.contains(where: { calendar.isDate($0.challengeDate, inSameDayAs: date) }) {
            throw AirQualityRepositoryError.predictionAlreadySubmitted
        }
        let cutoff = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: date) ?? date
        guard Date() < cutoff else {
            throw AirQualityRepositoryError.predictionCutoffPassed
        }
        let challenge = PredictionChallenge(
            challengeDate: date,
            userPredictionPM25: pm25,
            cutoffAt: cutoff
        )
        storedChallenges.append(challenge)
        return challenge
    }

    // MARK: Scenario generation

    /// Representative "today" inputs for each interactive scenario. These are
    /// illustrative starting points (a demo needs *some* current reading),
    /// but everything computed *from* them — the forecast points, the driver
    /// contributions — goes through the real fitted coefficients below, not
    /// arbitrary trend math.
    private struct ScenarioInputs {
        let pm25Today: Double
        let windToday: Double
        let precipToday: Double
        let hourlyNoise: Double
        let hourlyTrendPerHour: Double
    }

    private func inputs(for scenario: DemoScenario) -> ScenarioInputs {
        switch scenario {
        case .cleanAirImproving:
            return ScenarioInputs(pm25Today: 14, windToday: 4.2, precipToday: 0.4, hourlyNoise: 1.2, hourlyTrendPerHour: -0.15)
        case .moderateRising:
            return ScenarioInputs(pm25Today: 24, windToday: 1.1, precipToday: 0.0, hourlyNoise: 2.0, hourlyTrendPerHour: 0.35)
        case .unhealthyLowConfidence:
            return ScenarioInputs(pm25Today: 95, windToday: 0.6, precipToday: 0.0, hourlyNoise: 6.0, hourlyTrendPerHour: 0.6)
        case .staleOffline:
            return ScenarioInputs(pm25Today: 18, windToday: 2.0, precipToday: 0.0, hourlyNoise: 1.0, hourlyTrendPerHour: 0.0)
        case .challengeRevealReady:
            return ScenarioInputs(pm25Today: 20, windToday: 2.4, precipToday: 0.1, hourlyNoise: 1.5, hourlyTrendPerHour: -0.1)
        }
    }

    /// Applies the real fitted regression: next-day PM2.5 = intercept +
    /// coef·(today's PM2.5) + coef·wind + coef·precip. See
    /// `ForecastModel.json` for the exact coefficients and their evaluation.
    private func regressionPredict(pm25: Double, wind: Double, precip: Double) -> Double {
        let c = BundledResearchData.forecastModel.model.coefficients
        let value = c.intercept + c.pm25Today * pm25 + c.wind * wind + c.precip * precip
        return max(0, value)
    }

    private func makeObservations() -> [AirQualityObservation] {
        let now = Date()
        let params = inputs(for: scenario)
        let calendar = Calendar.current
        let hoursBack = scenario == .staleOffline ? 6 : 0 // stale scenario: freshest point is 6h old
        var points: [AirQualityObservation] = []
        for hourOffset in stride(from: 23, through: 0, by: -1) {
            guard let timestamp = calendar.date(byAdding: .hour, value: -(hourOffset + hoursBack), to: now) else { continue }
            let hoursElapsed = Double(23 - hourOffset)
            let deterministicWiggle = sin(hoursElapsed / 3.0) * params.hourlyNoise
            let value = max(1, params.pm25Today + params.hourlyTrendPerHour * hoursElapsed + deterministicWiggle)
            points.append(
                AirQualityObservation(
                    timestamp: timestamp,
                    pm25: value.rounded(toPlaces: 1),
                    locationName: "Demo Station · Orange County, CA",
                    provenance: DataProvenance(
                        source: "AirCast Demo Dataset",
                        kind: .demo,
                        observedOrGeneratedAt: timestamp,
                        retrievedAt: now
                    )
                )
            )
        }
        return points.sorted { $0.timestamp > $1.timestamp }
    }

    /// Builds a daily forecast (not hourly): the underlying regression was
    /// fit and validated on next-*day* PM2.5, so presenting it as an hourly
    /// curve would imply precision it doesn't have. Only day+1 carries the
    /// real, validated empirical interval; day+2/day+3 come from recursively
    /// feeding the model's own prediction back in, which was never
    /// separately validated — so those are shown with an honest, degrading
    /// qualitative confidence label instead of a fabricated numeric interval.
    private func makeForecast() -> PM25Forecast {
        let now = Date()
        let params = inputs(for: scenario)
        let calendar = Calendar.current
        let residualInterval = BundledResearchData.forecastModel.evaluation.empiricalResidualInterval80pct
        let modelVersion = ResearchModelCard.card.model.version

        var points: [PM25ForecastPoint] = []
        var rollingPM25 = params.pm25Today

        for dayAhead in 1...3 {
            guard let target = calendar.date(byAdding: .day, value: dayAhead, to: now) else { continue }
            let predicted = regressionPredict(pm25: rollingPM25, wind: params.windToday, precip: params.precipToday)
            rollingPM25 = predicted // recursive rollout for subsequent days

            let uncertainty: ForecastUncertainty
            if scenario == .unhealthyLowConfidence {
                uncertainty = .qualitative(.low)
            } else if dayAhead == 1 {
                // Real, validated 80% empirical interval from the held-out test set.
                uncertainty = .computed(
                    lower: max(0, predicted + residualInterval.lower),
                    upper: predicted + residualInterval.upper,
                    coverage: 0.8
                )
            } else {
                uncertainty = .qualitative(dayAhead == 2 ? .medium : .low)
            }

            points.append(
                PM25ForecastPoint(
                    targetTime: target,
                    pm25: predicted.rounded(toPlaces: 1),
                    uncertainty: uncertainty,
                    provenance: DataProvenance(
                        source: "AirCast PM2.5 Forecast Model (fit on Orange County EPA/NOAA data)",
                        kind: .demo,
                        observedOrGeneratedAt: now,
                        retrievedAt: now,
                        modelVersion: modelVersion
                    )
                )
            )
        }

        let drivers = makeDrivers(inputs: params)
        return PM25Forecast(generatedAt: now, points: points, drivers: drivers, modelVersion: modelVersion)
    }

    /// Driver contributions are derived from the real regression coefficients'
    /// relative magnitude (|coef| normalized to sum to 1 across the three
    /// model inputs) — not hand-picked per scenario. Direction follows the
    /// coefficient's real sign combined with whether this scenario's input is
    /// above/below a typical Orange County day, so the explanation stays
    /// consistent with what the fitted model actually learned.
    private func makeDrivers(inputs params: ScenarioInputs) -> [ExplanationDriver] {
        guard scenario != .staleOffline else { return [] }

        let c = BundledResearchData.forecastModel.model.coefficients
        let magnitudes: [ExplanationDriver.Kind: Double] = [
            .recentPersistence: abs(c.pm25Today),
            .windSpeed: abs(c.wind),
            .precipitation: abs(c.precip),
        ]
        let total = magnitudes.values.reduce(0, +)
        func contribution(_ kind: ExplanationDriver.Kind) -> Double {
            total > 0 ? (magnitudes[kind] ?? 0) / total : 0
        }

        // Reference values used only to decide whether "today" reads as
        // high/low wind or meaningfully-wet for direction wording. Wind
        // threshold (2.1 m/s) is the real historical median from the bundled
        // dataset. Precipitation's historical median is exactly 0 (most days
        // are dry), so 0.2mm is used instead as a "meaningfully more than a
        // dry day" cutoff rather than a literal median.
        let typicalWind = 2.1
        let typicalPrecip = 0.2

        let windDirection: ExplanationDriver.Direction = params.windToday >= typicalWind ? .decreasesPM25 : .increasesPM25
        let precipDirection: ExplanationDriver.Direction = params.precipToday >= typicalPrecip ? .decreasesPM25 : .mixed
        let persistenceDirection: ExplanationDriver.Direction = params.hourlyTrendPerHour < 0 ? .decreasesPM25 : .increasesPM25

        let basis: ExplanationDriver.Basis = scenario == .unhealthyLowConfidence ? .ruleBased : .modelComputed

        var drivers = [
            ExplanationDriver(
                kind: .recentPersistence,
                direction: persistenceDirection,
                basis: basis,
                relativeContribution: basis == .modelComputed ? contribution(.recentPersistence) : nil,
                explanation: persistenceDirection == .decreasesPM25
                    ? "Recent PM2.5 has been trending down, and the model's strongest input is today's own level (coefficient \(c.pm25Today.formatted(decimals: 2)))."
                    : "Recent PM2.5 has been trending up, and the model's strongest input is today's own level (coefficient \(c.pm25Today.formatted(decimals: 2)))."
            ),
            ExplanationDriver(
                kind: .windSpeed,
                direction: windDirection,
                basis: basis,
                relativeContribution: basis == .modelComputed ? contribution(.windSpeed) : nil,
                explanation: windDirection == .decreasesPM25
                    ? "Wind is above its typical level; the fitted model associates higher wind with lower next-day PM2.5 (coefficient \(c.wind.formatted(decimals: 2)))."
                    : "Wind is below its typical level, which the fitted model associates with less particulate dispersion."
            ),
        ]

        if scenario != .unhealthyLowConfidence {
            drivers.append(
                ExplanationDriver(
                    kind: .precipitation,
                    direction: precipDirection,
                    basis: basis,
                    relativeContribution: basis == .modelComputed ? contribution(.precipitation) : nil,
                    explanation: precipDirection == .decreasesPM25
                        ? "Some precipitation is present; the fitted model associates precipitation with lower next-day PM2.5 (coefficient \(c.precip.formatted(decimals: 3)), a small effect)."
                        : "Little to no precipitation today, which removes one path for particulate washout."
                )
            )
        } else {
            drivers.append(
                ExplanationDriver(
                    kind: .windDirection,
                    direction: .mixed,
                    basis: .ruleBased,
                    relativeContribution: nil,
                    explanation: "Readings are elevated and wind is light, which limits how much the model's usual pattern can be trusted right now."
                )
            )
        }

        return drivers
    }

    /// Seeds the Prediction Challenge history with a **real** historical
    /// instance from the bundled dataset (today's inputs, the model's actual
    /// forecast, and the actual next-day observation) rather than invented
    /// numbers. The "user's" guess is a plausible illustrative value — there
    /// is no real historical user, since this is a demo persona. Seeded
    /// regardless of the app-wide demo scenario, so the Challenge tab always
    /// has a real, resolved example to show — a CAC judge shouldn't have to
    /// land on exactly the right scenario to see the full reveal flow.
    private func seedChallenges() -> [PredictionChallenge] {
        let example = BundledResearchData.recentObservations.challengeExample
        let calendar = Calendar.current
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let challengeDate = formatter.date(from: example.date) else { return [] }
        let cutoff = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: challengeDate) ?? challengeDate
        return [
            PredictionChallenge(
                challengeDate: challengeDate,
                userPredictionPM25: (example.pm25Today + 1.5).rounded(toPlaces: 1),
                submittedAt: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: challengeDate) ?? challengeDate,
                cutoffAt: cutoff,
                modelForecastPM25: example.modelForecastNextDay,
                observedPM25: example.observedNextDay,
                resolvedAt: challengeDate
            )
        ]
    }
}

/// Builds the app's `ModelCard` entirely from bundled, real research
/// artifacts — the fitted forecast regression's evaluation
/// (`BundledResearchData.forecastModel`) plus a summary of the JEI PM2.5
/// Episode-Recovery Cox survival study that motivated which weather features
/// the forecast model uses. No number here is invented.
private enum ResearchModelCard {
    static let card: ModelCard = {
        let bundled = BundledResearchData.forecastModel
        let dataset = bundled.dataset
        let model = bundled.model
        let eval = bundled.evaluation

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let lastUpdated = dateFormatter.date(from: dataset.dateRangeEnd) ?? Date()

        return ModelCard(
            researchQuestion: "Can next-day PM2.5 concentration in Orange County, CA be forecast from today's PM2.5, wind, and precipitation — and does that beat simply assuming tomorrow looks like today?",
            dataset: DatasetCard(
                sourceName: dataset.sourceName,
                geography: dataset.geography,
                dateRangeDescription: "\(dataset.dateRangeStart) to \(dataset.dateRangeEnd) (\(dataset.nConsecutiveDayPairs) consecutive-day pairs; gaps excluded, never interpolated)",
                sampleSize: dataset.nConsecutiveDayPairs,
                variables: dataset.variables,
                lastUpdated: lastUpdated
            ),
            model: ModelDescription(
                modelType: model.modelType,
                target: model.target,
                inputs: model.inputs,
                version: "ols-1.0",
                trainingValidationApproach: "Time-based split — trained on \(model.trainDateRange[0]) to \(model.trainDateRange[1]) (n=\(dataset.nTrainPairs)), evaluated on the held-out \(model.testDateRange[0]) to \(model.testDateRange[1]) (n=\(dataset.nTestPairs)) — so no future data leaks into training.",
                deploymentStatus: "On-device, computed from bundled coefficients. Not yet connected to a live data feed."
            ),
            metrics: [
                EvaluationMetric(
                    name: "MAE (test)",
                    definition: "Mean Absolute Error: average size of the forecast's miss, in µg/m³, on next-day PM2.5 the model never trained on.",
                    value: eval.test.modelMAE,
                    unit: "µg/m³",
                    baselineValue: eval.test.baselinePersistenceMAE
                ),
                EvaluationMetric(
                    name: "RMSE (test)",
                    definition: "Root Mean Squared Error: like MAE but penalizes large misses more heavily.",
                    value: eval.test.modelRMSE,
                    unit: "µg/m³",
                    baselineValue: eval.test.baselinePersistenceRMSE
                ),
            ],
            limitations: [
                "This is a simple 4-parameter linear regression (intercept + today's PM2.5 + wind + precipitation), not the peer-reviewed survival model described below — it exists to power a demonstrable next-day forecast.",
                "It beats a naive persistence baseline (\"tomorrow = today\") on the held-out test set, but only by a modest margin (\(eval.test.modelMAE.formatted(decimals: 2)) vs \((eval.test.baselinePersistenceMAE ?? 0).formatted(decimals: 2)) µg/m³ MAE) — treat forecasts as directionally useful, not precise.",
                "Trained on Orange County, CA only (2 monitoring sites averaged); may not generalize to other geographies.",
                "Daily resolution only — the source data does not support hourly forecasting, so AirCast shows day-ahead points rather than an hourly curve.",
                "The 80% interval shown for day+1 is a real, validated empirical interval from the test-set residuals; day+2 and day+3 reuse the model's own prediction as input and were not separately validated, so they show a qualitative confidence label instead of a numeric interval.",
            ],
            responsibleUseStatement: "AirCast is a student research and engineering project. It is not a substitute for official air-quality guidance from environmental agencies such as the EPA AirNow program.",
            relatedResearch: RelatedResearch(
                title: "Post-Peak Atmospheric Removal Conditions and Recovery from PM2.5 Pollution Episodes",
                summary: "A separate statistical study (Orange County, CA, 2014-2025) tested whether PM2.5 pollution episodes followed by stronger post-peak wind and precipitation recovered to baseline faster than episodes followed by weaker removal conditions, using a Cox proportional-hazards survival model on 143 identified episodes.",
                keyFinding: "Adjusted hazard ratio for the atmospheric removal index: 1.199 (95% CI 1.063–1.352, p=0.003) — episodes with stronger post-peak wind+precipitation recovered significantly faster. Supported by 4 of 6 prespecified sensitivity analyses and an independent 5-region external validation.",
                methodology: "Cox proportional-hazards model adjusted for season and year, fit on EPA daily PM2.5 (Anaheim + Mission Viejo) and NOAA John Wayne Airport wind/precipitation. Proportional-hazards assumption held (Schoenfeld test p=0.225).",
                limitations: [
                    "The sensitivity pattern is sensitive, not uniformly robust: 2 of 6 prespecified variants (5% and 20% recovery-tolerance thresholds) did not reach the same clear-support level as the primary analysis.",
                    "Wind and precipitation were not individually significant on their own (p=0.12, p=0.099) — only their combined removal index was (p=0.003), most likely due to statistical power rather than the combined result being spurious.",
                    "This study explains *why* wind/precipitation matter for recovery; it does not itself produce a next-day PM2.5 point forecast — that is the separate regression above.",
                ]
            )
        )
    }()
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }

    func formatted(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }
}
