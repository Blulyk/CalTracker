import SwiftUI
import SwiftData
import PhotosUI

private enum PlanSection: String, CaseIterable, Identifiable {
    case recipes = "Recetas"
    case week = "Semana"
    case shopping = "Compra"
    var id: String { rawValue }
}

struct PlanView: View {
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Query(sort: \MealPlanEntry.date) private var planEntries: [MealPlanEntry]
    @Query(sort: \ShoppingItem.createdAt) private var shoppingItems: [ShoppingItem]
    @Environment(\.modelContext) private var modelContext
    @State private var section = PlanSection.recipes
    @State private var showingRecipe = false
    @State private var showingImport = false
    @State private var showingPlanEntry = false
    @State private var search = ""
    @State private var shoppingName = ""
    @State private var shoppingQuantity = ""

    private var filteredRecipes: [Recipe] {
        guard !search.isEmpty else { return recipes }
        return recipes.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.ingredientsText.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                header
                Picker("Sección", selection: $section) {
                    ForEach(PlanSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        switch section {
                        case .recipes: recipeList
                        case .week: weekPlan
                        case .shopping: shoppingList
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingRecipe) { RecipeEditorView() }
        .sheet(isPresented: $showingImport) { RecipeImportView() }
        .sheet(isPresented: $showingPlanEntry) { PlanEntryEditorView(recipes: recipes) }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.rawValue).font(.largeTitle.bold())
                    Text(section == .recipes ? "\(recipes.count) recetas" : section == .week ? "Organiza tus próximos días" : "\(shoppingItems.filter { !$0.isCompleted }.count) pendientes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if section == .recipes {
                    HStack(spacing: 8) {
                        headerButton("Calendario", systemName: "calendar") { section = .week }
                        headerButton("Importar", systemName: "link") { showingImport = true }
                        headerButton("Nueva", systemName: "plus") { showingRecipe = true }
                    }
                } else if section == .week {
                    headerButton("Añadir", systemName: "plus") { showingPlanEntry = true }
                }
            }

            if section == .recipes {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar recetas e ingredientes", text: $search)
                        .textInputAutocapitalization(.never)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Brand.surface, in: RoundedRectangle(cornerRadius: 15))
                .overlay { RoundedRectangle(cornerRadius: 15).stroke(Brand.border, lineWidth: 1) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private func headerButton(_ label: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.bold())
                .foregroundStyle(Brand.orange)
                .frame(width: 40, height: 40)
                .appSurface(interactive: true, padding: 0, radius: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var recipeList: some View {
        if filteredRecipes.isEmpty {
            VStack(spacing: 14) {
                IconBadge(systemName: "book.closed.fill", color: Brand.orange, size: 62)
                Text(search.isEmpty ? "Tu recetario está vacío" : "No hay coincidencias")
                    .font(.title3.bold())
                Text(search.isEmpty ? "Crea recetas con sus macros para planificarlas y registrarlas en un toque." : "Prueba con otro nombre o ingrediente.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if search.isEmpty {
                    Button { showingRecipe = true } label: {
                        PrimaryActionLabel(title: "Crear primera receta", systemImage: "plus")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .appSurface()
        } else {
            ForEach(filteredRecipes) { recipe in
                recipeCard(recipe)
            }
        }
    }

    private func recipeCard(_ recipe: Recipe) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                RecipeDetailView(recipe: recipe)
            } label: {
                ZStack(alignment: .bottomLeading) {
                    if let image = MediaStore.image(named: recipe.imageFilename) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [Brand.orange.opacity(0.56), Brand.violet.opacity(0.26), Brand.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("\(recipe.servings) \(recipe.servings == 1 ? "ración" : "raciones")")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        Spacer()
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                    .padding(16)
                }
                .frame(height: 118)
                .clipped()
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 13) {
                Text("\(Int(recipe.caloriesPerServing)) kcal/ración")
                    .font(.headline)
                    .foregroundStyle(Brand.orange)
                HStack {
                    MetricChip(label: "P", value: "\(Int(recipe.proteinPerServing))g", color: Brand.protein)
                    MetricChip(label: "C", value: "\(Int(recipe.carbsPerServing))g", color: Brand.carb)
                    MetricChip(label: "G", value: "\(Int(recipe.fatPerServing))g", color: Brand.fat)
                }
                Button {
                    modelContext.insert(MealEntry(name: recipe.name, mealType: .lunch, calories: recipe.caloriesPerServing, protein: recipe.proteinPerServing, carbohydrates: recipe.carbsPerServing, fat: recipe.fatPerServing, source: "recipe"))
                } label: {
                    PrimaryActionLabel(title: "Añadir como comida", systemImage: "plus")
                }
            }
            .padding(16)
        }
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Brand.border, lineWidth: 1) }
        .contextMenu {
            Button("Eliminar", systemImage: "trash", role: .destructive) {
                MediaStore.delete(recipe.imageFilename)
                modelContext.delete(recipe)
            }
        }
    }

    private var weekPlan: some View {
        ForEach(nextSevenDays(), id: \.self) { day in
            let entries = planEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(day, format: .dateTime.weekday(.wide)).font(.headline)
                        Text(day, format: .dateTime.day().month(.wide)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(entries.count) comidas").font(.caption.bold()).foregroundStyle(Brand.orange)
                }
                if entries.isEmpty {
                    Button { showingPlanEntry = true } label: {
                        Label("Planificar este día", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(entries) { entry in
                        HStack(spacing: 12) {
                            IconBadge(systemName: entry.mealType.icon, color: Brand.orange, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
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
            .appSurface()
        }
    }

    private var shoppingList: some View {
        VStack(spacing: 14) {
            Button(action: generateShoppingList) {
                Label("Generar desde la semana", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.green)

            HStack(spacing: 10) {
                TextField("Ingrediente", text: $shoppingName)
                TextField("Cantidad", text: $shoppingQuantity).frame(maxWidth: 92)
                Button {
                    guard !shoppingName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    modelContext.insert(ShoppingItem(name: shoppingName, quantity: shoppingQuantity))
                    shoppingName = ""
                    shoppingQuantity = ""
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.bold())
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(Brand.orange)
            }
            .appSurface()

            if shoppingItems.isEmpty {
                VStack(spacing: 12) {
                    IconBadge(systemName: "cart.fill", color: Brand.orange, size: 58)
                    Text("Lista vacía").font(.title3.bold())
                    Text("Añade los ingredientes que necesitas.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .appSurface()
            } else {
                ForEach(shoppingItems) { item in
                    HStack(spacing: 12) {
                        Button { item.isCompleted.toggle() } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(item.isCompleted ? Brand.green : .secondary)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).fontWeight(.semibold).strikethrough(item.isCompleted)
                            if !item.quantity.isEmpty {
                                Text(item.quantity).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) { modelContext.delete(item) } label: { Image(systemName: "trash") }
                    }
                    .appSurface()
                }
            }
        }
    }

    private func nextSevenDays() -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: .now)) }
    }

    private func generateShoppingList() {
        let planned = planEntries.compactMap { entry -> PlannedIngredients? in
            guard let recipe = recipes.first(where: { $0.name == entry.recipeName }) else { return nil }
            return PlannedIngredients(text: recipe.ingredientsText, servings: entry.servings)
        }
        let existing = Set(shoppingItems.map { $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) })
        for suggestion in ShoppingListGenerator.suggestions(from: planned) {
            let key = suggestion.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !existing.contains(key) else { continue }
            modelContext.insert(ShoppingItem(name: suggestion.name, quantity: suggestion.quantity))
        }
    }
}

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name: String
    @State private var details: String
    @State private var servings: Int
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var fiber: Double
    @State private var ingredients: String
    @State private var instructions: String
    @State private var photoItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var errorMessage: String?
    private let sourceURL: String?
    private let onSaved: () -> Void

    init(
        importDraft: RecipeImportDraft? = nil,
        sourceURL: String? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        _name = State(initialValue: importDraft?.name ?? "")
        _details = State(initialValue: importDraft?.details ?? "")
        _servings = State(initialValue: importDraft?.servings ?? 1)
        _calories = State(initialValue: importDraft?.caloriesPerServing ?? 0)
        _protein = State(initialValue: importDraft?.proteinPerServing ?? 0)
        _carbs = State(initialValue: importDraft?.carbsPerServing ?? 0)
        _fat = State(initialValue: importDraft?.fatPerServing ?? 0)
        _fiber = State(initialValue: importDraft?.fiberPerServing ?? 0)
        _ingredients = State(initialValue: importDraft?.ingredientsText ?? "")
        _instructions = State(initialValue: importDraft?.instructionsText ?? "")
        self.sourceURL = sourceURL
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack {
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.largeTitle)
                                    Text("Añadir fotografía")
                                        .font(.headline)
                                }
                                .foregroundStyle(Brand.orange)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .onChange(of: photoItem) { _, item in
                        guard let item else { return }
                        Task {
                            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                            image = UIImage(data: data)
                        }
                    }
                }
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
                    numeric("Fibra", $fiber, "g")
                }
                Section("Ingredientes, uno por línea") { TextEditor(text: $ingredients).frame(minHeight: 120) }
                Section("Preparación") { TextEditor(text: $instructions).frame(minHeight: 120) }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Brand.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Nueva receta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func numeric(_ title: String, _ value: Binding<Double>, _ unit: String) -> some View {
        LabeledContent(title) {
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func save() {
        do {
            let recipe = Recipe(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                details: details,
                servings: servings,
                caloriesPerServing: calories,
                proteinPerServing: protein,
                carbsPerServing: carbs,
                fatPerServing: fat,
                ingredientsText: ingredients,
                instructionsText: instructions
            )
            recipe.fiberPerServing = fiber
            recipe.sourceURL = sourceURL
            if let image {
                recipe.imageFilename = try MediaStore.saveJPEG(image, prefix: "recipe")
            }
            modelContext.insert(recipe)
            try modelContext.save()
            dismiss()
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
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
    @State private var servings = 1.0

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
                Stepper(
                    "Raciones: \(servings.formatted(.number.precision(.fractionLength(0...1))))",
                    value: $servings,
                    in: 0.5...20,
                    step: 0.5
                )
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Planificar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let entry = MealPlanEntry(date: date, mealType: type, title: title, recipeName: selectedRecipe.nilIfEmpty)
                        entry.servings = servings
                        modelContext.insert(entry)
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
    @Bindable var recipe: Recipe
    @State private var photoItem: PhotosPickerItem?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        if let image = MediaStore.image(named: recipe.imageFilename) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            LinearGradient(colors: [Brand.orange.opacity(0.6), Brand.violet.opacity(0.3), Brand.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 82))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .clipped()
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(recipe.imageFilename == nil ? "Añadir foto" : "Cambiar foto", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    .onChange(of: photoItem) { _, item in
                        guard let item else { return }
                        Task { await updatePhoto(item) }
                    }
                    Text(recipe.details).foregroundStyle(.secondary)
                    HStack {
                        MetricChip(label: "P", value: "\(Int(recipe.proteinPerServing))g", color: Brand.protein)
                        MetricChip(label: "C", value: "\(Int(recipe.carbsPerServing))g", color: Brand.carb)
                        MetricChip(label: "G", value: "\(Int(recipe.fatPerServing))g", color: Brand.fat)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        EyebrowLabel(text: "Ingredientes", color: .primary)
                        Text(recipe.ingredientsText)
                    }
                    .appSurface()
                    if let sourceURL = recipe.sourceURL, let url = URL(string: sourceURL) {
                        Link(destination: url) {
                            Label("Abrir receta original", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(Brand.red)
                            .appSurface(tint: Brand.red)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        EyebrowLabel(text: "Preparación", color: .primary)
                        Text(recipe.instructionsText)
                    }
                    .appSurface()
                    Button {
                        modelContext.insert(MealEntry(name: recipe.name, mealType: .lunch, calories: recipe.caloriesPerServing, protein: recipe.proteinPerServing, carbohydrates: recipe.carbsPerServing, fat: recipe.fatPerServing, source: "recipe"))
                    } label: {
                        PrimaryActionLabel(title: "Registrar una ración", systemImage: "plus")
                    }
                }
                .padding()
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func updatePhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw ServiceError.imageEncoding
            }
            let oldFilename = recipe.imageFilename
            recipe.imageFilename = try MediaStore.saveJPEG(image, prefix: "recipe")
            try modelContext.save()
            MediaStore.delete(oldFilename)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
