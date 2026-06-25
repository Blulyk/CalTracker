import SwiftUI
import SwiftData

@main
struct CalTrackerApp: App {
    private let container: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            MealEntry.self,
            WaterEntry.self,
            WeightEntry.self,
            Recipe.self,
            MealPlanEntry.self,
            ShoppingItem.self
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("No se pudo abrir la base de datos local: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppGateView()
                .tint(Brand.blue)
        }
        .modelContainer(container)
    }
}

struct AppGateView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if profiles.first == nil {
            OnboardingView()
        } else {
            RootView()
        }
    }
}
