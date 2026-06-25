import SwiftUI

enum AppTab: Hashable {
    case today, log, history, plan, profile
}

struct RootView: View {
    @State private var selection: AppTab = .today

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { TodayView(onAddMeal: { selection = .log }) }
                .tabItem { Label("Hoy", systemImage: "circle.grid.2x2.fill") }
                .tag(AppTab.today)
            NavigationStack { LogView() }
                .tabItem { Label("Registrar", systemImage: "plus.circle.fill") }
                .tag(AppTab.log)
            NavigationStack { HistoryView() }
                .tabItem { Label("Historial", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.history)
            NavigationStack { PlanView() }
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(AppTab.plan)
            NavigationStack { ProfileView() }
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}
