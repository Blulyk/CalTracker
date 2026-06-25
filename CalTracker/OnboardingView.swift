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
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Brand.orange, Brand.blue.opacity(0.18))
                        VStack(alignment: .leading) {
                            Text("CalTracker").font(.title.bold())
                            Text("Tu nutrición, guardada en tu iPhone.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Tu perfil") {
                    TextField("Nombre", text: $name)
                        .textContentType(.name)
                    Stepper("Edad: \(age)", value: $age, in: 13...100)
                    Picker("Sexo metabólico", selection: $sex) {
                        ForEach(Sex.allCases) { Text($0.rawValue).tag($0) }
                    }
                    LabeledContent("Altura") {
                        TextField("cm", value: $height, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    LabeledContent("Peso actual") {
                        TextField("kg", value: $weight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    LabeledContent("Peso objetivo") {
                        TextField("kg", value: $targetWeight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }

                Section("Objetivo") {
                    Picker("Actividad", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Meta", selection: $goal) {
                        ForEach(NutritionGoal.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section {
                    SecureField("Clave de Google Gemini", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("IA opcional")
                } footer: {
                    Text("La clave se guarda en Keychain y solo se envía a Google al usar análisis o coach. Puedes añadirla más tarde.")
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                Button {
                    createProfile()
                } label: {
                    Label("Crear perfil local", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .navigationTitle("Bienvenido")
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
