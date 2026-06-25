import SwiftUI
import SwiftData

private enum BuffetCategory: String, CaseIterable, Identifiable {
    case nigiri, maki, tempura, gyoza, dessert, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nigiri: "Nigiri"
        case .maki: "Maki"
        case .tempura: "Tempura"
        case .gyoza: "Gyoza"
        case .dessert: "Postre"
        case .other: "Otros"
        }
    }
    var emoji: String {
        switch self {
        case .nigiri: "🍣"
        case .maki: "🌀"
        case .tempura: "🍤"
        case .gyoza: "🥟"
        case .dessert: "🍡"
        case .other: "🍱"
        }
    }
}

struct BuffetSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: BuffetSession
    @State private var showingFinish = false
    @State private var analyzing = false
    @State private var errorMessage: String?

    private var estimate: BuffetEstimate {
        BuffetEstimator.estimate(totalPieces: session.totalPieces, breakdown: session.breakdown)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.19, green: 0.01, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header
                    totalCounter
                    categoryGrid
                    estimateCard
                    finishButton
                    Button("Terminar sin guardar", role: .destructive) {
                        modelContext.delete(session)
                        dismiss()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .padding(.bottom, 24)
            }
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showingFinish) { finishSheet }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                EyebrowLabel(text: "Buffet de sushi", color: Brand.red)
                Text("Buffet en curso").font(.title.bold())
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(durationText(context.date.timeIntervalSince(session.startedAt)))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
        }
    }

    private var totalCounter: some View {
        VStack(spacing: 14) {
            Text("🍣").font(.system(size: 58))
            Text("\(session.totalPieces)")
                .font(.system(size: 86, weight: .black, design: .rounded))
                .contentTransition(.numericText())
            Text(session.totalPieces == 1 ? "pieza" : "piezas")
                .font(.headline).foregroundStyle(.secondary)
            HStack(spacing: 20) {
                counterButton(systemName: "minus", enabled: session.totalPieces > 0) {
                    session.totalPieces = max(0, session.totalPieces - 1)
                }
                counterButton(systemName: "plus", enabled: true) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                        session.totalPieces += 1
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .appSurface(tint: Brand.red, padding: 24, radius: 28)
    }

    private func counterButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.bold())
                .frame(width: 62, height: 62)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(systemName == "plus" ? Brand.red : Brand.elevatedSurface)
        .disabled(!enabled)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(BuffetCategory.allCases) { category in
                VStack(spacing: 10) {
                    Text(category.emoji).font(.title)
                    Text(category.title).font(.subheadline.bold())
                    HStack {
                        Button { adjust(category, by: -1) } label: { Image(systemName: "minus.circle") }
                            .disabled(value(for: category) == 0)
                        Text("\(value(for: category))")
                            .font(.title3.bold().monospacedDigit())
                            .frame(minWidth: 28)
                        Button { adjust(category, by: 1) } label: { Image(systemName: "plus.circle.fill") }
                    }
                }
                .frame(maxWidth: .infinity)
                .appSurface(padding: 14, radius: 18)
            }
        }
    }

    private var estimateCard: some View {
        VStack(spacing: 14) {
            EyebrowLabel(text: "Estimación local · \(session.totalPieces) piezas", color: .secondary)
            HStack {
                estimateMetric("Calorías", "\(estimate.calories)", "kcal", Brand.orange)
                estimateMetric("Proteína", "\(estimate.protein)", "g", Brand.green)
                estimateMetric("Carbos", "\(estimate.carbohydrates)", "g", Brand.cyan)
                estimateMetric("Grasa", "\(estimate.fat)", "g", .yellow)
            }
        }
        .appSurface()
    }

    private func estimateMetric(_ label: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline.bold()).foregroundStyle(color)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
            Text(label.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var finishButton: some View {
        Button {
            showingFinish = true
        } label: {
            Label("Finalizar sesión", systemImage: "flag.checkered")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .buttonStyle(.borderedProminent)
        .tint(Brand.red)
        .disabled(session.totalPieces == 0)
    }

    private var finishSheet: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Text("¿Cómo quieres calcularla?")
                            .font(.title2.bold())
                        Text("Puedes usar Gemini para una estimación contextual o guardar la fórmula local por categorías.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(Brand.red).appSurface(tint: Brand.red)
                        }
                        Button {
                            Task { await finish(usingGemini: true) }
                        } label: {
                            Label(analyzing ? "Analizando…" : "Usar Gemini", systemImage: "sparkles")
                                .frame(maxWidth: .infinity).frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.violet)
                        .disabled(analyzing || KeychainStore.geminiKey() == nil)
                        Button {
                            Task { await finish(usingGemini: false) }
                        } label: {
                            Label("Usar estimación local", systemImage: "chart.bar.fill")
                                .frame(maxWidth: .infinity).frame(height: 50)
                        }
                        .buttonStyle(.bordered)
                        .disabled(analyzing)
                    }
                    .padding()
                }
            }
            .navigationTitle("Finalizar buffet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showingFinish = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func finish(usingGemini: Bool) async {
        analyzing = true
        defer { analyzing = false }
        do {
            let result: BuffetAnalysisResult
            if usingGemini {
                result = try await GeminiService().analyzeBuffet(
                    pieces: session.totalPieces,
                    breakdown: session.breakdown,
                    durationMinutes: max(1, Int(Date().timeIntervalSince(session.startedAt) / 60))
                )
            } else {
                result = BuffetAnalysisResult(
                    calories: estimate.calories,
                    protein: estimate.protein,
                    carbohydrates: estimate.carbohydrates,
                    fat: estimate.fat,
                    summary: "Estimación local basada en el tipo y número de piezas.",
                    modelUsed: "Estimación local"
                )
            }
            session.calories = result.calories
            session.protein = result.protein
            session.carbohydrates = result.carbohydrates
            session.fat = result.fat
            session.summary = result.summary
            session.usedGemini = usingGemini
            session.completedAt = .now

            let meal = MealEntry(
                name: "Buffet de sushi · \(session.totalPieces) piezas",
                mealType: .dinner,
                calories: Double(result.calories),
                protein: Double(result.protein),
                carbohydrates: Double(result.carbohydrates),
                fat: Double(result.fat),
                serving: "\(session.totalPieces) piezas",
                source: "buffet"
            )
            meal.analysisNotes = result.summary
            meal.analysisModel = result.modelUsed
            modelContext.insert(meal)
            session.savedMealID = meal.persistentModelID.hashValue.description
            try modelContext.save()
            showingFinish = false
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func value(for category: BuffetCategory) -> Int {
        switch category {
        case .nigiri: session.nigiri
        case .maki: session.maki
        case .tempura: session.tempura
        case .gyoza: session.gyoza
        case .dessert: session.dessert
        case .other: session.other
        }
    }

    private func adjust(_ category: BuffetCategory, by delta: Int) {
        let previous = value(for: category)
        let next = max(0, previous + delta)
        let applied = next - previous
        switch category {
        case .nigiri: session.nigiri = next
        case .maki: session.maki = next
        case .tempura: session.tempura = next
        case .gyoza: session.gyoza = next
        case .dessert: session.dessert = next
        case .other: session.other = next
        }
        session.totalPieces = max(session.breakdown.classifiedTotal, session.totalPieces + applied)
    }

    private func durationText(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
