import Foundation
import Observation

/// Drives the Statistics / Model Lab screen. The model card is fetched
/// through the repository (so it stays swappable for live mode later); the
/// per-point diagnostic data is fixed, bundled research output
/// (`BundledResearchData.testResiduals`) — not scenario-dependent, since
/// it's the literal held-out evaluation of the one real fitted model.
@Observable
@MainActor
final class ModelLabViewModel {
    private let repository: AirQualityRepository

    private(set) var phase: LoadPhase = .loading
    private(set) var modelCard: ModelCard?

    init(repository: AirQualityRepository) {
        self.repository = repository
    }

    var testPoints: [BundledTestResidualsFile.TestPoint] {
        BundledResearchData.testResiduals.testPoints
    }

    func load() async {
        let hadData = modelCard != nil
        if !hadData { phase = .loading }
        do {
            modelCard = try await repository.modelCard()
            phase = .loaded
        } catch {
            if !hadData {
                phase = .failed(RepositoryErrorPresentation.kind(for: error), message: RepositoryErrorPresentation.message(for: error))
            }
        }
    }
}
