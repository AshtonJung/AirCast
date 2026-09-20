import Foundation

/// Decoded shape of `Resources/ResearchData/ForecastModel.json` — the output
/// of a real ordinary-least-squares regression fit against the cleaned
/// Orange County daily PM2.5 + weather dataset from the `jei-pm25-episode-recovery`
/// research project (EPA AirData + NOAA John Wayne Airport, 2014-2025).
///
/// This is a genuine fitted model, not illustrative numbers: coefficients,
/// evaluation metrics, and baseline comparison are all computed from a
/// time-based train (2014-2022) / test (2023-2025) split with no leakage
/// across data gaps. See `fit_forecast_model.py` provenance note in
/// `evaluation` for exact methodology.
struct BundledForecastModelFile: Codable {
    struct DatasetInfo: Codable {
        let sourceName: String
        let geography: String
        let dateRangeStart: String
        let dateRangeEnd: String
        let nConsecutiveDayPairs: Int
        let nTrainPairs: Int
        let nTestPairs: Int
        let variables: [String]

        enum CodingKeys: String, CodingKey {
            case sourceName = "source_name"
            case geography
            case dateRangeStart = "date_range_start"
            case dateRangeEnd = "date_range_end"
            case nConsecutiveDayPairs = "n_consecutive_day_pairs"
            case nTrainPairs = "n_train_pairs"
            case nTestPairs = "n_test_pairs"
            case variables
        }
    }

    struct ModelInfo: Codable {
        struct Coefficients: Codable {
            let intercept: Double
            let pm25Today: Double
            let wind: Double
            let precip: Double

            enum CodingKeys: String, CodingKey {
                case intercept
                case pm25Today = "pm25_today"
                case wind
                case precip
            }
        }

        let modelType: String
        let target: String
        let inputs: [String]
        let coefficients: Coefficients
        let trainDateRange: [String]
        let testDateRange: [String]

        enum CodingKeys: String, CodingKey {
            case modelType = "model_type"
            case target
            case inputs
            case coefficients
            case trainDateRange = "train_date_range"
            case testDateRange = "test_date_range"
        }
    }

    struct Evaluation: Codable {
        struct Split: Codable {
            let modelMAE: Double
            let modelRMSE: Double
            let baselinePersistenceMAE: Double?
            let baselinePersistenceRMSE: Double?
            let n: Int

            enum CodingKeys: String, CodingKey {
                case modelMAE = "model_mae"
                case modelRMSE = "model_rmse"
                case baselinePersistenceMAE = "baseline_persistence_mae"
                case baselinePersistenceRMSE = "baseline_persistence_rmse"
                case n
            }
        }

        struct ResidualInterval: Codable {
            let lower: Double
            let upper: Double
            let description: String
        }

        let test: Split
        let train: Split
        let empiricalResidualInterval80pct: ResidualInterval

        enum CodingKeys: String, CodingKey {
            case test, train
            case empiricalResidualInterval80pct = "empirical_residual_interval_80pct"
        }
    }

    let generatedAt: String
    let sourceDataset: String
    let dataset: DatasetInfo
    let model: ModelInfo
    let evaluation: Evaluation

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case sourceDataset = "source_dataset"
        case dataset, model, evaluation
    }
}

/// Decoded shape of `Resources/ResearchData/RecentObservations.json` — the
/// most recent 60 days of the real cleaned daily series, plus one real,
/// deterministic (date, today's inputs, model forecast, actual next-day
/// observation) example used to ground the Prediction Challenge demo in a
/// genuine historical event instead of synthetic numbers.
struct BundledRecentObservationsFile: Codable {
    struct DailyRecord: Codable {
        let date: String
        let pm25: Double?
        let wind: Double?
        let precip: Double?
        let season: String
    }

    struct ChallengeExample: Codable {
        let date: String
        let pm25Today: Double
        let windToday: Double
        let precipToday: Double
        let modelForecastNextDay: Double
        let observedNextDay: Double

        enum CodingKeys: String, CodingKey {
            case date
            case pm25Today = "pm25_today"
            case windToday = "wind_today"
            case precipToday = "precip_today"
            case modelForecastNextDay = "model_forecast_next_day"
            case observedNextDay = "observed_next_day"
        }
    }

    let recentObservations: [DailyRecord]
    let challengeExample: ChallengeExample

    enum CodingKeys: String, CodingKey {
        case recentObservations = "recent_observations"
        case challengeExample = "challenge_example"
    }
}

/// Decoded shape of `Resources/ResearchData/TestResiduals.json` — every one
/// of the 1,052 held-out test-set (date, observed, predicted, residual)
/// rows behind the model's reported MAE/RMSE. This is what powers Model
/// Lab's diagnostic charts (observed-vs-predicted, residuals over time) with
/// real per-point data instead of just the aggregate metrics.
struct BundledTestResidualsFile: Codable {
    struct TestPoint: Codable, Identifiable {
        let date: String
        let observed: Double
        let predicted: Double
        let residual: Double

        var id: String { date }
    }

    let testPoints: [TestPoint]

    enum CodingKeys: String, CodingKey {
        case testPoints = "test_points"
    }
}

/// Loads the bundled research-derived JSON resources once per launch. These
/// files ship inside the app bundle and are covered by
/// `BundledResearchDataTests`, so a decode failure here means the bundle is
/// broken (a packaging bug to fix, not a runtime condition to recover from).
enum BundledResearchData {
    static let forecastModel: BundledForecastModelFile = load("ForecastModel")
    static let recentObservations: BundledRecentObservationsFile = load("RecentObservations")
    static let testResiduals: BundledTestResidualsFile = load("TestResiduals")

    static func load<T: Decodable>(_ name: String, bundle: Bundle = .main) -> T {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "ResearchData")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else {
            fatalError("Missing bundled research data file '\(name).json'. This ships with the app; see AirCast/Resources/ResearchData.")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Failed to decode bundled research data '\(name).json': \(error)")
        }
    }
}
