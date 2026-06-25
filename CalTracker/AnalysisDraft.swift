import Foundation

enum AnalysisConfidence: String, Codable, CaseIterable {
    case high = "Alta"
    case medium = "Media"
    case low = "Baja"

    init(serviceValue: String?) {
        switch serviceValue?.lowercased() {
        case "high", "alta": self = .high
        case "low", "baja": self = .low
        default: self = .medium
        }
    }
}

struct DraftFood: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var portion: String
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var fiber: Double

    init(
        id: UUID = UUID(),
        name: String,
        portion: String,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        fiber: Double
    ) {
        self.id = id
        self.name = name
        self.portion = portion
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
    }

    init(_ food: AnalyzedFood) {
        self.init(
            name: food.name,
            portion: food.portion,
            calories: food.calories,
            protein: food.protein,
            carbohydrates: food.carbs,
            fat: food.fat,
            fiber: food.fiber ?? 0
        )
    }
}

struct AnalysisDraft: Identifiable, Equatable {
    let id: UUID
    var foods: [DraftFood]
    var confidence: AnalysisConfidence
    var modelUsed: String
    var notes: String
    var imageFilename: String?
    var mealType: MealType
    var source: String

    init(
        id: UUID = UUID(),
        foods: [DraftFood],
        confidence: AnalysisConfidence,
        modelUsed: String,
        notes: String,
        imageFilename: String? = nil,
        mealType: MealType = .lunch,
        source: String = "gemini"
    ) {
        self.id = id
        self.foods = foods
        self.confidence = confidence
        self.modelUsed = modelUsed
        self.notes = notes
        self.imageFilename = imageFilename
        self.mealType = mealType
        self.source = source
    }

    var totalCalories: Double { foods.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { foods.reduce(0) { $0 + $1.protein } }
    var totalCarbohydrates: Double { foods.reduce(0) { $0 + $1.carbohydrates } }
    var totalFat: Double { foods.reduce(0) { $0 + $1.fat } }
    var totalFiber: Double { foods.reduce(0) { $0 + $1.fiber } }

    var displayName: String {
        let names = foods.map(\.name).filter { !$0.isEmpty }
        return names.prefix(2).joined(separator: " + ").nilIfEmpty ?? "Comida analizada"
    }
}

enum StructuredFoodCodec {
    static func encode(_ foods: [DraftFood]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(foods)
        guard let value = String(data: data, encoding: .utf8) else {
            throw ServiceError.invalidResponse
        }
        return value
    }

    static func decode(_ value: String?) throws -> [DraftFood] {
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([DraftFood].self, from: data)
    }
}

struct BuffetBreakdown: Codable, Equatable {
    var nigiri = 0
    var maki = 0
    var tempura = 0
    var gyoza = 0
    var dessert = 0
    var other = 0

    var classifiedTotal: Int {
        nigiri + maki + tempura + gyoza + dessert + other
    }
}

struct BuffetEstimate: Equatable {
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int
}

enum BuffetEstimator {
    private struct Nutrition {
        let calories: Double
        let protein: Double
        let carbohydrates: Double
        let fat: Double
    }

    private static let nigiri = Nutrition(calories: 70, protein: 5.5, carbohydrates: 8.5, fat: 1.2)
    private static let maki = Nutrition(calories: 45, protein: 1.8, carbohydrates: 7.5, fat: 1.2)
    private static let tempura = Nutrition(calories: 85, protein: 3.8, carbohydrates: 8.5, fat: 4)
    private static let gyoza = Nutrition(calories: 55, protein: 3.2, carbohydrates: 5.5, fat: 2.2)
    private static let dessert = Nutrition(calories: 95, protein: 1.2, carbohydrates: 21, fat: 1)
    private static let other = Nutrition(calories: 60, protein: 2.8, carbohydrates: 7, fat: 1.8)
    private static let unclassified = Nutrition(calories: 66, protein: 3.5, carbohydrates: 8, fat: 2)

    static func estimate(totalPieces: Int, breakdown: BuffetBreakdown) -> BuffetEstimate {
        let entries: [(Int, Nutrition)] = [
            (breakdown.nigiri, nigiri),
            (breakdown.maki, maki),
            (breakdown.tempura, tempura),
            (breakdown.gyoza, gyoza),
            (breakdown.dessert, dessert),
            (breakdown.other, other),
            (max(0, totalPieces - breakdown.classifiedTotal), unclassified)
        ]
        let calories = entries.reduce(0.0) { $0 + Double($1.0) * $1.1.calories }
        let protein = entries.reduce(0.0) { $0 + Double($1.0) * $1.1.protein }
        let carbohydrates = entries.reduce(0.0) { $0 + Double($1.0) * $1.1.carbohydrates }
        let fat = entries.reduce(0.0) { $0 + Double($1.0) * $1.1.fat }
        return BuffetEstimate(
            calories: Int(calories.rounded()),
            protein: Int(protein.rounded()),
            carbohydrates: Int(carbohydrates.rounded()),
            fat: Int(fat.rounded())
        )
    }
}

enum APIKeyPresentation {
    static let mask = "••••••••••••••••••••"

    static func isMask(_ value: String) -> Bool {
        value == mask
    }

    static func shouldSave(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isMask(value)
    }
}
