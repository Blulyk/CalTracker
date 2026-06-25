import SwiftUI

enum AppTab: Hashable {
    case today, recipes, add, history, profile
}

struct RootView: View {
    @State private var selection: AppTab
    @State private var previousSelection: AppTab = .today
    @State private var showingLog = false
    private let opensLogOnLaunch: Bool

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        opensLogOnLaunch = arguments.contains("-ui-log")
        if let index = arguments.firstIndex(of: "-ui-tab"), arguments.indices.contains(index + 1) {
            let value = arguments[index + 1]
            _selection = State(initialValue: value == "recipes" ? .recipes : value == "history" ? .history : value == "profile" ? .profile : .today)
        } else {
            _selection = State(initialValue: .today)
        }
#else
        opensLogOnLaunch = false
        _selection = State(initialValue: .today)
#endif
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { TodayView(onAddMeal: openLog) }
                .tabItem { Label("Inicio", systemImage: "house.fill") }
                .tag(AppTab.today)

            NavigationStack { PlanView() }
                .tabItem { Label("Recetas", systemImage: "book.closed.fill") }
                .tag(AppTab.recipes)

            Color.clear
                .tabItem { Label("Registrar", systemImage: "plus.circle.fill") }
                .tag(AppTab.add)

            NavigationStack { HistoryView() }
                .tabItem { Label("Historial", systemImage: "clock.fill") }
                .tag(AppTab.history)

            NavigationStack { ProfileView() }
                .tabItem { Label("Perfil", systemImage: "person.fill") }
                .tag(AppTab.profile)
        }
        .tint(Brand.blue)
        .onChange(of: selection) { oldValue, newValue in
            if newValue == .add {
                previousSelection = oldValue == .add ? .today : oldValue
                selection = previousSelection
                showingLog = true
            } else {
                previousSelection = newValue
            }
        }
        .fullScreenCover(isPresented: $showingLog) {
            NavigationStack { LogView() }
                .tint(Brand.orange)
        }
        .overlay(alignment: .bottom) {
            Button(action: openLog) {
                Image(systemName: "plus")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Brand.blue, in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.2), lineWidth: 1) }
                    .shadow(color: Brand.blue.opacity(0.42), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 42)
            .accessibilityLabel("Registrar comida")
        }
        .task {
            guard opensLogOnLaunch else { return }
            try? await Task.sleep(for: .milliseconds(500))
            showingLog = true
        }
    }

    private func openLog() {
        showingLog = true
    }
}
