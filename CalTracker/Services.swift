import Foundation
import Security
import UIKit

enum NutritionCalculator {
    static func targets(for profile: UserProfile) -> NutritionTargets {
        let sexOffset = profile.sex == .male ? 5.0 : -161.0
        let bmr = (10 * profile.currentWeightKG) + (6.25 * profile.heightCM) - (5 * Double(profile.age)) + sexOffset
        let calculated = max(1200, Int((bmr * profile.activity.multiplier + profile.goal.calorieAdjustment).rounded()))
        let calories = profile.calorieOverride ?? calculated
        let protein = Int((profile.currentWeightKG * (profile.goal == .gain ? 2.0 : 1.8)).rounded())
        let fat = Int((Double(calories) * 0.25 / 9).rounded())
        let carbs = max(0, Int((Double(calories) - Double(protein * 4) - Double(fat * 9)) / 4))
        return NutritionTargets(calories: calories, protein: protein, carbohydrates: carbs, fat: fat)
    }
}

enum KeychainStore {
    private static let service = "com.blulyk.CalTracker"

    static func saveGeminiKey(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "gemini-api-key"
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else { throw ServiceError.keychain(status) }
    }

    static func geminiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "gemini-api-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteGeminiKey() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "gemini-api-key"
        ] as CFDictionary)
    }
}

enum ServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case productNotFound
    case imageEncoding
    case keychain(OSStatus)
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Añade tu clave de Gemini en Perfil."
        case .invalidResponse: "El servicio devolvió una respuesta que no se pudo interpretar."
        case .productNotFound: "No se encontró ese producto."
        case .imageEncoding: "No se pudo preparar la imagen."
        case .keychain(let status): "Keychain devolvió el error \(status)."
        case .remote(let message): message
        }
    }
}

struct BuffetAnalysisResult: Equatable {
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int
    let summary: String
    let modelUsed: String

    private struct Payload: Decodable {
        let calories: Double
        let protein: Double
        let carbohydrates: Double
        let fat: Double
        let summary: String
    }

    static func decode(_ data: Data, modelUsed: String) throws -> BuffetAnalysisResult {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return BuffetAnalysisResult(
            calories: Int(payload.calories.rounded()),
            protein: Int(payload.protein.rounded()),
            carbohydrates: Int(payload.carbohydrates.rounded()),
            fat: Int(payload.fat.rounded()),
            summary: payload.summary,
            modelUsed: modelUsed
        )
    }
}

actor GeminiService {
    private let models = ["gemini-2.5-flash-lite", "gemini-2.5-flash", "gemini-2.0-flash"]

    func analyze(imageData: Data, profileName: String?) async throws -> FoodAnalysis {
        guard let key = KeychainStore.geminiKey(), !key.isEmpty else { throw ServiceError.missingAPIKey }
        let prompt = """
        Analiza esta comida y responde únicamente JSON válido, sin markdown:
        {"foods":[{"name":"string","portion":"string","calories":0,"protein":0,"carbs":0,"fat":0,"fiber":0}],"confidence":0.0,"meal_type_suggestion":"Desayuno|Comida|Cena|Snack","notes":"string"}
        Estima valores realistas. Las calorías son kcal y los macronutrientes gramos.
        """
        guard let encoded = imageData.base64EncodedString().nilIfEmpty else { throw ServiceError.imageEncoding }

        var lastError: Error = ServiceError.invalidResponse
        for model in models {
            do {
                return try await request(model: model, key: key, prompt: prompt, image: encoded)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func coach(summary: String, profileName: String) async throws -> String {
        guard let key = KeychainStore.geminiKey(), !key.isEmpty else { throw ServiceError.missingAPIKey }
        let prompt = "Eres un coach nutricional prudente. Dirígete a \(profileName). Resume en español, en máximo 90 palabras, una mejora concreta basada en estos datos: \(summary). No diagnostiques enfermedades."
        var lastError: Error = ServiceError.invalidResponse
        for model in models {
            do {
                return try await textRequest(model: model, key: key, prompt: prompt)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func analyzeBuffet(
        pieces: Int,
        breakdown: BuffetBreakdown,
        durationMinutes: Int
    ) async throws -> BuffetAnalysisResult {
        guard let key = KeychainStore.geminiKey(), !key.isEmpty else {
            throw ServiceError.missingAPIKey
        }
        let prompt = """
        Estima la nutrición de una sesión de buffet de sushi y responde únicamente JSON válido, sin markdown:
        {"calories":0,"protein":0,"carbohydrates":0,"fat":0,"summary":"string"}
        Datos: \(pieces) piezas totales durante \(durationMinutes) minutos.
        Desglose: \(breakdown.nigiri) nigiri, \(breakdown.maki) maki, \(breakdown.tempura) tempura, \(breakdown.gyoza) gyoza, \(breakdown.dessert) postres y \(breakdown.other) otras piezas.
        Usa kcal y gramos enteros, y explica brevemente las principales suposiciones en summary.
        """

        var lastError: Error = ServiceError.invalidResponse
        for model in models {
            do {
                let data = try await call(model: model, key: key, parts: [["text": prompt]])
                let json = try cleanedJSONData(from: extractText(data))
                return try BuffetAnalysisResult.decode(json, modelUsed: model)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func request(model: String, key: String, prompt: String, image: String) async throws -> FoodAnalysis {
        let parts: [[String: Any]] = [
            ["text": prompt],
            ["inline_data": ["mime_type": "image/jpeg", "data": image]]
        ]
        let data = try await call(model: model, key: key, parts: parts)
        let json = try cleanedJSONData(from: extractText(data))
        return try JSONDecoder().decode(FoodAnalysis.self, from: json)
    }

    private func textRequest(model: String, key: String, prompt: String) async throws -> String {
        let data = try await call(model: model, key: key, parts: [["text": prompt]])
        return try extractText(data)
    }

    private func call(model: String, key: String, parts: [[String: Any]]) async throws -> Data {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            throw ServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["contents": [["parts": parts]]])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Gemini respondió \(http.statusCode)."
            throw ServiceError.remote(message)
        }
        return data
    }

    private func extractText(_ data: Data) throws -> String {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw ServiceError.invalidResponse
        }
        return text
    }

    private func cleanedJSONData(from text: String) throws -> Data {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else {
            throw ServiceError.invalidResponse
        }
        return data
    }
}

actor OpenFoodFactsService {
    func lookup(barcode: String) async throws -> ProductLookup {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json") else {
            throw ServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("CalTracker/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["status"] as? Int) == 1,
              let product = root["product"] as? [String: Any],
              let nutrients = product["nutriments"] as? [String: Any] else {
            throw ServiceError.productNotFound
        }
        func number(_ key: String) -> Double {
            (nutrients[key] as? NSNumber)?.doubleValue ?? 0
        }
        return ProductLookup(
            name: (product["product_name"] as? String).flatMap { $0.nilIfEmpty } ?? "Producto",
            serving: (product["serving_size"] as? String).flatMap { $0.nilIfEmpty } ?? "100 g",
            calories: number("energy-kcal_100g"),
            protein: number("proteins_100g"),
            carbohydrates: number("carbohydrates_100g"),
            fat: number("fat_100g"),
            fiber: number("fiber_100g")
        )
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
