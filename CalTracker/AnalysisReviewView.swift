import SwiftUI
import SwiftData

struct AnalysisReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: AnalysisDraft
    @State private var errorMessage: String?
    let image: UIImage?
    let onRepeat: () -> Void
    let onSaved: () -> Void

    init(
        draft: AnalysisDraft,
        image: UIImage?,
        onRepeat: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.image = image
        self.onRepeat = onRepeat
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        summaryCard
                        ForEach($draft.foods) { $food in
                            foodEditor(food: $food)
                        }
                        Button {
                            draft.foods.append(
                                DraftFood(
                                    name: "",
                                    portion: "1 ración",
                                    calories: 0,
                                    protein: 0,
                                    carbohydrates: 0,
                                    fat: 0,
                                    fiber: 0
                                )
                            )
                        } label: {
                            Label("Añadir alimento", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        VStack(alignment: .leading, spacing: 10) {
                            EyebrowLabel(text: "Notas", color: Brand.violet)
                            TextField("Observaciones del análisis", text: $draft.notes, axis: .vertical)
                                .lineLimit(2...5)
                        }
                        .appSurface()

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Brand.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appSurface(tint: Brand.red)
                        }

                        HStack(spacing: 12) {
                            Button {
                                dismiss()
                                onRepeat()
                            } label: {
                                Label("Repetir", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button(action: save) {
                                Label("Guardar comida", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Brand.blue)
                            .disabled(draft.foods.isEmpty || draft.foods.allSatisfy { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Revisar análisis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 86, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    IconBadge(systemName: "sparkles", color: Brand.violet, size: 58)
                }
                VStack(alignment: .leading, spacing: 5) {
                    EyebrowLabel(text: "Resultado revisable", color: Brand.violet)
                    Text(draft.displayName)
                        .font(.title3.bold())
                    Text("\(draft.confidence.rawValue) confianza · \(draft.modelUsed)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Picker("Momento", selection: $draft.mealType) {
                ForEach(MealType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 8) {
                totalMetric("kcal", draft.totalCalories, Brand.orange)
                totalMetric("P", draft.totalProtein, Brand.protein)
                totalMetric("C", draft.totalCarbohydrates, Brand.carb)
                totalMetric("G", draft.totalFat, Brand.fat)
            }
        }
        .appSurface(tint: Brand.violet, padding: 18, radius: 26)
    }

    private func totalMetric(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value, format: .number.precision(.fractionLength(0...1)))
                .font(.headline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func foodEditor(food: Binding<DraftFood>) -> some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Alimento", text: food.name)
                    .font(.headline)
                Button(role: .destructive) {
                    draft.foods.removeAll { $0.id == food.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            TextField("Ración", text: food.portion)
                .foregroundStyle(.secondary)
            Divider()
            HStack(spacing: 8) {
                nutrientField("kcal", value: food.calories)
                nutrientField("P", value: food.protein)
                nutrientField("C", value: food.carbohydrates)
                nutrientField("G", value: food.fat)
                nutrientField("Fibra", value: food.fiber)
            }
        }
        .appSurface()
    }

    private func nutrientField(_ label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        do {
            if let image {
                draft.imageFilename = try MediaStore.saveJPEG(image, prefix: "meal")
            }
            let meal = try MealEntry(draft: draft)
            modelContext.insert(meal)
            try modelContext.save()
            dismiss()
            onSaved()
        } catch {
            MediaStore.delete(draft.imageFilename)
            draft.imageFilename = nil
            errorMessage = error.localizedDescription
        }
    }
}
