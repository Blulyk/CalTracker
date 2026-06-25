import Foundation
import UIKit

struct RecipeImportDraft: Decodable, Equatable {
    let name: String
    let details: String
    let servings: Int
    let caloriesPerServing: Double
    let proteinPerServing: Double
    let carbsPerServing: Double
    let fatPerServing: Double
    let fiberPerServing: Double
    let ingredients: [String]
    let instructions: [String]

    enum CodingKeys: String, CodingKey {
        case name, details, servings, ingredients, instructions
        case caloriesPerServing = "calories_per_serving"
        case proteinPerServing = "protein_per_serving"
        case carbsPerServing = "carbs_per_serving"
        case fatPerServing = "fat_per_serving"
        case fiberPerServing = "fiber_per_serving"
    }

    var ingredientsText: String {
        ingredients.joined(separator: "\n")
    }

    var instructionsText: String {
        instructions.joined(separator: "\n")
    }
}

struct PlannedIngredients {
    let text: String
    let servings: Double
}

struct ShoppingSuggestion: Equatable {
    let name: String
    let quantity: String
}

enum ShoppingListGenerator {
    static func suggestions(from plans: [PlannedIngredients]) -> [ShoppingSuggestion] {
        var totals: [String: (displayName: String, servings: Double)] = [:]
        for plan in plans {
            for line in plan.text.components(separatedBy: .newlines) {
                let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                let existing = totals[key]
                totals[key] = (existing?.displayName ?? name.capitalized, (existing?.servings ?? 0) + plan.servings)
            }
        }
        return totals.values
            .map {
                let value = $0.servings.formatted(.number.precision(.fractionLength(0...1)))
                return ShoppingSuggestion(name: $0.displayName, quantity: "\(value) raciones")
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

actor RecipeImportService {
    func importRecipe(from urlText: String) async throws -> RecipeImportDraft {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            throw ServiceError.remote("Introduce una URL válida de una receta.")
        }
        var request = URLRequest(url: url)
        request.setValue("CalTracker/1.2 (iOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw ServiceError.remote("No se pudo descargar la receta.")
        }
        let text = try plainText(from: data)
        return try await GeminiService().importRecipe(pageText: String(text.prefix(18_000)), sourceURL: url.absoluteString)
    }

    private func plainText(from htmlData: Data) throws -> String {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let attributed = try NSAttributedString(data: htmlData, options: options, documentAttributes: nil)
        let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ServiceError.invalidResponse }
        return text
    }
}
