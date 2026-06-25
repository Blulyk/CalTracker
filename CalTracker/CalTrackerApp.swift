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
            ShoppingItem.self,
            BuffetSession.self
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
    @Environment(\.modelContext) private var modelContext
    @State private var didSeedUITest = false

    var body: some View {
        Group {
            if profiles.first == nil {
                OnboardingView()
                    .task { seedUITestDataIfNeeded() }
            } else {
                RootView()
            }
        }
        .preferredColorScheme(forcedColorScheme)
    }

    private var forcedColorScheme: ColorScheme? {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-dark") { return .dark }
        if arguments.contains("-ui-light") { return .light }
#endif
        return nil
    }

    private func seedUITestDataIfNeeded() {
#if DEBUG
        guard !didSeedUITest,
              ProcessInfo.processInfo.arguments.contains("-ui-testing"),
              profiles.isEmpty else { return }
        didSeedUITest = true
        let profile = UserProfile(
            name: "Blulyk",
            age: 29,
            sex: .male,
            heightCM: 175,
            currentWeightKG: 74.2,
            targetWeightKG: 69,
            activity: .moderate,
            goal: .lose
        )
        modelContext.insert(profile)
        modelContext.insert(MealEntry(name: "Tostada con aguacate", mealType: .breakfast, calories: 390, protein: 14, carbohydrates: 44, fat: 18, fiber: 7, serving: "1 plato"))
        modelContext.insert(MealEntry(name: "Pollo con arroz y verduras", mealType: .lunch, calories: 680, protein: 52, carbohydrates: 72, fat: 19, fiber: 9, serving: "1 plato"))
        modelContext.insert(WaterEntry(milliliters: 1_250))
        modelContext.insert(WeightEntry(kilograms: 74.2))
        modelContext.insert(Recipe(name: "Patatas estilo restaurante", details: "Patatas crujientes con salsa casera.", servings: 2, caloriesPerServing: 540, proteinPerServing: 11, carbsPerServing: 57, fatPerServing: 34, ingredientsText: "Patata\nQueso\nCebolla crujiente", instructionsText: "Hornea las patatas y termina con la salsa y el queso."))
        modelContext.insert(Recipe(name: "Café con leche", details: "Café suave para el desayuno.", servings: 1, caloriesPerServing: 109, proteinPerServing: 4, carbsPerServing: 14, fatPerServing: 4, ingredientsText: "Café\nLeche", instructionsText: "Prepara el café y añade leche caliente."))
        try? modelContext.save()
#endif
    }
}
