import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Query(sort: \MealEntry.date) private var meals: [MealEntry]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var profiles: [UserProfile]
    @State private var selectedDate = Date()

    private var calendar: Calendar { .current }
    private var week: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                weekPicker
                let weekMeals = meals.filter { meal in week.contains { calendar.isDate($0, inSameDayAs: meal.date) } }
                HStack(spacing: 12) {
                    summary(title: "Media diaria", value: "\(dailyAverage(weekMeals))", unit: "kcal", icon: "flame.fill", color: Brand.orange)
                    summary(title: "Días registrados", value: "\(Set(weekMeals.map { calendar.startOfDay(for: $0.date) }).count)", unit: "de 7", icon: "calendar.badge.checkmark", color: Brand.green)
                }
                calorieChart(weekMeals)
                if !weights.isEmpty { weightChart }
                selectedDayMeals
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Historial")
    }

    private var weekPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(selectedDate, format: .dateTime.month(.wide).year()).font(.headline)
                Spacer()
                Button { selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate } label: { Image(systemName: "chevron.right") }
                    .disabled(week.last.map { $0 >= Date() } ?? true)
            }
            HStack {
                ForEach(week, id: \.self) { date in
                    Button { selectedDate = date } label: {
                        VStack(spacing: 7) {
                            Text(date, format: .dateTime.weekday(.narrow)).font(.caption2.weight(.semibold))
                            Text(date, format: .dateTime.day())
                                .font(.subheadline.bold())
                                .frame(width: 34, height: 34)
                                .background(calendar.isDate(date, inSameDayAs: selectedDate) ? Brand.blue : Color.clear, in: Circle())
                                .foregroundStyle(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassCard()
    }

    private func summary(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.title2)
            Text(value).font(.title2.bold())
            Text(unit).font(.caption).foregroundStyle(.secondary)
            Text(title).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func calorieChart(_ weekMeals: [MealEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calorías esta semana").font(.headline)
            Chart(week, id: \.self) { day in
                let value = weekMeals.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.calories }
                BarMark(x: .value("Día", day, unit: .day), y: .value("Calorías", value))
                    .foregroundStyle(Brand.blue.gradient)
                    .cornerRadius(4)
                if let target = profiles.first.map({ NutritionCalculator.targets(for: $0).calories }) {
                    RuleMark(y: .value("Objetivo", target))
                        .foregroundStyle(Brand.orange)
                        .lineStyle(StrokeStyle(dash: [4]))
                }
            }
            .frame(height: 190)
        }
        .glassCard()
    }

    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Evolución del peso").font(.headline)
            Chart(weights.suffix(30)) { entry in
                LineMark(x: .value("Fecha", entry.date), y: .value("Peso", entry.kilograms))
                    .foregroundStyle(Brand.orange)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Fecha", entry.date), y: .value("Peso", entry.kilograms))
                    .foregroundStyle(Brand.orange)
            }
            .frame(height: 180)
        }
        .glassCard()
    }

    private var selectedDayMeals: some View {
        let entries = meals.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Detalle del día").font(.headline)
            if entries.isEmpty {
                ContentUnavailableView("Sin registros", systemImage: "fork.knife", description: Text("No hay comidas guardadas este día."))
            } else {
                ForEach(entries) { meal in
                    HStack {
                        Text(meal.name)
                        Spacer()
                        Text("\(Int(meal.calories)) kcal").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .glassCard()
    }

    private func dailyAverage(_ entries: [MealEntry]) -> Int {
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) }).count
        return days == 0 ? 0 : Int(entries.reduce(0) { $0 + $1.calories }) / days
    }
}
