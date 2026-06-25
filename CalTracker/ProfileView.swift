import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Query private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @State private var apiKey = ""
    @State private var keyStatus = ""
    @State private var coachText = ""
    @State private var loadingCoach = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack {
            AppBackground()
            if let profile = profiles.first {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        profileHeader(profile)
                        geminiCard
                        bodyMetricsCard(profile)
                        goalCard(profile)
                        calculatedCard(profile)
                        coachCard(profile)
                        fastingCard(profile)
                        carbCyclingCard(profile)
                        privacyCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            let configured = KeychainStore.geminiKey() != nil
            apiKey = configured ? APIKeyPresentation.mask : ""
            keyStatus = configured ? "Clave API configurada" : "No configurada"
        }
        .alert("Borrar todos los datos", isPresented: $showingDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar", role: .destructive) { eraseAllData() }
        } message: {
            Text("Esta acción elimina el perfil, comidas, recetas, planificación y clave de Gemini de este iPhone.")
        }
    }

    private func profileHeader(_ profile: UserProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Perfil").font(.largeTitle.bold())
                Text("@\(profile.name.replacingOccurrences(of: " ", with: "").lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(profile.name.first.map(String.init)?.uppercased() ?? "C")
                .font(.title3.bold())
                .foregroundStyle(Brand.orange)
                .frame(width: 50, height: 50)
                .background(Brand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                .overlay { RoundedRectangle(cornerRadius: 17).stroke(Brand.orange.opacity(0.35), lineWidth: 1) }
        }
        .padding(.top, 10)
    }

    private var geminiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "key.fill", color: Brand.orange, title: "Clave API de Gemini")
            Text("Se guarda en Keychain y solo se usa cuando solicitas análisis de fotos o consejo.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField("Introduce tu clave API", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Brand.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(Brand.border, lineWidth: 1) }
            HStack {
                Circle().fill(KeychainStore.geminiKey() == nil ? Brand.red : Brand.orange).frame(width: 7, height: 7)
                Text(keyStatus).font(.caption.weight(.semibold)).foregroundStyle(KeychainStore.geminiKey() == nil ? Brand.red : Brand.orange)
                Spacer()
                Button("Guardar") { saveAPIKey() }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.orange)
                    .disabled(!APIKeyPresentation.shouldSave(apiKey))
            }
        }
        .appSurface()
    }

    private func bodyMetricsCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            cardTitle(icon: "ruler.fill", color: Brand.violet, title: "Métricas corporales")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricField("Altura", value: binding(profile, \.heightCM), unit: "cm")
                metricField("Peso actual", value: binding(profile, \.currentWeightKG), unit: "kg")
                metricField("Peso objetivo", value: binding(profile, \.targetWeightKG), unit: "kg")
                ageField(profile)
            }
            Picker("Sexo metabólico", selection: binding(profile, \.sexRaw)) {
                ForEach(Sex.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
        .appSurface()
    }

    private func goalCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            cardTitle(icon: "target", color: Brand.red, title: "Tu objetivo")
            HStack(spacing: 10) {
                goalTile(profile, goal: .lose, icon: "chart.line.downtrend.xyaxis")
                goalTile(profile, goal: .maintain, icon: "equal.circle.fill")
                goalTile(profile, goal: .gain, icon: "chart.line.uptrend.xyaxis")
            }
            Text("Nivel de actividad")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 9) {
                ForEach(ActivityLevel.allCases) { level in
                    activityRow(profile, level: level)
                }
            }
        }
        .appSurface()
    }

    private func calculatedCard(_ profile: UserProfile) -> some View {
        let targets = NutritionCalculator.targets(for: profile)
        return VStack(spacing: 15) {
            EyebrowLabel(text: "Objetivo calculado", color: Brand.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                resultTile(value: "\(targets.calories)", label: "kcal/día", color: Brand.orange)
                resultTile(value: String(format: "%.1f", bmi(profile)), label: "IMC", color: .primary)
                resultTile(value: "\(Int(tdee(profile)))", label: "TDEE", color: Brand.orange)
            }
            HStack(spacing: 10) {
                resultTile(value: "\(targets.protein)g", label: "Proteína", color: Brand.protein)
                resultTile(value: "\(targets.carbohydrates)g", label: "Carbos", color: Brand.carb)
                resultTile(value: "\(targets.fat)g", label: "Grasas", color: Brand.fat)
            }
            if let weeks = estimatedWeeks(profile) {
                Text("~\(weeks) semanas para alcanzar tu objetivo")
                    .font(.headline)
                    .foregroundStyle(Brand.orange)
                    .frame(maxWidth: .infinity)
            }
            Toggle("Usar objetivo calórico manual", isOn: Binding(
                get: { profile.calorieOverride != nil },
                set: { profile.calorieOverride = $0 ? targets.calories : nil }
            ))
            if profile.calorieOverride != nil {
                Stepper("Objetivo: \(profile.calorieOverride ?? targets.calories) kcal", value: Binding(
                    get: { profile.calorieOverride ?? targets.calories },
                    set: { profile.calorieOverride = $0 }
                ), in: 1200...6000, step: 50)
            }
            Button {
                try? modelContext.save()
            } label: {
                PrimaryActionLabel(title: "Guardar cambios", systemImage: "checkmark")
            }
        }
        .appSurface(tint: Brand.orange)
    }

    private func coachCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            cardTitle(icon: "sparkles", color: Brand.violet, title: "Coach nutricional")
            if coachText.isEmpty {
                Text("Analiza tus últimos siete días para recibir una recomendación breve y personalizada.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(coachText).font(.subheadline)
            }
            Button {
                Task { await askCoach(profile) }
            } label: {
                if loadingCoach {
                    ProgressView().frame(maxWidth: .infinity).frame(height: 46)
                } else {
                    Label("Analizar mi semana", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.violet.opacity(0.62))
            .disabled(loadingCoach)
        }
        .appSurface(tint: Brand.violet)
    }

    private func fastingCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "timer", color: Brand.violet, title: "Ayuno intermitente")
            Text("Controla tu ventana de alimentación. El inicio mostrará tu estado cuando esté activo.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Activar ayuno intermitente", isOn: binding(profile, \.fastingEnabled))
                .fontWeight(.semibold)
            if profile.fastingEnabled {
                Stepper("Comienza a las \(profile.fastingStartHour):00", value: binding(profile, \.fastingStartHour), in: 0...23)
                Stepper("Duración: \(profile.fastingHours) h", value: binding(profile, \.fastingHours), in: 8...23)
            }
        }
        .appSurface()
    }

    private func carbCyclingCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "arrow.triangle.2.circlepath", color: Brand.blue, title: "Ciclo de carbohidratos")
            Text("Activa objetivos diferenciados para alternar días de entrenamiento y descanso.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Activar ciclo de carbohidratos", isOn: binding(profile, \.carbCyclingEnabled))
                .fontWeight(.semibold)
        }
        .appSurface()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(icon: "lock.shield.fill", color: Brand.green, title: "Privacidad local")
            Text("CalTracker no usa cuentas, servidor propio, iCloud ni telemetría. Tus registros viven en este iPhone.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if KeychainStore.geminiKey() != nil {
                Button("Eliminar clave de Gemini", role: .destructive) {
                    KeychainStore.deleteGeminiKey()
                    apiKey = ""
                    keyStatus = "No configurada"
                }
                .buttonStyle(.bordered)
            }
            Button("Borrar todos mis datos", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .buttonStyle(.bordered)
            .tint(Brand.red)
        }
        .appSurface()
    }

    private func cardTitle(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            IconBadge(systemName: icon, color: color, size: 36)
            Text(title).font(.headline)
        }
    }

    private func metricField(_ title: String, value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
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
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1) }
        }
    }

    private func ageField(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Edad").font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Edad", value: binding(profile, \.age), format: .number)
                    .keyboardType(.numberPad)
                    .fontWeight(.semibold)
                Text("años").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Brand.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1) }
        }
    }

    private func goalTile(_ profile: UserProfile, goal: NutritionGoal, icon: String) -> some View {
        let selected = profile.goal == goal
        return Button {
            withAnimation(.snappy) { profile.goal = goal }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title3)
                Text(goal == .lose ? "Perder" : goal == .maintain ? "Mantener" : "Ganar")
                    .font(.caption.bold())
            }
            .foregroundStyle(selected ? Brand.orange : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(selected ? Brand.orange.opacity(0.14) : Brand.elevatedSurface, in: RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).stroke(selected ? Brand.orange.opacity(0.5) : Brand.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func activityRow(_ profile: UserProfile, level: ActivityLevel) -> some View {
        let selected = profile.activity == level
        return Button {
            withAnimation(.snappy) { profile.activity = level }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(level.rawValue).fontWeight(.semibold)
                    Text(activityDescription(level)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.orange)
                }
            }
            .foregroundStyle(selected ? Brand.orange : .primary)
            .padding(.horizontal, 14)
            .frame(height: 62)
            .background(selected ? Brand.orange.opacity(0.12) : Brand.elevatedSurface, in: RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).stroke(selected ? Brand.orange.opacity(0.5) : Brand.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func activityDescription(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "Trabajo de escritorio, sin ejercicio"
        case .light: return "1–3 días por semana"
        case .moderate: return "3–5 días por semana"
        case .active: return "6–7 días por semana"
        case .veryActive: return "Deportista o trabajo físico"
        }
    }

    private func resultTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.headline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.22), lineWidth: 1) }
    }

    private func saveAPIKey() {
        guard APIKeyPresentation.shouldSave(apiKey) else { return }
        do {
            try KeychainStore.saveGeminiKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            apiKey = APIKeyPresentation.mask
            keyStatus = "Clave API configurada"
        } catch {
            keyStatus = error.localizedDescription
        }
    }

    private func binding<Value>(_ profile: UserProfile, _ keyPath: ReferenceWritableKeyPath<UserProfile, Value>) -> Binding<Value> {
        Binding(get: { profile[keyPath: keyPath] }, set: { profile[keyPath: keyPath] = $0 })
    }

    private func bmi(_ profile: UserProfile) -> Double {
        profile.currentWeightKG / pow(profile.heightCM / 100, 2)
    }

    private func tdee(_ profile: UserProfile) -> Double {
        let offset = profile.sex == .male ? 5.0 : -161.0
        let bmr = 10 * profile.currentWeightKG + 6.25 * profile.heightCM - 5 * Double(profile.age) + offset
        return bmr * profile.activity.multiplier
    }

    private func estimatedWeeks(_ profile: UserProfile) -> Int? {
        let difference = abs(profile.currentWeightKG - profile.targetWeightKG)
        guard difference >= 0.2, profile.goal != .maintain else { return nil }
        let weeklyRate = profile.goal == .lose ? 0.5 : 0.3
        return max(1, Int(ceil(difference / weeklyRate)))
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
        meals.forEach { MediaStore.delete($0.imageFilename) }
        recipes.forEach { MediaStore.delete($0.imageFilename) }
        try? modelContext.delete(model: MealEntry.self)
        try? modelContext.delete(model: WaterEntry.self)
        try? modelContext.delete(model: WeightEntry.self)
        try? modelContext.delete(model: Recipe.self)
        try? modelContext.delete(model: MealPlanEntry.self)
        try? modelContext.delete(model: ShoppingItem.self)
        try? modelContext.delete(model: BuffetSession.self)
        try? modelContext.delete(model: UserProfile.self)
        KeychainStore.deleteGeminiKey()
        apiKey = ""
        keyStatus = "No configurada"
    }
}
