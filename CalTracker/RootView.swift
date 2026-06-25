import SwiftUI

enum AppTab: Hashable {
    case today, recipes, add, history, profile
}

struct RootView: View {
    @State private var selection: AppTab
    @State private var previousSelection: AppTab = .today
    @State private var showingLog = false

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-ui-tab"), arguments.indices.contains(index + 1) {
            let value = arguments[index + 1]
            _selection = State(initialValue: value == "recipes" ? .recipes : value == "history" ? .history : value == "profile" ? .profile : .today)
        } else {
            _selection = State(initialValue: .today)
        }
#else
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
    }

    private func openLog() {
        showingLog = true
    }
}
