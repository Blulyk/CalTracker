import SwiftUI

private struct ImportedRecipe: Identifiable {
    let id = UUID()
    let draft: RecipeImportDraft
    let sourceURL: String
}

struct RecipeImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var importedRecipe: ImportedRecipe?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        IconBadge(systemName: "link", color: Brand.violet, size: 66)
                        Text("Importar receta")
                            .font(.title2.bold())
                        Text("Pega el enlace de una receta. Gemini extraerá ingredientes, pasos y nutrición para que puedas revisarlos.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        TextField("https://…", text: $urlText)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .appSurface()

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Brand.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appSurface(tint: Brand.red)
                        }

                        Button {
                            Task { await importRecipe() }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Label("Analizar enlace", systemImage: "sparkles")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.violet)
                        .disabled(isLoading || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Desde URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .sheet(item: $importedRecipe) { imported in
            RecipeEditorView(
                importDraft: imported.draft,
                sourceURL: imported.sourceURL,
                onSaved: { dismiss() }
            )
        }
    }

    private func importRecipe() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let draft = try await RecipeImportService().importRecipe(from: urlText)
            importedRecipe = ImportedRecipe(draft: draft, sourceURL: urlText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
