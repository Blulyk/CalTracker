import Foundation

struct RestaurantFood: Identifiable, Equatable {
    let id: String
    let chain: String
    let name: String
    let serving: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double

    init(
        chain: String,
        name: String,
        serving: String,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        fiber: Double = 0
    ) {
        self.chain = chain
        self.name = name
        self.serving = serving
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        id = "\(chain)-\(name)".lowercased()
    }

    var draft: AnalysisDraft {
        AnalysisDraft(
            foods: [
                DraftFood(
                    name: name,
                    portion: serving,
                    calories: calories,
                    protein: protein,
                    carbohydrates: carbohydrates,
                    fat: fat,
                    fiber: fiber
                )
            ],
            confidence: .high,
            modelUsed: "Base local \(chain)",
            notes: "Información nutricional orientativa del producto seleccionado.",
            source: "restaurant"
        )
    }
}

enum RestaurantCatalog {
    static let items: [RestaurantFood] = [
        RestaurantFood(chain: "McDonald's", name: "Big Mac", serving: "1 hamburguesa", calories: 590, protein: 25, carbohydrates: 46, fat: 34, fiber: 3),
        RestaurantFood(chain: "McDonald's", name: "McChicken", serving: "1 hamburguesa", calories: 400, protein: 14, carbohydrates: 39, fat: 21, fiber: 2),
        RestaurantFood(chain: "McDonald's", name: "Patatas medianas", serving: "1 ración", calories: 337, protein: 4, carbohydrates: 42, fat: 17, fiber: 4),
        RestaurantFood(chain: "Burger King", name: "Whopper", serving: "1 hamburguesa", calories: 657, protein: 28, carbohydrates: 49, fat: 40, fiber: 2),
        RestaurantFood(chain: "Burger King", name: "Chicken Royale", serving: "1 hamburguesa", calories: 571, protein: 25, carbohydrates: 55, fat: 28, fiber: 3),
        RestaurantFood(chain: "KFC", name: "3 tiras de pollo", serving: "3 unidades", calories: 390, protein: 36, carbohydrates: 22, fat: 18),
        RestaurantFood(chain: "KFC", name: "Twister", serving: "1 wrap", calories: 535, protein: 27, carbohydrates: 53, fat: 24, fiber: 3),
        RestaurantFood(chain: "Starbucks", name: "Caffè Latte grande", serving: "473 ml", calories: 190, protein: 13, carbohydrates: 18, fat: 7),
        RestaurantFood(chain: "Starbucks", name: "Caramel Macchiato grande", serving: "473 ml", calories: 250, protein: 10, carbohydrates: 35, fat: 7),
        RestaurantFood(chain: "Five Guys", name: "Hamburguesa", serving: "1 hamburguesa", calories: 840, protein: 39, carbohydrates: 39, fat: 55),
        RestaurantFood(chain: "Five Guys", name: "Patatas pequeñas", serving: "1 ración", calories: 526, protein: 8, carbohydrates: 72, fat: 23, fiber: 8),
        RestaurantFood(chain: "Subway", name: "Pollo teriyaki 15 cm", serving: "1 bocadillo", calories: 370, protein: 25, carbohydrates: 58, fat: 5, fiber: 4),
        RestaurantFood(chain: "Subway", name: "Italian B.M.T. 15 cm", serving: "1 bocadillo", calories: 410, protein: 20, carbohydrates: 46, fat: 16, fiber: 4)
    ]

    static func search(_ query: String) -> [RestaurantFood] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return items }
        return items.filter {
            $0.chain.localizedCaseInsensitiveContains(value)
                || $0.name.localizedCaseInsensitiveContains(value)
        }
    }
}
