import SwiftUI
import SwiftData
import Charts

private enum HistoryMode: String, CaseIterable, Identifiable {
    case calendar = "Calendario"
    case week = "Semana"
    var id: String { rawValue }
}

struct HistoryView: View {
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Query(sort: \WaterEntry.date) private var waterEntries: [WaterEntry]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query(sort: \BuffetSession.startedAt) private var buffetSessions: [BuffetSession]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var mode = HistoryMode.calendar
    @State private var mealToDelete: MealEntry?

    private var calendar: Calendar {
        var value = Calendar.current
        value.firstWeekday = 2
        return value
    }
    private var calorieTarget: Int {
        profiles.first.map { NutritionCalculator.targets(for: $0).calories } ?? 2_000
    }
    private var selectedSummary: DailySummary { summary(for: selectedDate) }
    private var selectedMeals: [MealEntry] {
        meals.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    Picker("Vista", selection: $mode) {
                        ForEach(HistoryMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if mode == .calendar {
                        monthCard
                    } else {
                        weekCard
                        weekChart
                    }
                    daySummary
                    achievementsCard
                    hydrationCard
                    selectedDayMeals
                    if !weights.isEmpty { weightChart }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
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
            Text("Se eliminarán la comida y su fotografía local.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Text("Historial")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left").frame(width: 38, height: 38)
                        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                Spacer()
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right").frame(width: 38, height: 38)
                        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Brand.border, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .disabled(calendar.compare(displayedMonth, to: .now, toGranularity: .month) != .orderedAscending)
            }
        }
        .padding(.top, 10)
    }

    private var monthCard: some View {
        VStack(spacing: 14) {
            HStack {
                ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 10) {
                ForEach(Array(monthSlots.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear.frame(height: 47)
                    }
                }
            }
            Divider()
            HStack(spacing: 14) {
                legend(color: Brand.orange, text: "Registrado")
                legend(color: Brand.red, text: "Excedido")
                legend(color: Brand.blue, text: "Agua")
            }
        }
        .appSurface(padding: 16, radius: 26)
    }

    private func dayButton(_ day: Date) -> some View {
        let daySummary = summary(for: day)
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 5) {
                Text(day, format: .dateTime.day())
                    .font(.subheadline.weight(selected || today ? .bold : .medium))
                    .foregroundStyle(selected ? Brand.orange : .primary)
                HStack(spacing: 3) {
                    if daySummary.calories > 0 {
                        Circle().fill(daySummary.exceededTarget ? Brand.red : Brand.orange).frame(width: 5, height: 5)
                    }
                    if daySummary.waterMilliliters > 0 {
                        Circle().fill(Brand.blue).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 47)
            .background(selected ? Brand.orange.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 12).stroke(Brand.orange.opacity(0.45), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var weekCard: some View {
        WeekStrip(selectedDate: $selectedDate)
    }

    private var weekChart: some View {
        let week = calendar.calTrackerWeek(containing: selectedDate)
        return VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "Calorías de la semana", color: .primary)
            Chart(week, id: \.self) { day in
                BarMark(
                    x: .value("Día", day, unit: .day),
                    y: .value("Calorías", summary(for: day).calories)
                )
                .foregroundStyle(summary(for: day).exceededTarget ? Brand.red.gradient : Brand.orange.gradient)
                .cornerRadius(5)
                RuleMark(y: .value("Objetivo", calorieTarget))
                    .foregroundStyle(.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(dash: [4]))
            }
            .frame(height: 190)
        }
        .appSurface()
    }

    private var daySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.headline)
                Spacer()
                Text("\(Int(selectedSummary.calories)) kcal")
                    .font(.headline)
                    .foregroundStyle(Brand.orange)
            }
            HStack {
                Text("\(selectedMeals.count) \(selectedMeals.count == 1 ? "comida" : "comidas")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Objetivo: \(calorieTarget) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: selectedSummary.calories, total: Double(max(calorieTarget, 1)))
                .tint(selectedSummary.exceededTarget ? Brand.red : Brand.orange)
        }
        .appSurface()
    }

    private var hydrationCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    EyebrowLabel(text: "Agua", color: .secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(selectedSummary.waterMilliliters)").font(.title.bold())
                        Text("ml").foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(min(Int(Double(selectedSummary.waterMilliliters) / 2500 * 100), 100))%")
                    .font(.headline.bold())
                    .padding(10)
                    .background(Brand.cyan.opacity(0.14), in: Circle())
            }
            AnimatedWaterBar(value: selectedSummary.waterMilliliters, goal: 2_500)
        }
        .appSurface()
    }

    private var achievementsCard: some View {
        HStack(spacing: 10) {
            achievement(value: "\(currentStreak)", label: "Racha", systemName: "flame.fill", color: Brand.orange)
            achievement(value: "\(hydrationDays)", label: "Hidratación", systemName: "drop.fill", color: Brand.cyan)
            achievement(value: "\(completedBuffets)", label: "Buffets", systemName: "takeoutbag.and.cup.and.straw.fill", color: Brand.violet)
        }
        .appSurface()
    }

    private func achievement(value: String, label: String, systemName: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName).foregroundStyle(color)
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedDayMeals: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Comidas", color: .primary)
            if selectedMeals.isEmpty {
                Text("No hay comidas guardadas este día.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(selectedMeals.enumerated()), id: \.element.id) { index, meal in
                    if index > 0 { Divider() }
                    HStack(spacing: 12) {
                        if let image = MediaStore.image(named: meal.imageFilename) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            IconBadge(systemName: meal.mealType.icon, color: Brand.orange, size: 42)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(meal.name).fontWeight(.semibold)
                            Text(meal.mealType.rawValue).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 7) {
                            Text("\(Int(meal.calories)) kcal").font(.subheadline.bold())
                            Button(role: .destructive) {
                                mealToDelete = meal
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 7)
                }
            }
        }
        .appSurface()
    }

    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "Evolución del peso", color: .primary)
            Chart(weights.suffix(30)) { entry in
                LineMark(x: .value("Fecha", entry.date), y: .value("Peso", entry.kilograms))
                    .foregroundStyle(Brand.orange)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Fecha", entry.date), y: .value("Peso", entry.kilograms))
                    .foregroundStyle(Brand.orange)
            }
            .frame(height: 180)
        }
        .appSurface()
    }

    private var monthSlots: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let days = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let first = interval.start
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + days.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: first)
        }.map(Optional.some)
    }

    private func summary(for date: Date) -> DailySummary {
        DailySummary.make(
            date: date,
            meals: meals.map { NutritionSnapshot(date: $0.date, calories: $0.calories, protein: $0.protein, carbohydrates: $0.carbohydrates, fat: $0.fat) },
            water: waterEntries.map { WaterSnapshot(date: $0.date, milliliters: $0.milliliters) },
            calorieTarget: calorieTarget,
            calendar: calendar
        )
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var currentStreak: Int {
        let days = Set(meals.map { calendar.startOfDay(for: $0.date) })
        var count = 0
        var cursor = calendar.startOfDay(for: .now)
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private var hydrationDays: Int {
        let totals = Dictionary(grouping: waterEntries, by: { calendar.startOfDay(for: $0.date) })
            .mapValues { $0.reduce(0) { $0 + $1.milliliters } }
        return totals.values.filter { $0 >= 2_500 }.count
    }

    private var completedBuffets: Int {
        buffetSessions.filter { $0.completedAt != nil }.count
    }
}
