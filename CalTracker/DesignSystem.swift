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
                        ? .regular.interactive()
                        : .regular,
                    in: .rect(cornerRadius: radius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke((tint ?? Brand.border).opacity(tint == nil ? 1 : 0.45), lineWidth: 1)
                }
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

struct MiniMacroRing: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color

    private var progress: Double { min(value / max(target, 1), 1) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Brand.border, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy(duration: 0.45), value: progress)
                Text("\(Int(value))")
                    .font(.caption.bold())
            }
            .frame(width: 46, height: 46)
            Text(label.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text("/\(Int(target))g")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(Int(value)) de \(Int(target)) gramos")
    }
}


struct MealRingSegment: Identifiable {
    let id: MealType
    let label: String
    let calories: Double
    let color: Color

    var displayCalories: String { "\(Int(calories.rounded()))" }
}

struct MealRingSlice {
    let segment: MealRingSegment
    let start: CGFloat
    let end: CGFloat
}

enum MealRingLayout {
    static func slices(for segments: [MealRingSegment], gap: CGFloat = 0.06) -> [MealRingSlice] {
        let visibleSegments = segments.filter { $0.calories > 0 }
        guard !visibleSegments.isEmpty else { return [] }
        guard visibleSegments.count > 1 else {
            return [MealRingSlice(segment: visibleSegments[0], start: 0, end: 1)]
        }

        let normalizedGap = min(max(gap, 0), 0.12)
        let totalGap = normalizedGap * CGFloat(visibleSegments.count)
        let available = max(1 - totalGap, 0.2)
        let totalCalories = max(visibleSegments.reduce(0) { $0 + $1.calories }, 1)
        var cursor = normalizedGap / 2

        return visibleSegments.map { segment in
            let length = CGFloat(segment.calories / totalCalories) * available
            let slice = MealRingSlice(segment: segment, start: cursor, end: min(cursor + length, 1))
            cursor = slice.end + normalizedGap
            return slice
        }
    }

    static func segmentID(
        at point: CGPoint,
        in size: CGSize,
        slices: [MealRingSlice],
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) -> MealType? {
        guard !slices.isEmpty else { return nil }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance >= innerRadius, distance <= outerRadius else { return nil }

        var turns = (atan2(dy, dx) + (CGFloat.pi / 2)) / (2 * CGFloat.pi)
        if turns < 0 { turns += 1 }

        return slices.first { turns >= $0.start && turns <= $0.end }?.segment.id
    }
}

struct SegmentedMealRing: View {
    let segments: [MealRingSegment]
    let selectedID: MealType?
    let totalCalories: Double
    let onSelect: (MealType) -> Void

    private var visibleSegments: [MealRingSegment] {
        segments.filter { $0.calories > 0 }
    }

    private var selectedSegment: MealRingSegment? {
        if let selectedID, let match = visibleSegments.first(where: { $0.id == selectedID }) {
            return match
        }
        return nil
    }

    private var ringSlices: [MealRingSlice] {
        MealRingLayout.slices(for: visibleSegments)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 26)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 10)

            ForEach(Array(ringSlices.enumerated()), id: \.element.segment.id) { _, slice in
                let isSelected = selectedID == slice.segment.id
                Circle()
                    .trim(from: slice.start, to: slice.end)
                    .stroke(
                        slice.segment.color,
                        style: StrokeStyle(lineWidth: isSelected ? 30 : 26, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: slice.segment.color.opacity(isSelected ? 0.48 : 0.24), radius: isSelected ? 18 : 12)
                    .animation(.snappy(duration: 0.35), value: selectedID?.rawValue)
                    .animation(.snappy(duration: 0.45), value: totalCalories)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.primary.opacity(0.08), Brand.canvas.opacity(0.86)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .padding(38)
                .overlay {
                    Circle()
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                        .padding(38)
                }

            VStack(spacing: 4) {
                Text(selectedSegment?.label.uppercased() ?? "TOTAL")
                    .font(.caption.weight(.black))
                    .foregroundStyle(selectedSegment?.color ?? Brand.blue)
                Text("\(Int((selectedSegment?.calories ?? totalCalories).rounded()))")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                Text("kcal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    guard let id = MealRingLayout.segmentID(
                        at: value.location,
                        in: CGSize(width: 220, height: 220),
                        slices: ringSlices,
                        innerRadius: 66,
                        outerRadius: 116
                    ) else { return }
                    onSelect(id)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Distribucion de comidas, \(Int(totalCalories.rounded())) calorias consumidas")
    }
}

struct MacroDistributionCard: View {
    let carbohydrates: Double
    let protein: Double
    let fat: Double

    private var total: Double {
        max(carbohydrates + protein + fat, 1)
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.10), lineWidth: 14)
                macroSlice(value: carbohydrates, offset: 0, color: Brand.carb)
                macroSlice(value: protein, offset: carbohydrates / total, color: Brand.protein)
                macroSlice(value: fat, offset: (carbohydrates + protein) / total, color: Brand.fat)
            }
            .frame(width: 86, height: 86)
            .shadow(color: Brand.carb.opacity(0.18), radius: 14)

            VStack(alignment: .leading, spacing: 10) {
                MacroDistributionRow(label: "Carbos", value: carbohydrates, total: total, color: Brand.carb)
                MacroDistributionRow(label: "Proteina", value: protein, total: total, color: Brand.protein)
                MacroDistributionRow(label: "Grasa", value: fat, total: total, color: Brand.fat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macroSlice(value: Double, offset: Double, color: Color) -> some View {
        Circle()
            .trim(from: CGFloat(offset), to: CGFloat(offset + value / total))
            .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

private struct MacroDistributionRow: View {
    let label: String
    let value: Double
    let total: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(value.rounded()))g")
                .font(.subheadline.weight(.black))
            Text("\(Int((value / total * 100).rounded()))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

struct AnimatedWaterBar: View {
    let value: Int
    let goal: Int
    @State private var displayedProgress = 0.0

    private var progress: Double {
        min(max(Double(value) / Double(max(goal, 1)), 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * displayedProgress
            let visibleWidth = displayedProgress > 0 ? max(width, proxy.size.height) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: proxy.size.height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Brand.cyan, Brand.blue, Brand.violet],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: visibleWidth)
                    .opacity(displayedProgress > 0 ? 1 : 0)
                    .shadow(color: Brand.cyan.opacity(displayedProgress > 0 ? 0.55 : 0), radius: 9)
            }
            .animation(.easeInOut(duration: 0.5), value: displayedProgress)
        }
        .frame(height: 11)
        .onAppear { displayedProgress = progress }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                displayedProgress = newValue
            }
        }
        .accessibilityLabel("Hidratación \(Int(progress * 100)) por ciento")
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
