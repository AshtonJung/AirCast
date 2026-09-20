import SwiftUI

/// Shared tab-selection state so a card on one tab (e.g. Home's Prediction
/// Challenge CTA) can jump the user to another tab without views reaching
/// into each other directly. Owned by `AppRootView`, injected as an
/// environment object.
@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
}
