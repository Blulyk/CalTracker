import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct LogView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var showingManual = false
    @State private var showingScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var analysis: FoodAnalysis?
    @State private var errorMessage: String?
    @State private var barcode = ""
    @State private var product: ProductLookup?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text("¿Qué quieres registrar?")
                    .font(.title2.bold())

                Button { showingManual = true } label: {
                    actionRow(icon: "square.and.pencil", color: Brand.blue, title: "Entrada manual", subtitle: "Control total de ración y nutrientes")
                }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    actionRow(icon: "camera.fill", color: Brand.orange, title: "Analizar una foto", subtitle: "Gemini propone alimentos editables")
                }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task { await analyze(item) }
                }

                Button { showingScanner = true } label: {
                    actionRow(icon: "barcode.viewfinder", color: Brand.green, title: "Escanear código", subtitle: "Consulta Open Food Facts")
                }

                if isAnalyzing {
                    HStack { ProgressView(); Text("Analizando la comida…") }.glassCard()
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).glassCard()
                }
                if let analysis {
                    analysisSection(analysis)
                }
                if let product {
                    productSection(product)
                }

                if !recipes.isEmpty {
                    Text("Recetas").font(.title3.bold())
                    ForEach(recipes.prefix(5)) { recipe in
                        Button {
                            modelContext.insert(MealEntry(name: recipe.name, mealType: suggestedMealType(), calories: recipe.caloriesPerServing, protein: recipe.proteinPerServing, carbohydrates: recipe.carbsPerServing, fat: recipe.fatPerServing, source: "recipe"))
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(recipe.name).fontWeight(.semibold)
                                    Text("\(Int(recipe.caloriesPerServing)) kcal por ración").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                            }
                            .glassCard()
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !meals.isEmpty {
                    Text("Recientes").font(.title3.bold())
                    ForEach(uniqueRecentMeals()) { meal in
                        Button {
                            modelContext.insert(MealEntry(name: meal.name, mealType: suggestedMealType(), calories: meal.calories, protein: meal.protein, carbohydrates: meal.carbohydrates, fat: meal.fat, fiber: meal.fiber, serving: meal.serving, source: "recent"))
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(meal.name).fontWeight(.semibold)
                                    Text(meal.serving).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(meal.calories)) kcal")
                                Image(systemName: "plus.circle")
                            }
                            .glassCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Registrar")
        .sheet(isPresented: $showingManual) { ManualMealView() }
        .sheet(isPresented: $showingScanner) {
            NavigationStack {
                BarcodeScannerView { code in
                    barcode = code
                    showingScanner = false
                    Task { await lookupBarcode() }
                }
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Escanear producto")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingScanner = false } }
                }
            }
        }
    }

    private func actionRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .glassCard()
    }

    private func analysisSection(_ result: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resultado de la foto").font(.headline)
            ForEach(result.foods) { food in
                HStack {
                    VStack(alignment: .leading) {
                        Text(food.name).fontWeight(.semibold)
                        Text(food.portion).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(food.calories)) kcal")
                    Button {
                        modelContext.insert(MealEntry(name: food.name, mealType: suggestedMealType(result.mealTypeSuggestion), calories: food.calories, protein: food.protein, carbohydrates: food.carbs, fat: food.fat, fiber: food.fiber ?? 0, serving: food.portion, source: "gemini"))
                    } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            if let notes = result.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary)
            }
        }
        .glassCard()
    }

    private func productSection(_ item: ProductLookup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Producto encontrado").font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name).fontWeight(.semibold)
                    Text(item.serving).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(item.calories)) kcal")
            }
            Button {
                modelContext.insert(MealEntry(name: item.name, mealType: suggestedMealType(), calories: item.calories, protein: item.protein, carbohydrates: item.carbohydrates, fat: item.fat, fiber: item.fiber, serving: item.serving, source: "open-food-facts"))
                product = nil
            } label: {
                Label("Añadir al día", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .glassCard()
    }

    private func analyze(_ item: PhotosPickerItem) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.78) else {
                throw ServiceError.imageEncoding
            }
            analysis = try await GeminiService().analyze(imageData: jpeg, profileName: profiles.first?.name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func lookupBarcode() async {
        errorMessage = nil
        do {
            product = try await OpenFoodFactsService().lookup(barcode: barcode)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func suggestedMealType(_ raw: String? = nil) -> MealType {
        if let raw, let exact = MealType(rawValue: raw) { return exact }
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: return .breakfast
        case 11..<16: return .lunch
        case 19..<24: return .dinner
        default: return .snack
        }
    }

    private func uniqueRecentMeals() -> [MealEntry] {
        var seen = Set<String>()
        return meals.filter { seen.insert($0.name.lowercased()).inserted }.prefix(8).map { $0 }
    }
}

struct ManualMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var serving = "1 ración"
    @State private var type = MealType.lunch
    @State private var calories = 0.0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var fiber = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Alimento") {
                    TextField("Nombre", text: $name)
                    TextField("Ración", text: $serving)
                    Picker("Momento", selection: $type) {
                        ForEach(MealType.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Nutrición") {
                    nutrient("Calorías", value: $calories, unit: "kcal")
                    nutrient("Proteína", value: $protein, unit: "g")
                    nutrient("Carbohidratos", value: $carbs, unit: "g")
                    nutrient("Grasa", value: $fat, unit: "g")
                    nutrient("Fibra", value: $fiber, unit: "g")
                }
            }
            .navigationTitle("Nueva comida")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        modelContext.insert(MealEntry(name: name.trimmingCharacters(in: .whitespacesAndNewlines), mealType: type, calories: calories, protein: protein, carbohydrates: carbs, fat: fat, fiber: fiber, serving: serving))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || calories < 0)
                }
            }
        }
    }

    private func nutrient(_ title: String, value: Binding<Double>, unit: String) -> some View {
        LabeledContent(title) {
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var delivered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !delivered,
              let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        delivered = true
        session.stopRunning()
        onCode?(code)
    }
}
