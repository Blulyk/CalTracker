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

        XCTAssertEqual(estimate.calories, 849)
        XCTAssertEqual(estimate.protein, 39)
        XCTAssertEqual(estimate.carbohydrates, 100)
        XCTAssertEqual(estimate.fat, 22)
    }

    func testMaskedKeyDoesNotReplaceStoredCredential() {
        XCTAssertTrue(APIKeyPresentation.isMask(APIKeyPresentation.mask))
        XCTAssertFalse(APIKeyPresentation.shouldSave(APIKeyPresentation.mask))
        XCTAssertFalse(APIKeyPresentation.shouldSave(""))
        XCTAssertTrue(APIKeyPresentation.shouldSave("AIza-new-value"))
    }
}
