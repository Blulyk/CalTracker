import Foundation
import SwiftData

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male = "Hombre"
    case female = "Mujer"
    var id: String { rawValue }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary = "Sedentario"
    case light = "Ligero"
    case moderate = "Moderado"
    case active = "Activo"
    case veryActive = "Muy activo"

    var id: String { rawValue }
    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

enum NutritionGoal: String, Codable, CaseIterable, Identifiable {
    case lose = "Perder peso"
    case maintain = "Mantener"
    case gain = "Ganar masa"

    var id: String { rawValue }
    var calorieAdjustment: Double {
        switch self {
        case .lose: -500
        case .maintain: 0
        case .gain: 300
        }
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Desayuno"
    case lunch = "Comida"
    case dinner = "Cena"
    case snack = "Snack"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .breakfast: "sun.max.fill"
        case .lunch: "fork.knife"
        case .dinner: "moon.stars.fill"
        case .snack: "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

struct NutritionTargets: Equatable {
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int
}

@Model
final class UserProfile {
    var name: String
    var age: Int
    var sexRaw: String
    var heightCM: Double
    var currentWeightKG: Double
    var targetWeightKG: Double
    var activityRaw: String
    var goalRaw: String
    var calorieOverride: Int?
    var fastingEnabled: Bool
    var fastingStartHour: Int
    var fastingHours: Int
    var carbCyclingEnabled: Bool = false
    var createdAt: Date

    init(
        name: String,
        age: Int,
        sex: Sex,
        heightCM: Double,
        currentWeightKG: Double,
        targetWeightKG: Double,
        activity: ActivityLevel,
        goal: NutritionGoal
    ) {
        self.name = name
        self.age = age
        sexRaw = sex.rawValue
        self.heightCM = heightCM
        self.currentWeightKG = currentWeightKG
        self.targetWeightKG = targetWeightKG
        activityRaw = activity.rawValue
        goalRaw = goal.rawValue
        calorieOverride = nil
        fastingEnabled = false
        fastingStartHour = 20
        fastingHours = 16
        carbCyclingEnabled = false
        createdAt = .now
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }
    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }
    var goal: NutritionGoal {
        get { NutritionGoal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }
}

@Model
final class MealEntry {
    var name: String
    var date: Date
    var mealTypeRaw: String
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var fiber: Double
    var serving: String
    var source: String
    var imageFilename: String?
    var foodsJSON: String?
    var analysisNotes: String?
    var analysisConfidence: String?
    var analysisModel: String?
    var createdAt: Date = Date()

    init(name: String, date: Date = .now, mealType: MealType, calories: Double, protein: Double, carbohydrates: Double, fat: Double, fiber: Double = 0, serving: String = "1 ración", source: String = "manual") {
        self.name = name
        self.date = date
        mealTypeRaw = mealType.rawValue
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.serving = serving
        self.source = source
        imageFilename = nil
        foodsJSON = nil
        analysisNotes = nil
        analysisConfidence = nil
        analysisModel = nil
        createdAt = .now
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }
}

@Model
final class WaterEntry {
    var date: Date
    var milliliters: Int
    init(date: Date = .now, milliliters: Int) {
        self.date = date
        self.milliliters = milliliters
    }
}

@Model
final class WeightEntry {
    var date: Date
    var kilograms: Double
    init(date: Date = .now, kilograms: Double) {
        self.date = date
        self.kilograms = kilograms
    }
}

@Model
final class Recipe {
    var name: String
    var details: String
    var servings: Int
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var carbsPerServing: Double
    var fatPerServing: Double
    var ingredientsText: String
    var instructionsText: String
    var createdAt: Date
    var imageFilename: String?
    var sourceURL: String?
    var foodsJSON: String?
    var fiberPerServing: Double = 0

    init(name: String, details: String = "", servings: Int = 1, caloriesPerServing: Double, proteinPerServing: Double, carbsPerServing: Double, fatPerServing: Double, ingredientsText: String, instructionsText: String) {
        self.name = name
        self.details = details
        self.servings = servings
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.carbsPerServing = carbsPerServing
        self.fatPerServing = fatPerServing
        self.ingredientsText = ingredientsText
        self.instructionsText = instructionsText
        createdAt = .now
        imageFilename = nil
        sourceURL = nil
        foodsJSON = nil
        fiberPerServing = 0
    }
}

@Model
final class MealPlanEntry {
    var date: Date
    var mealTypeRaw: String
    var title: String
    var recipeName: String?
    var recipeIdentifier: String?
    var servings: Double = 1

    init(date: Date, mealType: MealType, title: String, recipeName: String? = nil) {
        self.date = date
        mealTypeRaw = mealType.rawValue
        self.title = title
        self.recipeName = recipeName
        recipeIdentifier = nil
        servings = 1
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .lunch }
        set { mealTypeRaw = newValue.rawValue }
    }
}

@Model
final class BuffetSession {
    var startedAt: Date
    var completedAt: Date?
    var totalPieces: Int
    var nigiri: Int
    var maki: Int
    var tempura: Int
    var gyoza: Int
    var dessert: Int
    var other: Int
    var calories: Int
    var protein: Int
    var carbohydrates: Int
    var fat: Int
    var usedGemini: Bool
    var summary: String
    var savedMealID: String?

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
        completedAt = nil
        totalPieces = 0
        nigiri = 0
        maki = 0
        tempura = 0
        gyoza = 0
        dessert = 0
        other = 0
        calories = 0
        protein = 0
        carbohydrates = 0
        fat = 0
        usedGemini = false
        summary = ""
        savedMealID = nil
    }

    var breakdown: BuffetBreakdown {
        get {
            BuffetBreakdown(
                nigiri: nigiri,
                maki: maki,
                tempura: tempura,
                gyoza: gyoza,
                dessert: dessert,
                other: other
            )
        }
        set {
            nigiri = newValue.nigiri
            maki = newValue.maki
            tempura = newValue.tempura
            gyoza = newValue.gyoza
            dessert = newValue.dessert
            other = newValue.other
        }
    }
}

@Model
final class ShoppingItem {
    var name: String
    var quantity: String
    var isCompleted: Bool
    var createdAt: Date

    init(name: String, quantity: String = "") {
        self.name = name
        self.quantity = quantity
        isCompleted = false
        createdAt = .now
    }
}

struct AnalyzedFood: Codable, Identifiable {
    var id = UUID()
    let name: String
    let portion: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?

    enum CodingKeys: String, CodingKey {
        case name, portion, calories, protein, carbs, fat, fiber
    }
}

struct FoodAnalysis: Codable {
    let foods: [AnalyzedFood]
    let confidence: Double?
    let mealTypeSuggestion: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case foods, confidence, notes
        case mealTypeSuggestion = "meal_type_suggestion"
    }
}

struct ProductLookup {
    let name: String
    let serving: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double
}
