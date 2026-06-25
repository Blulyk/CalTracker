import XCTest
@testable import CalTracker

final class FunctionalParityTests: XCTestCase {
    func testAnalysisDraftRecalculatesTotalsAfterFoodEdit() throws {
        var draft = AnalysisDraft(
            foods: [
                DraftFood(name: "Pan", portion: "120 g", calories: 312, protein: 9.6, carbohydrates: 60, fat: 1.8, fiber: 4),
                DraftFood(name: "Tomate", portion: "40 g", calories: 7, protein: 0.4, carbohydrates: 1.6, fat: 0.1, fiber: 0.5)
            ],
            confidence: .high,
            modelUsed: "gemini-2.5-flash",
            notes: "Estimación"
        )

        draft.foods[1].calories = 12

        XCTAssertEqual(draft.totalCalories, 324)
        XCTAssertEqual(draft.totalProtein, 10, accuracy: 0.001)
        XCTAssertEqual(draft.totalCarbohydrates, 61.6, accuracy: 0.001)
        XCTAssertEqual(draft.totalFat, 1.9, accuracy: 0.001)
    }

    func testStructuredFoodsRoundTripPreservesEditableValues() throws {
        let foods = [
            DraftFood(name: "Salmón", portion: "150 g", calories: 310, protein: 32, carbohydrates: 0, fat: 19, fiber: 0)
        ]

        let encoded = try StructuredFoodCodec.encode(foods)
        let decoded = try StructuredFoodCodec.decode(encoded)

        XCTAssertEqual(decoded, foods)
    }

    func testBuffetEstimateUsesCategoriesAndUnclassifiedPieces() {
        let breakdown = BuffetBreakdown(
            nigiri: 3,
            maki: 4,
            tempura: 2,
            gyoza: 1,
            dessert: 1,
            other: 0
        )

        let estimate = BuffetEstimator.estimate(totalPieces: 13, breakdown: breakdown)

        XCTAssertEqual(estimate.calories, 842)
        XCTAssertEqual(estimate.protein, 43)
        XCTAssertEqual(estimate.carbohydrates, 115)
        XCTAssertEqual(estimate.fat, 24)
    }

    func testMaskedKeyDoesNotReplaceStoredCredential() {
        XCTAssertTrue(APIKeyPresentation.isMask(APIKeyPresentation.mask))
        XCTAssertFalse(APIKeyPresentation.shouldSave(APIKeyPresentation.mask))
        XCTAssertFalse(APIKeyPresentation.shouldSave(""))
        XCTAssertTrue(APIKeyPresentation.shouldSave("AIza-new-value"))
    }

    func testBuffetAnalysisDecodesGeminiPayloadAndRecordsModel() throws {
        let payload = """
        {
          "calories": 842,
          "protein": 43,
          "carbohydrates": 115,
          "fat": 24,
          "summary": "Estimación contextual del buffet."
        }
        """.data(using: .utf8)!

        let result = try BuffetAnalysisResult.decode(
            payload,
            modelUsed: "gemini-2.5-flash"
        )

        XCTAssertEqual(result.calories, 842)
        XCTAssertEqual(result.protein, 43)
        XCTAssertEqual(result.carbohydrates, 115)
        XCTAssertEqual(result.fat, 24)
        XCTAssertEqual(result.summary, "Estimación contextual del buffet.")
        XCTAssertEqual(result.modelUsed, "gemini-2.5-flash")
    }

    func testFoodAnalysisAcceptsTextAndNumericConfidence() throws {
        let textPayload = """
        {"foods":[],"confidence":"high","meal_type_suggestion":"Comida","notes":""}
        """.data(using: .utf8)!
        let numericPayload = """
        {"foods":[],"confidence":0.45,"meal_type_suggestion":"Snack","notes":""}
        """.data(using: .utf8)!

        let textResult = try JSONDecoder().decode(FoodAnalysis.self, from: textPayload)
        let numericResult = try JSONDecoder().decode(FoodAnalysis.self, from: numericPayload)

        XCTAssertEqual(textResult.confidence, .high)
        XCTAssertEqual(numericResult.confidence, .low)
    }

    func testDraftCreatesOneMealWithImageAndStructuredFoods() throws {
        let draft = AnalysisDraft(
            foods: [
                DraftFood(name: "Salmón", portion: "150 g", calories: 310, protein: 32, carbohydrates: 0, fat: 19, fiber: 0),
                DraftFood(name: "Arroz", portion: "180 g", calories: 234, protein: 4.8, carbohydrates: 50.4, fat: 0.5, fiber: 0.7)
            ],
            confidence: .high,
            modelUsed: "gemini-2.5-flash",
            notes: "Raciones revisadas",
            imageFilename: "meal-photo.jpg",
            mealType: .lunch
        )

        let meal = try MealEntry(draft: draft, date: Date(timeIntervalSince1970: 123))

        XCTAssertEqual(meal.name, "Salmón + Arroz")
        XCTAssertEqual(meal.calories, 544, accuracy: 0.001)
        XCTAssertEqual(meal.imageFilename, "meal-photo.jpg")
        XCTAssertEqual(meal.analysisConfidence, AnalysisConfidence.high.rawValue)
        XCTAssertEqual(try StructuredFoodCodec.decode(meal.foodsJSON), draft.foods)
    }

    func testRestaurantCatalogSearchMatchesChainAndProductName() {
        let chainMatches = RestaurantCatalog.search("mcdonald")
        let productMatches = RestaurantCatalog.search("whopper")

        XCTAssertTrue(chainMatches.contains { $0.chain == "McDonald's" })
        XCTAssertTrue(productMatches.contains { $0.name == "Whopper" })
    }

    func testRecipeImportDraftDecodesGeminiPayload() throws {
        let payload = """
        {
          "name": "Pasta al pesto",
          "details": "Receta rápida",
          "servings": 2,
          "calories_per_serving": 540,
          "protein_per_serving": 18,
          "carbs_per_serving": 72,
          "fat_per_serving": 21,
          "fiber_per_serving": 6,
          "ingredients": ["200 g pasta", "40 g pesto"],
          "instructions": ["Cocer la pasta", "Mezclar con el pesto"]
        }
        """.data(using: .utf8)!

        let draft = try JSONDecoder().decode(RecipeImportDraft.self, from: payload)

        XCTAssertEqual(draft.name, "Pasta al pesto")
        XCTAssertEqual(draft.servings, 2)
        XCTAssertEqual(draft.ingredientsText, "200 g pasta\n40 g pesto")
        XCTAssertEqual(draft.instructionsText, "Cocer la pasta\nMezclar con el pesto")
    }

    func testShoppingSuggestionsDeduplicatePlannedIngredients() {
        let suggestions = ShoppingListGenerator.suggestions(
            from: [
                PlannedIngredients(text: "Tomate\nArroz\nAceite", servings: 2),
                PlannedIngredients(text: "tomate\nPollo", servings: 1)
            ]
        )

        XCTAssertEqual(suggestions.map(\.name), ["Aceite", "Arroz", "Pollo", "Tomate"])
        XCTAssertEqual(suggestions.first { $0.name == "Tomate" }?.quantity, "3 raciones")
    }
}
