import XCTest
@testable import CalTracker

final class DailySummaryTests: XCTestCase {
    func testSummaryIncludesOnlyEntriesFromSelectedDay() {
        let calendar = Calendar(identifier: .gregorian)
        let selected = date(2026, 6, 25)
        let meals = [
            NutritionSnapshot(date: selected, calories: 450, protein: 30, carbohydrates: 52, fat: 14),
            NutritionSnapshot(date: date(2026, 6, 24), calories: 900, protein: 60, carbohydrates: 90, fat: 30)
        ]

        let summary = DailySummary.make(
            date: selected,
            meals: meals,
            water: [],
            calorieTarget: 2_000,
            calendar: calendar
        )

        XCTAssertEqual(summary.calories, 450)
        XCTAssertEqual(summary.protein, 30)
        XCTAssertEqual(summary.carbohydrates, 52)
        XCTAssertEqual(summary.fat, 14)
    }

    func testSummaryAccumulatesWaterAndDetectsExceededTarget() {
        let calendar = Calendar(identifier: .gregorian)
        let selected = date(2026, 6, 25)

        let summary = DailySummary.make(
            date: selected,
            meals: [
                NutritionSnapshot(date: selected, calories: 1_300, protein: 40, carbohydrates: 100, fat: 25),
                NutritionSnapshot(date: selected, calories: 900, protein: 35, carbohydrates: 80, fat: 30)
            ],
            water: [
                WaterSnapshot(date: selected, milliliters: 250),
                WaterSnapshot(date: selected, milliliters: 500)
            ],
            calorieTarget: 2_000,
            calendar: calendar
        )

        XCTAssertEqual(summary.waterMilliliters, 750)
        XCTAssertTrue(summary.exceededTarget)
        XCTAssertEqual(summary.remainingCalories, 0)
        XCTAssertEqual(summary.progress, 1)
    }

    func testWeekStartsOnMondayAndContainsSevenDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2

        let week = calendar.calTrackerWeek(containing: date(2026, 6, 25))

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(calendar.component(.day, from: week[0]), 22)
        XCTAssertEqual(calendar.component(.day, from: week[6]), 28)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day).date!
    }
}
