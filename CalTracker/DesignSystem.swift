import SwiftUI

enum Brand {
    static let blue = Color(red: 0.12, green: 0.39, blue: 0.95)
    static let orange = Color(red: 0.98, green: 0.42, blue: 0.16)
    static let green = Color(red: 0.20, green: 0.72, blue: 0.46)
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCardModifier()) }
}

struct MacroBar: View {
    let name: String
    let value: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(value))/\(Int(target)) g").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: min(value, target), total: max(target, 1))
                .tint(color)
        }
    }
}

struct CalorieRing: View {
    let consumed: Double
    let goal: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 16)
            Circle()
                .trim(from: 0, to: min(consumed / max(goal, 1), 1))
                .stroke(Brand.blue, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(max(goal - consumed, 0)))").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("kcal restantes").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 170, height: 170)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(consumed)) calorías consumidas de \(Int(goal))")
    }
}
