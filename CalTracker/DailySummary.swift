import Foundation

struct NutritionSnapshot {
    let date: Date
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
}

struct WaterSnapshot {
    let date: Date
    let milliliters: Int
}

struct DailySummary {
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let waterMilliliters: Int
    let calorieTarget: Int

    var remainingCalories: Int {
        max(calorieTarget - Int(calories.rounded()), 0)
    }

    var exceededTarget: Bool {
        calories > Double(calorieTarget)
    }

    var progress: Double {
        min(calories / max(Double(calorieTarget), 1), 1)
    }

    static func make(
        date: Date,
        meals: [NutritionSnapshot],
        water: [WaterSnapshot],
        calorieTarget: Int,
        calendar: Calendar = .current
    ) -> DailySummary {
        let dayMeals = meals.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let dayWater = water.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return DailySummary(
            calories: dayMeals.reduce(0) { $0 + $1.calories },
            protein: dayMeals.reduce(0) { $0 + $1.protein },
            carbohydrates: dayMeals.reduce(0) { $0 + $1.carbohydrates },
            fat: dayMeals.reduce(0) { $0 + $1.fat },
            waterMilliliters: max(0, dayWater.reduce(0) { $0 + $1.milliliters }),
            calorieTarget: calorieTarget
        )
    }
}

extension Calendar {
    func calTrackerWeek(containing date: Date) -> [Date] {
        var components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = firstWeekday
        guard let start = self.date(from: components) else { return [date] }
        return (0..<7).compactMap { self.date(byAdding: .day, value: $0, to: start) }
    }
}
