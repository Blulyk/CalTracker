import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var age = 30
    @State private var sex = Sex.male
    @State private var height = 175.0
    @State private var weight = 75.0
    @State private var targetWeight = 70.0
    @State private var activity = ActivityLevel.moderate
    @State private var goal = NutritionGoal.lose
    @State private var apiKey = ""
    @State private var errorMessage: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (13...100).contains(age) && (120...230).contains(height) &&
        (30...350).contains(weight) && (30...350).contains(targetWeight)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    brandHeader
                    identityCard
                    metricsCard
                    objectiveCard
                    geminiCard
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Brand.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appSurface(tint: Brand.red)
                    }
                    Button(action: createProfile) {
                        PrimaryActionLabel(title: "Crear perfil local", systemImage: "arrow.right")
                    }
                    .disabled(!isValid)
                    Text("Sin cuenta, sin servidor y sin telemetría.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Brand.blue.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(Brand.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0.76, to: 0.92)
                    .stroke(Brand.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "leaf.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 94, height: 94)
            Text("CalTracker")
                .font(.system(size: 38, weight: .black, design: .rounded))
            Text("Tu nutrición, clara y privada.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "person.fill", color: Brand.blue, title: "Tu perfil")
            TextField("¿Cómo te llamas?", text: $name)
                .textContentType(.name)
                .font(.headline)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Brand.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
            HStack {
                Text("Edad").fontWeight(.semibold)
                Spacer()
                Stepper("\(age) años", value: $age, in: 13...100)
                    .fixedSize()
            }
            Picker("Sexo metabólico", selection: $sex) {
                ForEach(Sex.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .appSurface()
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "ruler.fill", color: Brand.violet, title: "Métricas corporales")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                numberField("Altura", value: $height, unit: "cm")
                numberField("Peso actual", value: $weight, unit: "kg")
                numberField("Peso objetivo", value: $targetWeight, unit: "kg")
            }
        }
        .appSurface()
    }

    private var objectiveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "target", color: Brand.orange, title: "Tu objetivo")
            Picker("Meta", selection: $goal) {
                ForEach(NutritionGoal.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Actividad", selection: $activity) {
                ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(Brand.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
        }
        .appSurface(tint: Brand.orange)
    }

    private var geminiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle(icon: "sparkles", color: Brand.violet, title: "Gemini, opcional")
            SecureField("Clave API de Google Gemini", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Brand.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
            Text("Puedes omitirla. Se guarda en Keychain y solo se usa al pedir análisis.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .appSurface(tint: Brand.violet)
    }

    private func cardTitle(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            IconBadge(systemName: icon, color: color, size: 36)
            Text(title).font(.headline)
        }
    }

    private func numberField(_ title: String, value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .fontWeight(.semibold)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Brand.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func createProfile() {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: age,
            sex: sex,
            heightCM: height,
            currentWeightKG: weight,
            targetWeightKG: targetWeight,
            activity: activity,
            goal: goal
        )
        modelContext.insert(profile)
        modelContext.insert(WeightEntry(kilograms: weight))
        do {
            if !apiKey.isEmpty { try KeychainStore.saveGeminiKey(apiKey) }
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
