import SwiftUI
import SwiftData

struct PlanView: View {
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Query(sort: \MealPlanEntry.date) private var planEntries: [MealPlanEntry]
    @Query(sort: \ShoppingItem.createdAt) private var shoppingItems: [ShoppingItem]
    @Environment(\.modelContext) private var modelContext
    @State private var section = 0
    @State private var showingRecipe = false
    @State private var showingPlanEntry = false
    @State private var shoppingName = ""
    @State private var shoppingQuantity = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sección", selection: $section) {
                Text("Semana").tag(0)
                Text("Recetas").tag(1)
                Text("Compra").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if section == 0 { weekPlan }
                    else if section == 1 { recipeList }
                    else { shoppingList }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    section == 0 ? (showingPlanEntry = true) : (showingRecipe = section == 1)
                } label: { Image(systemName: "plus") }
                .disabled(section == 2)
            }
        }
        .sheet(isPresented: $showingRecipe) { RecipeEditorView() }
        .sheet(isPresented: $showingPlanEntry) { PlanEntryEditorView(recipes: recipes) }
    }

    private var weekPlan: some View {
        ForEach(nextSevenDays(), id: \.self) { day in
            let entries = planEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            VStack(alignment: .leading, spacing: 10) {
                Text(day, format: .dateTime.weekday(.wide).day().month()).font(.headline)
                if entries.isEmpty {
                    Text("Sin comidas planificadas").foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        HStack {
                            Image(systemName: entry.mealType.icon).foregroundStyle(Brand.blue)
                            VStack(alignment: .leading) {
                                Text(entry.title).fontWeight(.semibold)
                                Text(entry.mealType.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contextMenu {
                            Button("Eliminar", systemImage: "trash", role: .destructive) { modelContext.delete(entry) }
                        }
                    }
                }
            }
            .glassCard()
        }
    }

    private var recipeList: some View {
        Group {
            if recipes.isEmpty {
                ContentUnavailableView("Aún no hay recetas", systemImage: "book.closed", description: Text("Crea recetas para planificarlas y registrarlas."))
                    .glassCard()
            } else {
                ForEach(recipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.name).font(.headline).foregroundStyle(.primary)
                                Text("\(Int(recipe.caloriesPerServing)) kcal · \(recipe.servings) raciones")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var shoppingList: some View {
        VStack(spacing: 14) {
            HStack {
                TextField("Ingrediente", text: $shoppingName)
                TextField("Cantidad", text: $shoppingQuantity).frame(maxWidth: 100)
                Button {
                    guard !shoppingName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    modelContext.insert(ShoppingItem(name: shoppingName, quantity: shoppingQuantity))
                    shoppingName = ""
                    shoppingQuantity = ""
                } label: { Image(systemName: "plus.circle.fill") }
            }
            .glassCard()

            if shoppingItems.isEmpty {
                ContentUnavailableView("Lista vacía", systemImage: "cart", description: Text("Añade los ingredientes que necesitas."))
                    .glassCard()
            } else {
                ForEach(shoppingItems) { item in
                    HStack {
                        Button {
                            item.isCompleted.toggle()
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isCompleted ? Brand.green : .secondary)
                        }
                        VStack(alignment: .leading) {
                            Text(item.name).strikethrough(item.isCompleted)
                            if !item.quantity.isEmpty { Text(item.quantity).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Button(role: .destructive) { modelContext.delete(item) } label: { Image(systemName: "trash") }
                    }
                    .glassCard()
                }
            }
        }
    }

    private func nextSevenDays() -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: .now)) }
    }
}

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var details = ""
    @State private var servings = 1
    @State private var calories = 0.0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var ingredients = ""
    @State private var instructions = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Receta") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción", text: $details, axis: .vertical)
                    Stepper("Raciones: \(servings)", value: $servings, in: 1...30)
                }
                Section("Por ración") {
                    numeric("Calorías", $calories, "kcal")
                    numeric("Proteína", $protein, "g")
                    numeric("Carbohidratos", $carbs, "g")
                    numeric("Grasa", $fat, "g")
                }
                Section("Ingredientes, uno por línea") { TextEditor(text: $ingredients).frame(minHeight: 120) }
                Section("Preparación") { TextEditor(text: $instructions).frame(minHeight: 120) }
            }
            .navigationTitle("Nueva receta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        modelContext.insert(Recipe(name: name, details: details, servings: servings, caloriesPerServing: calories, proteinPerServing: protein, carbsPerServing: carbs, fatPerServing: fat, ingredientsText: ingredients, instructionsText: instructions))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func numeric(_ title: String, _ value: Binding<Double>, _ unit: String) -> some View {
        LabeledContent(title) {
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1))).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}

struct PlanEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let recipes: [Recipe]
    @State private var date = Date()
    @State private var type = MealType.lunch
    @State private var title = ""
    @State private var selectedRecipe = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Día", selection: $date, displayedComponents: .date)
                Picker("Momento", selection: $type) { ForEach(MealType.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Comida", text: $title)
                if !recipes.isEmpty {
                    Picker("Usar receta", selection: $selectedRecipe) {
                        Text("Ninguna").tag("")
                        ForEach(recipes) { Text($0.name).tag($0.name) }
                    }
                    .onChange(of: selectedRecipe) { _, value in if !value.isEmpty { title = value } }
                }
            }
            .navigationTitle("Planificar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        modelContext.insert(MealPlanEntry(date: date, mealType: type, title: title, recipeName: selectedRecipe.nilIfEmpty))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let recipe: Recipe

    var body: some View {
        List {
            Section {
                LabeledContent("Calorías", value: "\(Int(recipe.caloriesPerServing)) kcal")
                LabeledContent("Proteína", value: "\(Int(recipe.proteinPerServing)) g")
                LabeledContent("Carbohidratos", value: "\(Int(recipe.carbsPerServing)) g")
                LabeledContent("Grasa", value: "\(Int(recipe.fatPerServing)) g")
            } header: { Text("Por ración") }
            Section("Ingredientes") { Text(recipe.ingredientsText) }
            Section("Preparación") { Text(recipe.instructionsText) }
            Section {
                Button {
                    modelContext.insert(MealEntry(name: recipe.name, mealType: .lunch, calories: recipe.caloriesPerServing, protein: recipe.proteinPerServing, carbohydrates: recipe.carbsPerServing, fat: recipe.fatPerServing, source: "recipe"))
                } label: { Label("Registrar una ración", systemImage: "plus.circle.fill") }
            }
        }
        .navigationTitle(recipe.name)
    }
}
