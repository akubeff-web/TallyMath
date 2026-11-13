import SwiftUI
import MathCore

/// Главная кнопка экрана: заливка чёрная в светлой теме и белая в тёмной (glassProminent с tint ink).
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title).font(.headline)
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Color.inverse)
            .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.ink)
        .controlSize(.large)
    }
}

/// Второстепенная стеклянная кнопка.
struct GlassButton: View {
    let title: String
    var systemImage: String?
    var fill = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.headline)
            .foregroundStyle(Color.ink)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: 34)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }
}

/// Кнопки «Не понял» / «Понял» под любым объяснением.
struct UnderstoodButtons: View {
    var onNotUnderstood: () -> Void
    var onUnderstood: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                GlassButton(title: "Не понял", action: onNotUnderstood)
                PrimaryButton(title: "Понял", systemImage: "checkmark", action: onUnderstood)
            }
        }
    }
}

/// Реплика Bit — контент, поэтому сплошная карточка, без стекла.
struct BitBubble: View {
    var mood: BitMood
    var title: String
    var subtitle: String?
    var bitSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            BitView(mood: mood, size: bitSize)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(Color.ink)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(Color.sub)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentCard(radius: 20, padding: 12)
        }
        .accessibilityElement(children: .combine)
    }
}

/// «Верно» / «Неверно» — инверсия и значок, без цвета.
struct StatusBadge: View {
    let status: LineStatus

    var body: some View {
        let (icon, text, filled): (String, String, Bool) = {
            switch status {
            case .correct: return ("checkmark", "Верно", true)
            case .correctNotSimplest: return ("checkmark.circle", "Почти", false)
            case .wrong: return ("xmark", "Неверно", true)
            case .unverifiable: return ("questionmark", "Не проверено", false)
            }
        }()
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(filled ? Color.inverse : Color.ink)
            .background(Capsule().fill(filled ? Color.ink : Color.clear))
            .overlay(Capsule().strokeBorder(Color.ink, style: StrokeStyle(lineWidth: 1.5, dash: filled ? [] : [4, 3])))
    }
}

/// Значок статуса строки тетради.
struct LineStatusIcon: View {
    let status: LineStatus?

    var body: some View {
        Group {
            switch status {
            case .correct?:
                Image(systemName: "checkmark.circle.fill")
            case .correctNotSimplest?:
                Image(systemName: "checkmark.circle")
            case .wrong?:
                Image(systemName: "xmark.circle.fill")
            case .unverifiable?:
                Image(systemName: "questionmark.circle.dashed")
            case nil:
                Image(systemName: "circle.dotted")
                    .foregroundStyle(Color.faint)
            }
        }
        .font(.title3)
        .foregroundStyle(Color.ink)
        .accessibilityLabel(status?.message ?? "Не проверено")
    }
}

struct SectionLabel: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(text.uppercased()).font(.footnote.weight(.semibold)).foregroundStyle(Color.sub)
            Spacer()
            if let trailing { Text(trailing).font(.footnote).foregroundStyle(Color.sub) }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Шаги уровня 1: правило и пояснение на числах.
struct StepList: View {
    let steps: [SolutionStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.numbers(14, .bold))
                        .foregroundStyle(Color.inverse)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.ink))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.rule).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink)
                        Text(step.detail).font(.subheadline).foregroundStyle(Color.sub)
                        if let line = step.line {
                            MathText(text: line, size: 20)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Маленькая плитка цифры статистики.
struct StatTile: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.numbers(28, .bold)).foregroundStyle(Color.ink).minimumScaleFactor(0.6).lineLimit(1)
            Text(caption).font(.footnote).foregroundStyle(Color.sub)
        }
        .contentCard(radius: 22, padding: 14)
        .accessibilityElement(children: .combine)
    }
}

/// Полоса точности: тонкая, без цвета.
struct AccuracyBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ink.opacity(0.1))
                Capsule().fill(Color.ink).frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
