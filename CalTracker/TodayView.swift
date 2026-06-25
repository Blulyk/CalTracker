import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var waterEntries: [WaterEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var showingWeight = false
    @State private var weight = 70.0
    @State private var coachText = ""
    @State private var loadingCoach = false
    @State private var mealToDelete: MealEntry?
    let onAddMeal: () -> Void
    let onStartBuffet: () -> Void

    private let waterGoal = 2_500
    private var profile: UserProfile? { profiles.first }
    private var targets: NutritionTargets {
        profile.map(NutritionCalculator.targets) ?? NutritionTargets(calories: 2_000, protein: 140, carbohydrates: 250, fat: 70)
    }
    private var dayMeals: [MealEntry] {
        meals.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    private var summary: DailySummary {
        DailySummary.make(
            date: selectedDate,
            meals: meals.map {
                NutritionSnapshot(date: $0.date, calories: $0.calories, protein: $0.protein, carbohydrates: $0.carbohydrates, fat: $0.fat)
            },
            water: waterEntries.map { WaterSnapshot(date: $0.date, milliliters: $0.milliliters) },
            calorieTarget: targets.calories
        )
    }
    private var latestWeight: WeightEntry? {
        weightEntries.first { $0.date <= Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(spacing: 16) {
                    header
                    WeekStrip(selectedDate: $selectedDate)
                    calorieHeadline
                    balanceCard
                    insightGrid
                    buffetCard
                    hydrationCard
                    weightCard
                    mealsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingWeight) { weightSheet }
        .alert("Eliminar comida", isPresented: Binding(
            get: { mealToDelete != nil },
            set: { if !$0 { mealToDelete = nil } }
        )) {
            Button("Cancelar", role: .cancel) { mealToDelete = nil }
            Button("Eliminar", role: .destructive) {
                guard let meal = mealToDelete else { return }
                MediaStore.delete(meal.imageFilename)
                modelContext.delete(meal)
                mealToDelete = nil
            }
        } message: {
            Text("La comida y su fotografía se eliminarán de este iPhone.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                EyebrowLabel(text: greeting, color: .primary)
                Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline.weight(.bold))
                    .textCase(.none)
            }
            Spacer()
            Text(profile?.name.first.map(String.init)?.uppercased() ?? "C")
                .font(.headline.bold())
                .frame(width: 44, height: 44)
                .background(Brand.elevatedSurface, in: Circle())
                .overlay { Circle().stroke(Brand.border, lineWidth: 1) }
                .accessibilityLabel("Perfil de \(profile?.name ?? "CalTracker")")
        }
        .padding(.top, 10)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<13: return "Buenos días"
        case 13..<20: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    private var calorieHeadline: some View {
        VStack(spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(Int(summary.calories))")
                    .font(.system(size: 62, weight: .black, design: .rounded))
                Text("kcal")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }
            Text(summary.exceededTarget ? "\(Int(summary.calories) - targets.calories) kcal sobre el objetivo" : "\(summary.remainingCalories) kcal restantes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(summary.exceededTarget ? Brand.red : .secondary)
        }
        .padding(.vertical, 4)
    }

    private var balanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    EyebrowLabel(text: "Balance diario", color: .primary)
                    Text("Objetivo \(targets.calories) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(summary.progress * 100))%")
                    .font(.headline.bold())
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(Brand.elevatedSurface, in: Capsule())
                    .overlay { Capsule().stroke(Brand.border, lineWidth: 1) }
            }

            CalorieRing(consumed: summary.calories, goal: Double(targets.calories))

            HStack(spacing: 8) {
                MiniMacroRing(label: "Carbos", value: summary.carbohydrates, target: Double(targets.carbohydrates), color: Brand.carb)
                MiniMacroRing(label: "Proteína", value: summary.protein, target: Double(targets.protein), color: Brand.protein)
                MiniMacroRing(label: "Grasa", value: summary.fat, target: Double(targets.fat), color: Brand.fat)
            }
        }
        .appSurface(padding: 18, radius: 28)
    }

    private func macroMetric(label: String, value: Double, target: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(value))").font(.title3.bold())
                Text("/\(target)g").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var insightGrid: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                Label("RACHA", systemImage: "flame.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Brand.carb)
                Text("\(streak)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                Text("días seguidos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .appSurface(padding: 16)

            VStack(alignment: .leading, spacing: 9) {
                Label("COACH IA", systemImage: "sparkles")
                    .font(.caption2.bold())
                    .foregroundStyle(Brand.violet)
                Text(coachText.isEmpty ? "Consejo personalizado basado en tu día" : coachText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Button {
                    Task { await askCoach() }
                } label: {
                    if loadingCoach {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Pedir consejo").frame(maxWidth: .infinity)
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(Color(red: 0.68, green: 0.66, blue: 1))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    LinearGradient(
                        colors: [Brand.violet.opacity(0.32), Color(red: 0.35, green: 0.34, blue: 0.84).opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 11)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Brand.violet.opacity(0.35), lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .appSurface(tint: Brand.violet, padding: 16)
        }
    }

    private var buffetCard: some View {
        Button(action: onStartBuffet) {
            HStack(spacing: 14) {
                IconBadge(systemName: "takeoutbag.and.cup.and.straw.fill", color: Brand.red, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    EyebrowLabel(text: "Sesión buffet", color: Brand.red)
                    Text("Iniciar sesión de buffet")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Cuenta piezas · IA calcula nutrición")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title)
                    .foregroundStyle(Brand.red)
            }
            .appSurface(tint: Brand.red, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private var hydrationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    EyebrowLabel(text: "Hidratación")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(summary.waterMilliliters)").font(.title.bold())
                        Text("ml").foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(min(Int(Double(summary.waterMilliliters) / Double(waterGoal) * 100), 100))%")
                    .font(.headline.bold())
                    .padding(10)
                    .background(Brand.cyan.opacity(0.12), in: Circle())
                    .overlay { Circle().stroke(Brand.cyan.opacity(0.35), lineWidth: 1) }
            }
            AnimatedWaterBar(value: summary.waterMilliliters, goal: waterGoal)
            HStack(spacing: 12) {
                Button("-250 ml") { removeWater() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(summary.waterMilliliters == 0)
                Button("+250 ml") {
                    modelContext.insert(WaterEntry(date: selectedDate, milliliters: 250))
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.blue)
                .frame(maxWidth: .infinity)
            }
        }
        .appSurface(tint: Brand.cyan, padding: 18, radius: 26)
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "Peso", color: .primary)
            if let latestWeight {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f", latestWeight.kilograms)).font(.title.bold())
                    Text("kg").foregroundStyle(.secondary)
                    Spacer()
                    Text(latestWeight.date, format: .dateTime.day().month())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sin datos").foregroundStyle(.secondary)
            }
            Button {
                weight = profile?.currentWeightKG ?? 70
                showingWeight = true
            } label: {
                Label("Registrar peso de hoy", systemImage: "scalemass.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.elevatedSurface)
        }
        .appSurface()
    }

    private var mealsSection: some View {
        VStack(spacing: 12) {
            SectionHeading(title: "Comidas de hoy", actionTitle: "Añadir", action: onAddMeal)
            if dayMeals.isEmpty {
                VStack(spacing: 12) {
                    IconBadge(systemName: "camera.fill", color: Brand.orange, size: 54)
                    Text("Sin comidas hoy").font(.title3.bold())
                    Text("Haz una foto y deja que la IA estime calorías y macros.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: onAddMeal) {
                        Text("Registrar comida")
                            .font(.headline)
                            .padding(.horizontal, 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .appSurface()
            } else {
                ForEach(MealType.allCases) { type in
                    let entries = dayMeals.filter { $0.mealType == type }
                    if !entries.isEmpty {
                        VStack(spacing: 0) {
                            HStack {
                                Label(type.rawValue, systemImage: type.icon).font(.headline)
                                Spacer()
                                Text("\(Int(entries.reduce(0) { $0 + $1.calories })) kcal")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Brand.orange)
                            }
                            .padding(.bottom, 12)
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, meal in
                                if index > 0 { Divider() }
                                HStack(spacing: 12) {
                                    if let image = MediaStore.image(named: meal.imageFilename) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 58, height: 58)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } else {
                                        IconBadge(systemName: type.icon, color: Brand.orange, size: 46)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(meal.name).fontWeight(.semibold)
                                        Text(meal.serving).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 7) {
                                        Text("\(Int(meal.calories)) kcal").font(.subheadline)
                                        Button(role: .destructive) {
                                            mealToDelete = meal
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption.bold())
                                        }
                                        .buttonStyle(.borderless)
                                        .accessibilityLabel("Eliminar \(meal.name)")
                                    }
                                }
                                .padding(.vertical, 11)
                                .contextMenu {
                                    Button("Eliminar", systemImage: "trash", role: .destructive) { mealToDelete = meal }
                                }
                            }
                        }
                        .appSurface()
                    }
                }
            }
        }
    }

    private var streak: Int {
        let calendar = Calendar.current
        let loggedDays = Set(meals.map { calendar.startOfDay(for: $0.date) })
        var count = 0
        var cursor = calendar.startOfDay(for: .now)
        while loggedDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private var weightSheet: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 18) {
                    IconBadge(systemName: "scalemass.fill", color: Brand.orange, size: 60)
                    TextField("Peso", value: $weight, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .appSurface()
                    Text("kilogramos").foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Registrar peso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingWeight = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        modelContext.insert(WeightEntry(date: selectedDate, kilograms: weight))
                        profile?.currentWeightKG = weight
                        showingWeight = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func removeWater() {
        if let latest = waterEntries.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.milliliters > 0
        }) {
            if latest.milliliters <= 250 {
                modelContext.delete(latest)
            } else {
                latest.milliliters -= 250
            }
        }
    }

    private func askCoach() async {
        guard let profile else { return }
        loadingCoach = true
        defer { loadingCoach = false }
        let text = "\(Int(summary.calories)) kcal, \(Int(summary.protein)) g proteína, \(summary.waterMilliliters) ml de agua; objetivo \(targets.calories) kcal."
        do {
            coachText = try await GeminiService().coach(summary: text, profileName: profile.name)
        } catch {
            coachText = error.localizedDescription
        }
    }
}
