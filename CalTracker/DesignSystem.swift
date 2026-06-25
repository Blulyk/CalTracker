import SwiftUI

enum Brand {
    static let blue = Color(red: 0.05, green: 0.50, blue: 0.98)
    static let orange = Color(red: 1.00, green: 0.43, blue: 0.07)
    static let violet = Color(red: 0.49, green: 0.43, blue: 1.00)
    static let green = Color(red: 0.24, green: 0.82, blue: 0.43)
    static let red = Color(red: 1.00, green: 0.31, blue: 0.36)
    static let cyan = Color(red: 0.16, green: 0.72, blue: 0.98)
    static let carb = Color(red: 1.00, green: 0.62, blue: 0.10)
    static let protein = Color(red: 0.43, green: 0.48, blue: 1.00)
    static let fat = Color(red: 1.00, green: 0.34, blue: 0.40)

    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.018, green: 0.022, blue: 0.021, alpha: 1)
            : UIColor(red: 0.955, green: 0.962, blue: 0.958, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.082, green: 0.088, blue: 0.090, alpha: 1)
            : UIColor.secondarySystemBackground
    })
    static let elevatedSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.122, blue: 0.128, alpha: 1)
            : UIColor.systemBackground
    })
    static let border = Color.primary.opacity(0.14)
    static let muted = Color.secondary.opacity(0.72)
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Brand.canvas
            RadialGradient(
                colors: [Brand.orange.opacity(colorScheme == .dark ? 0.07 : 0.025), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

struct AppSurfaceModifier: ViewModifier {
    var tint: Color?
    var interactive = false
    var padding: CGFloat = 16
    var radius: CGFloat = 22

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .padding(padding)
                .glassEffect(
                    interactive
                        ? .regular.tint(tint ?? .clear).interactive()
                        : .regular.tint(tint ?? .clear),
                    in: .rect(cornerRadius: radius)
                )
        } else {
            content
                .padding(padding)
                .background(Brand.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke((tint ?? Brand.border).opacity(tint == nil ? 1 : 0.42), lineWidth: 1)
                }
        }
#else
        content
            .padding(padding)
            .background(Brand.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke((tint ?? Brand.border).opacity(tint == nil ? 1 : 0.42), lineWidth: 1)
            }
#endif
    }
}

extension View {
    func appSurface(tint: Color? = nil, interactive: Bool = false, padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
        modifier(AppSurfaceModifier(tint: tint, interactive: interactive, padding: padding, radius: radius))
    }

    func glassCard() -> some View {
        appSurface()
    }
}

struct EyebrowLabel: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.black))
            .tracking(1.7)
            .foregroundStyle(color)
    }
}

struct IconBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .stroke(color.opacity(0.23), lineWidth: 1)
            }
    }
}

struct SectionHeading: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title).font(.title3.bold())
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

struct MetricChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.bold)).foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.1), in: Capsule())
        .overlay { Capsule().stroke(color.opacity(0.25), lineWidth: 1) }
    }
}

struct PrimaryActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Brand.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct WeekStrip: View {
    @Binding var selectedDate: Date
    var allowsFuture = false
    private var calendar: Calendar {
        var value = Calendar.current
        value.firstWeekday = 2
        return value
    }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(calendar.calTrackerWeek(containing: selectedDate), id: \.self) { date in
                let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                let future = date > calendar.startOfDay(for: .now)
                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 8) {
                        Text(date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.bold))
                        Text(date, format: .dateTime.day())
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(selected ? .primary : (future ? .tertiary : .secondary))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(selected ? Brand.elevatedSurface : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if selected {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Brand.border, lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(future && !allowsFuture)
            }
        }
        .padding(8)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Brand.border, lineWidth: 1) }
    }
}

struct CalorieRing: View {
    let consumed: Double
    let goal: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Brand.border, lineWidth: 21)
            Circle()
                .trim(from: 0, to: min(consumed / max(goal, 1), 1))
                .stroke(
                    AngularGradient(colors: [Brand.orange, Color(red: 1, green: 0.76, blue: 0.28)], center: .center),
                    style: StrokeStyle(lineWidth: 21, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.primary.opacity(0.07), Brand.canvas.opacity(0.8)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 92
                    )
                )
                .padding(31)
            VStack(spacing: 2) {
                Text("\(Int(consumed))")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                Text("kcal consumidas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(consumed)) calorías consumidas de \(Int(goal))")
    }
}
