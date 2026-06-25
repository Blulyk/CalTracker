import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var apiKey = ""
    @State private var keyStatus = ""
    @State private var coachText = ""
    @State private var loadingCoach = false

    var body: some View {
        Form {
            if let profile = profiles.first {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Brand.blue)
                        VStack(alignment: .leading) {
                            Text(profile.name).font(.title2.bold())
                            Text("Perfil local · sin cuenta").foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Datos y objetivo") {
                    TextField("Nombre", text: binding(profile, \.name))
                    Stepper("Edad: \(profile.age)", value: binding(profile, \.age), in: 13...100)
                    Picker("Sexo metabólico", selection: binding(profile, \.sexRaw)) {
                        ForEach(Sex.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    editableNumber("Altura", value: binding(profile, \.heightCM), unit: "cm")
                    editableNumber("Peso", value: binding(profile, \.currentWeightKG), unit: "kg")
                    editableNumber("Objetivo", value: binding(profile, \.targetWeightKG), unit: "kg")
                    Picker("Actividad", selection: binding(profile, \.activityRaw)) {
                        ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Picker("Meta", selection: binding(profile, \.goalRaw)) {
                        ForEach(NutritionGoal.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                }

                targetsSection(profile)
                fastingSection(profile)

                Section {
                    SecureField("Clave API", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Guardar clave en Keychain") {
                        do {
                            try KeychainStore.saveGeminiKey(apiKey)
                            apiKey = ""
                            keyStatus = "Clave guardada de forma segura."
                        } catch { keyStatus = error.localizedDescription }
                    }
                    Button("Eliminar clave", role: .destructive) {
                        KeychainStore.deleteGeminiKey()
                        keyStatus = "Clave eliminada."
                    }
                    if !keyStatus.isEmpty { Text(keyStatus).font(.caption).foregroundStyle(.secondary) }
                } header: {
                    Text("Google Gemini")
                } footer: {
                    Text("Las fotos y el resumen nutricional solo salen del dispositivo cuando tú solicitas una función de Gemini.")
                }

                Section("Coach nutricional") {
                    if !coachText.isEmpty { Text(coachText) }
                    Button {
                        Task { await askCoach(profile) }
                    } label: {
                        if loadingCoach { ProgressView() } else { Label("Analizar mi semana", systemImage: "sparkles") }
                    }
                    .disabled(loadingCoach)
                }

                Section {
                    Button("Borrar todos mis datos", role: .destructive) { eraseAllData() }
                } footer: {
                    Text("CalTracker no usa cuentas, servidor propio, iCloud ni telemetría. Tus registros viven en este dispositivo.")
                }
            }
        }
        .navigationTitle("Perfil")
        .onAppear { keyStatus = KeychainStore.geminiKey() == nil ? "No hay ninguna clave configurada." : "Hay una clave guardada en Keychain." }
    }

    private func targetsSection(_ profile: UserProfile) -> some View {
        let targets = NutritionCalculator.targets(for: profile)
        return Section("Objetivos calculados") {
            LabeledContent("Calorías", value: "\(targets.calories) kcal")
            LabeledContent("Proteína", value: "\(targets.protein) g")
            LabeledContent("Carbohidratos", value: "\(targets.carbohydrates) g")
            LabeledContent("Grasa", value: "\(targets.fat) g")
            Toggle("Usar objetivo manual", isOn: Binding(
                get: { profile.calorieOverride != nil },
                set: { profile.calorieOverride = $0 ? targets.calories : nil }
            ))
            if profile.calorieOverride != nil {
                Stepper("Objetivo: \(profile.calorieOverride ?? targets.calories) kcal", value: Binding(
                    get: { profile.calorieOverride ?? targets.calories },
                    set: { profile.calorieOverride = $0 }
                ), in: 1200...6000, step: 50)
            }
        }
    }

    private func fastingSection(_ profile: UserProfile) -> some View {
        Section("Ayuno") {
            Toggle("Ayuno intermitente", isOn: binding(profile, \.fastingEnabled))
            if profile.fastingEnabled {
                Stepper("Comienza a las \(profile.fastingStartHour):00", value: binding(profile, \.fastingStartHour), in: 0...23)
                Stepper("Duración: \(profile.fastingHours) h", value: binding(profile, \.fastingHours), in: 8...23)
            }
        }
    }

    private func editableNumber(_ label: String, value: Binding<Double>, unit: String) -> some View {
        LabeledContent(label) {
            TextField(label, value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func binding<Value>(_ profile: UserProfile, _ keyPath: ReferenceWritableKeyPath<UserProfile, Value>) -> Binding<Value> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { profile[keyPath: keyPath] = $0 }
        )
    }

    private func askCoach(_ profile: UserProfile) async {
        loadingCoach = true
        defer { loadingCoach = false }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recent = meals.filter { $0.date >= sevenDaysAgo }
        let summary = "\(recent.count) comidas, \(Int(recent.reduce(0) { $0 + $1.calories })) kcal totales, \(Int(recent.reduce(0) { $0 + $1.protein })) g proteína; objetivo \(NutritionCalculator.targets(for: profile).calories) kcal/día."
        do {
            coachText = try await GeminiService().coach(summary: summary, profileName: profile.name)
        } catch {
            coachText = error.localizedDescription
        }
    }

    private func eraseAllData() {
        try? modelContext.delete(model: MealEntry.self)
        try? modelContext.delete(model: WaterEntry.self)
        try? modelContext.delete(model: WeightEntry.self)
        try? modelContext.delete(model: Recipe.self)
        try? modelContext.delete(model: MealPlanEntry.self)
        try? modelContext.delete(model: ShoppingItem.self)
        try? modelContext.delete(model: UserProfile.self)
        KeychainStore.deleteGeminiKey()
    }
}
