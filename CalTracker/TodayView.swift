import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var waterEntries: [WaterEntry]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var showingWeight = false
    @State private var weight = 70.0
    let onAddMeal: () -> Void

    private var profile: UserProfile? { profiles.first }
    private var dayMeals: [MealEntry] { meals.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    private var dayWater: Int { waterEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }.reduce(0) { $0 + $1.milliliters } }
    private var calories: Double { dayMeals.reduce(0) { $0 + $1.calories } }
    private var protein: Double { dayMeals.reduce(0) { $0 + $1.protein } }
    private var carbs: Double { dayMeals.reduce(0) { $0 + $1.carbohydrates } }
    private var fat: Double { dayMeals.reduce(0) { $0 + $1.fat } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                dateHeader
                if let profile {
                    let targets = NutritionCalculator.targets(for: profile)
                    HStack {
                        CalorieRing(consumed: calories, goal: Double(targets.calories))
                        VStack(spacing: 14) {
                            MacroBar(name: "Proteína", value: protein, target: Double(targets.protein), color: Brand.orange)
                            MacroBar(name: "Carbohidratos", value: carbs, target: Double(targets.carbohydrates), color: Brand.blue)
                            MacroBar(name: "Grasa", value: fat, target: Double(targets.fat), color: Brand.green)
                        }
                    }
                    .glassCard()
                }
                quickMetrics
                mealSections
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(profile.map { "Hola, \($0.name)" } ?? "Hoy")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddMeal) { Image(systemName: "plus") }
                    .accessibilityLabel("Registrar comida")
            }
        }
        .sheet(isPresented: $showingWeight) {
            NavigationStack {
                Form {
                    TextField("Peso", value: $weight, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                }
                .navigationTitle("Registrar peso")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingWeight = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") {
                            modelContext.insert(WeightEntry(kilograms: weight))
                            profile?.currentWeightKG = weight
                            showingWeight = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var dateHeader: some View {
        HStack {
            Button { selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            VStack {
                Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.headline)
                if !Calendar.current.isDateInToday(selectedDate) {
                    Button("Volver a hoy") { selectedDate = .now }.font(.caption)
                }
            }
            Spacer()
            Button { selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
    }

    private var quickMetrics: some View {
        HStack(spacing: 12) {
            Button {
                modelContext.insert(WaterEntry(milliliters: 250))
            } label: {
                metric(icon: "drop.fill", color: .cyan, value: "\(dayWater) ml", label: "Agua +250")
            }
            .buttonStyle(.plain)
            Button {
                weight = profile?.currentWeightKG ?? 70
                showingWeight = true
            } label: {
                metric(icon: "scalemass.fill", color: Brand.orange, value: profile.map { String(format: "%.1f kg", $0.currentWeightKG) } ?? "--", label: "Peso")
            }
            .buttonStyle(.plain)
        }
    }

    private func metric(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.title2)
            Text(value).font(.title3.bold()).foregroundStyle(.primary)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var mealSections: some View {
        ForEach(MealType.allCases) { type in
            let entries = dayMeals.filter { $0.mealType == type }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(type.rawValue, systemImage: type.icon).font(.headline)
                    Spacer()
                    Text("\(Int(entries.reduce(0) { $0 + $1.calories })) kcal").foregroundStyle(.secondary)
                }
                if entries.isEmpty {
                    Button(action: onAddMeal) {
                        Label("Añadir \(type.rawValue.lowercased())", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(entries) { meal in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(meal.name).fontWeight(.semibold)
                                Text(meal.serving).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(meal.calories)) kcal")
                        }
                        .contextMenu {
                            Button("Eliminar", systemImage: "trash", role: .destructive) { modelContext.delete(meal) }
                        }
                    }
                }
            }
            .glassCard()
        }
    }
}
