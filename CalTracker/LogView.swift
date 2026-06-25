import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

private enum LogSource: String, CaseIterable, Identifiable {
    case photo = "Foto IA"
    case barcode = "Código"
    case manual = "Manual"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .photo: "camera.fill"
        case .barcode: "barcode.viewfinder"
        case .manual: "square.and.pencil"
        }
    }
}

struct LogView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMealType = MealType.breakfast
    @State private var source = LogSource.photo
    @State private var showingManual = false
    @State private var showingScanner = false
    @State private var showingCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var analysis: FoodAnalysis?
    @State private var errorMessage: String?
    @State private var barcode = ""
    @State private var product: ProductLookup?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    mealTypeSelector
                    sourceSelector
                    sourceContent

                    if isAnalyzing {
                        HStack(spacing: 12) {
                            ProgressView().tint(Brand.orange)
                            Text("Analizando la comida…").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appSurface(tint: Brand.orange)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Brand.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appSurface(tint: Brand.red)
                    }
                    if let analysis { analysisSection(analysis) }
                    if let product { productSection(product) }
                    recipeSection
                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Registrar comida")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Cerrar")
            }
        }
        .sheet(isPresented: $showingManual) { ManualMealView(initialType: selectedMealType) }
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
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView { image in
                showingCamera = false
                Task { await analyze(image: image) }
            }
            .ignoresSafeArea()
        }
    }

    private var mealTypeSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(MealType.allCases) { type in
                    Button {
                        withAnimation(.snappy) { selectedMealType = type }
                    } label: {
                        Label(type.rawValue, systemImage: type.icon)
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 15)
                            .frame(height: 44)
                            .foregroundStyle(selectedMealType == type ? Brand.orange : .secondary)
                            .background(
                                selectedMealType == type ? Brand.orange.opacity(0.13) : Brand.surface,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule().stroke(selectedMealType == type ? Brand.orange.opacity(0.55) : Brand.border, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var sourceSelector: some View {
        HStack(spacing: 5) {
            ForEach(LogSource.allCases) { item in
                Button {
                    withAnimation(.snappy) { source = item }
                    if item == .manual { showingManual = true }
                } label: {
                    Label(item.rawValue, systemImage: item.icon)
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(source == item ? .primary : .secondary)
                        .background(source == item ? Brand.elevatedSurface : .clear, in: RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(Brand.border, lineWidth: 1) }
    }

    @ViewBuilder
    private var sourceContent: some View {
        switch source {
        case .photo:
            photoCard
        case .barcode:
            barcodeCard
        case .manual:
            Button { showingManual = true } label: {
                VStack(spacing: 14) {
                    IconBadge(systemName: "square.and.pencil", color: Brand.orange, size: 58)
                    Text("Crear entrada manual").font(.title3.bold()).foregroundStyle(.primary)
                    Text("Introduce la ración, las calorías y los macros.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    PrimaryActionLabel(title: "Abrir editor", systemImage: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .appSurface()
            }
            .buttonStyle(.plain)
        }
    }

    private var photoCard: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                VStack(spacing: 13) {
                    IconBadge(systemName: "photo.on.rectangle.angled", color: Brand.orange, size: 62)
                    Text("Subir foto de comida").font(.title3.bold()).foregroundStyle(.primary)
                    Text("Toca para elegir de la fototeca")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 182)
                .background(Brand.elevatedSurface.opacity(0.38), in: RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Brand.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await analyze(item) }
            }

            Button { showingCamera = true } label: {
                PrimaryActionLabel(title: "Hacer foto", systemImage: "camera.fill")
            }
            Button {
                source = .manual
                showingManual = true
            } label: {
                Label("Añadir manualmente", systemImage: "square.and.pencil")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.bordered)
            .tint(Brand.orange)
        }
        .appSurface(padding: 20, radius: 26)
    }

    private var barcodeCard: some View {
        VStack(spacing: 15) {
            IconBadge(systemName: "barcode.viewfinder", color: Brand.green, size: 66)
            Text("Escanea el envase").font(.title3.bold())
            Text("Buscaremos la información nutricional en Open Food Facts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showingScanner = true } label: {
                Label("Abrir escáner", systemImage: "viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.green)
        }
        .frame(maxWidth: .infinity)
        .appSurface(tint: Brand.green, padding: 22, radius: 26)
    }

    private func analysisSection(_ result: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                EyebrowLabel(text: "Resultado IA", color: Brand.violet)
                Spacer()
                if let confidence = result.confidence {
                    Text("\(Int(confidence * 100))% confianza")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(result.foods) { food in
                HStack(spacing: 12) {
                    IconBadge(systemName: "fork.knife", color: Brand.orange, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(food.name).fontWeight(.bold)
                        Text("\(food.portion) · \(Int(food.calories)) kcal")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        addFood(food)
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.bold())
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(Brand.blue)
                    .accessibilityLabel("Añadir \(food.name)")
                }
            }
            if let notes = result.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary)
            }
        }
        .appSurface(tint: Brand.violet)
    }

    private func productSection(_ item: ProductLookup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "Producto encontrado", color: Brand.green)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.headline)
                    Text(item.serving).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(item.calories)) kcal").font(.headline).foregroundStyle(Brand.orange)
            }
            HStack {
                MetricChip(label: "P", value: "\(Int(item.protein))g", color: Brand.protein)
                MetricChip(label: "C", value: "\(Int(item.carbohydrates))g", color: Brand.carb)
                MetricChip(label: "G", value: "\(Int(item.fat))g", color: Brand.fat)
            }
            Button {
                modelContext.insert(MealEntry(name: item.name, mealType: selectedMealType, calories: item.calories, protein: item.protein, carbohydrates: item.carbohydrates, fat: item.fat, fiber: item.fiber, serving: item.serving, source: "open-food-facts"))
                product = nil
            } label: {
                PrimaryActionLabel(title: "Añadir al día", systemImage: "plus")
            }
        }
        .appSurface(tint: Brand.green)
    }

    private var recipeSection: some View {
        Group {
            if !recipes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    EyebrowLabel(text: "Recetario", color: .primary)
                    ForEach(recipes.prefix(4)) { recipe in
                        Button {
                            modelContext.insert(MealEntry(name: recipe.name, mealType: selectedMealType, calories: recipe.caloriesPerServing, protein: recipe.proteinPerServing, carbohydrates: recipe.carbsPerServing, fat: recipe.fatPerServing, source: "recipe"))
                        } label: {
                            HStack {
                                IconBadge(systemName: "book.closed.fill", color: Brand.orange, size: 42)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(recipe.name).fontWeight(.bold).foregroundStyle(.primary)
                                    Text("\(Int(recipe.caloriesPerServing)) kcal por ración")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Brand.blue)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        if recipe.id != recipes.prefix(4).last?.id { Divider() }
                    }
                }
                .appSurface()
            }
        }
    }

    private var recentSection: some View {
        Group {
            if !meals.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    EyebrowLabel(text: "Recientes", color: .primary)
                        .padding(.bottom, 10)
                    ForEach(uniqueRecentMeals()) { meal in
                        Button {
                            modelContext.insert(MealEntry(name: meal.name, mealType: selectedMealType, calories: meal.calories, protein: meal.protein, carbohydrates: meal.carbohydrates, fat: meal.fat, fiber: meal.fiber, serving: meal.serving, source: "recent"))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(meal.name).fontWeight(.semibold).foregroundStyle(.primary)
                                    Text("\(meal.serving) · \(Int(meal.calories)) kcal")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Brand.blue, in: Circle())
                            }
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .appSurface()
            }
        }
    }

    private func addFood(_ food: AnalyzedFood) {
        modelContext.insert(MealEntry(name: food.name, mealType: selectedMealType, calories: food.calories, protein: food.protein, carbohydrates: food.carbs, fat: food.fat, fiber: food.fiber ?? 0, serving: food.portion, source: "gemini"))
    }

    private func analyze(_ item: PhotosPickerItem) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { throw ServiceError.imageEncoding }
            try await analyzeImage(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func analyze(image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            try await analyzeImage(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func analyzeImage(_ image: UIImage) async throws {
        guard let jpeg = image.jpegData(compressionQuality: 0.78) else { throw ServiceError.imageEncoding }
        analysis = try await GeminiService().analyze(imageData: jpeg, profileName: profiles.first?.name)
    }

    private func lookupBarcode() async {
        errorMessage = nil
        do {
            product = try await OpenFoodFactsService().lookup(barcode: barcode)
        } catch {
            errorMessage = error.localizedDescription
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
    @State private var type: MealType
    @State private var calories = 0.0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var fiber = 0.0

    init(initialType: MealType = .lunch) {
        _type = State(initialValue: initialType)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            TextField("Nombre del alimento", text: $name)
                                .font(.headline)
                            Divider()
                            TextField("Ración", text: $serving)
                            Picker("Momento", selection: $type) {
                                ForEach(MealType.allCases) { Text($0.rawValue).tag($0) }
                            }
                        }
                        .appSurface()

                        VStack(spacing: 14) {
                            EyebrowLabel(text: "Nutrición", color: .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            nutrient("Calorías", value: $calories, unit: "kcal", color: Brand.orange)
                            nutrient("Proteína", value: $protein, unit: "g", color: Brand.protein)
                            nutrient("Carbohidratos", value: $carbs, unit: "g", color: Brand.carb)
                            nutrient("Grasa", value: $fat, unit: "g", color: Brand.fat)
                            nutrient("Fibra", value: $fiber, unit: "g", color: Brand.green)
                        }
                        .appSurface()
                    }
                    .padding()
                }
            }
            .navigationTitle("Nueva comida")
            .navigationBarTitleDisplayMode(.inline)
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

    private func nutrient(_ title: String, value: Binding<Double>, unit: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).fontWeight(.semibold)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit).foregroundStyle(.secondary).frame(width: 35, alignment: .leading)
        }
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onImage(image) }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
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
