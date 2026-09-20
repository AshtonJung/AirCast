import Foundation

/// A single measured PM2.5 reading.
struct AirQualityObservation: Identifiable, Equatable, Codable {
    let id: UUID
    let timestamp: Date
    /// PM2.5 concentration in micrograms per cubic meter (µg/m³).
    let pm25: Double
    let locationName: String
    let provenance: DataProvenance

    var category: AQICategory { AQICategory.classify(pm25: pm25) }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        pm25: Double,
        locationName: String,
        provenance: DataProvenance
    ) {
        self.id = id
        self.timestamp = timestamp
        self.pm25 = pm25
        self.locationName = locationName
        self.provenance = provenance
    }
}

/// Weather covariates associated with a timestamp. Optional per-field because
/// live sources may not report everything — missing must stay `nil`, never 0.
struct WeatherObservation: Equatable, Codable {
    let timestamp: Date
    /// Wind speed in meters/second.
    let windSpeedMS: Double?
    /// Wind direction in degrees (0 = N, 90 = E).
    let windDirectionDegrees: Double?
    /// Precipitation in the prior hour, millimeters.
    let precipitationMM: Double?
    /// Relative humidity, percent (0-100).
    let relativeHumidityPercent: Double?
    let provenance: DataProvenance
}
