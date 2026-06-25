import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today, recipes, add, history, profile
}

struct RootView: View {
    @Query(sort: \BuffetSession.startedAt, order: .reverse) private var buffetSessions: [BuffetSession]
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppTab
    @State private var previousSelection: AppTab = .today
    @State private var showingLog = false
    @State private var presentedBuffet: BuffetSession?
    private let opensLogOnLaunch: Bool
    private let opensBuffetOnLaunch: Bool

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        opensLogOnLaunch = arguments.contains("-ui-log")
        opensBuffetOnLaunch = arguments.contains("-ui-buffet")
        if let index = arguments.firstIndex(of: "-ui-tab"), arguments.indices.contains(index + 1) {
            let value = arguments[index + 1]
            _selection = State(initialValue: value == "recipes" ? .recipes : value == "history" ? .history : value == "profile" ? .profile : .today)
        } else {
            _selection = State(initialValue: .today)
        }
#else
        opensLogOnLaunch = false
        opensBuffetOnLaunch = false
        _selection = State(initialValue: .today)
#endif
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView(
                    onAddMeal: openLog,
                    onStartBuffet: startBuffet
                )
            }
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
        .fullScreenCover(item: $presentedBuffet) { session in
            BuffetSessionView(session: session)
        }
        .overlay(alignment: .bottom) {
            if let activeBuffet {
                activeBuffetBar(activeBuffet)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 62)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            if opensLogOnLaunch {
                showingLog = true
            } else if opensBuffetOnLaunch {
                startBuffet()
            }
        }
    }

    private func openLog() {
        showingLog = true
    }

    private var activeBuffet: BuffetSession? {
        buffetSessions.first { $0.completedAt == nil }
    }

    private func startBuffet() {
        if let activeBuffet {
            presentedBuffet = activeBuffet
        } else {
            let session = BuffetSession()
            modelContext.insert(session)
            presentedBuffet = session
        }
    }

    private func activeBuffetBar(_ session: BuffetSession) -> some View {
        Button {
            presentedBuffet = session
        } label: {
            HStack(spacing: 12) {
                IconBadge(systemName: "fish.fill", color: Brand.red, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Buffet en curso").font(.subheadline.bold()).foregroundStyle(.primary)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("\(session.totalPieces) piezas · \(durationText(context.date.timeIntervalSince(session.startedAt)))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up").foregroundStyle(Brand.red)
            }
            .appSurface(tint: Brand.red, interactive: true, padding: 12, radius: 18)
        }
        .buttonStyle(.plain)
    }

    private func durationText(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
