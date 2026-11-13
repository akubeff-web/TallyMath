import SwiftUI
import MathCore

/// Запись с дробями «столбиком», показателями и корнями. Текст берётся как есть (см. MathLayout).
struct MathText: View {
    let text: String
    var size: CGFloat = 28
    var weight: Font.Weight = .semibold
    var color: Color = .ink

    var body: some View {
        MathRow(boxes: MathLayout.layout(text), size: size, weight: weight, color: color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(MathSpeech.speak(text))
    }
}

struct MathRow: View {
    let boxes: [MathBox]
    let size: CGFloat
    let weight: Font.Weight
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: size * 0.06) {
            ForEach(Array(boxes.enumerated()), id: \.offset) { _, box in
                MathBoxView(box: box, size: size, weight: weight, color: color)
            }
        }
    }
}

struct MathBoxView: View {
    let box: MathBox
    let size: CGFloat
    let weight: Font.Weight
    let color: Color

    var body: some View {
        switch box {
        case .text(let s):
            Text(s)
                .font(.numbers(size, weight))
                .foregroundStyle(color)
                .fixedSize()
        case .fraction(let top, let bottom, let annotation):
            HStack(alignment: .top, spacing: 2) {
                // Grid растягивает черту на ширину более широкой части.
                Grid(horizontalSpacing: 0, verticalSpacing: size * 0.06) {
                    GridRow { MathRow(boxes: top, size: size * 0.82, weight: weight, color: color) }
                    GridRow {
                        Rectangle()
                            .fill(color)
                            .frame(height: max(1.5, size * 0.07))
                            .gridCellUnsizedAxes(.horizontal)
                    }
                    GridRow { MathRow(boxes: bottom, size: size * 0.82, weight: weight, color: color) }
                }
                .padding(.horizontal, size * 0.06)
                .fixedSize()
                if let annotation {
                    Text(annotation)
                        .font(.numbers(size * 0.42, .bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 4)
                        .overlay(alignment: .bottom) { Rectangle().fill(color).frame(height: 1) }
                }
            }
        case .sup(let inner):
            MathRow(boxes: inner, size: size * 0.55, weight: weight, color: color)
                .offset(y: -size * 0.38)
        case .sqrt(let inner):
            HStack(spacing: 0) {
                Text("√").font(.numbers(size, weight)).foregroundStyle(color)
                MathRow(boxes: inner, size: size, weight: weight, color: color)
                    .padding(.top, 3)
                    .overlay(alignment: .top) { Rectangle().fill(color).frame(height: max(1.5, size * 0.06)) }
            }
        }
    }
}

/// Озвучка записи для VoiceOver.
enum MathSpeech {
    static func speak(_ text: String) -> String {
        var s = text
        let pairs: [(String, String)] = [
            ("{", " "), ("}", " "), ("/", " дробь на "), ("−", " минус "), ("-", " минус "), ("+", " плюс "),
            ("×", " умножить на "), ("·", " умножить на "), (":", " разделить на "), ("=", " равно "),
            ("²", " в квадрате"), ("³", " в кубе"), ("√", " корень из "), ("≤", " меньше или равно "),
            ("≥", " больше или равно "), ("<", " меньше "), (">", " больше "), ("∞", " бесконечность "),
            ("^", " в степени "), ("%", " процентов"), ("∪", " объединение "),
        ]
        for (a, b) in pairs { s = s.replacingOccurrences(of: a, with: b) }
        return s
    }
}
