import SwiftUI
import MathCore

/// Набор клавиш под класс: лишнее не показываем.
enum KeyboardSet {
    /// 5–6 класс: цифры, действия, дробь, смешанное число, степень, %, отношение, модуль.
    case basic
    /// 7–8 класс: переменные, степень, корень, промежутки, системы, «или».
    case algebra

    static func forTopic(_ id: String?) -> KeyboardSet {
        guard let id, let t = Course.topic(id) else { return .basic }
        return t.grade >= .seven ? .algebra : .basic
    }
}

/// Собственная стеклянная цифровая клавиатура.
struct MathKeyboard: View {
    @Binding var editor: MathEditor
    var set: KeyboardSet = .basic
    @State private var showDigits = false
    @State private var tick = 0

    private enum Key: Hashable {
        case text(String, insert: String)
        case fraction, power, sqrt, abs, system, annotation, delete, left, right, toggle(String)
        case squared
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(strip, id: \.self) { key in
                            keyButton(key, compact: true)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                Grid(horizontalSpacing: 8, verticalSpacing: 7) {
                    ForEach(Array(grid.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(row, id: \.self) { key in keyButton(key, compact: false) }
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: tick)
    }

    private var strip: [Key] {
        switch set {
        case .basic:
            return [.left, .right, .text("смеш.", insert: ""), .power, .text("%", insert: "%"), .text("a : b", insert: ":"),
                    .abs, .annotation]
        case .algebra:
            return [.left, .right, .text("или", insert: " или "), .text("x₁", insert: "x₁"), .text("x₂", insert: "x₂"),
                    .text("a⁻ⁿ", insert: ""), .text("∞", insert: "∞"), .text("нет решений", insert: "нет решений"),
                    .text("любое число", insert: "любое число"), .annotation]
        }
    }

    private var grid: [[Key]] {
        let digits: [[Key]] = [
            [.text("7", insert: "7"), .text("8", insert: "8"), .text("9", insert: "9"), .fraction, .delete],
            [.text("4", insert: "4"), .text("5", insert: "5"), .text("6", insert: "6"), .text("+", insert: "+"), .text("−", insert: "−")],
            [.text("1", insert: "1"), .text("2", insert: "2"), .text("3", insert: "3"), .text("×", insert: "×"), .text(":", insert: ":")],
            [.text(",", insert: ","), .text("0", insert: "0"), .text("=", insert: "="), .text("(", insert: "("), .text(")", insert: ")")],
        ]
        if set == .basic { return digits }
        if showDigits {
            var d = digits
            d[3][2] = .toggle("x y")
            d[3][3] = .text("=", insert: "=")
            d[3][4] = .text(";", insert: ";")
            return d
        }
        return [
            [.text("x", insert: "x"), .text("y", insert: "y"), .squared, .power, .sqrt],
            [.text("(", insert: "("), .text(")", insert: ")"), .text("[", insert: "["), .text("]", insert: "]"), .text(";", insert: ";")],
            [.text("<", insert: "<"), .text(">", insert: ">"), .text("≤", insert: "≤"), .text("≥", insert: "≥"), .text("∪", insert: "∪")],
            [.toggle("123"), .fraction, .system, .text("±", insert: "±"), .delete],
        ]
    }

    @ViewBuilder
    private func keyButton(_ key: Key, compact: Bool) -> some View {
        Button {
            press(key)
        } label: {
            label(for: key)
                .font(compact ? .system(size: 15, weight: .semibold) : .numbers(24, .medium))
                .foregroundStyle(Color.ink)
                .frame(minWidth: compact ? 36 : nil, maxWidth: compact ? nil : .infinity, minHeight: compact ? 30 : 46)
                .padding(.horizontal, compact ? 6 : 0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
        .buttonBorderShape(compact ? .capsule : .roundedRectangle(radius: 16))
        .accessibilityLabel(spoken(key))
    }

    @ViewBuilder
    private func label(for key: Key) -> some View {
        switch key {
        case .text(let t, _): Text(t)
        case .fraction: FractionKeyIcon()
        case .power: Text("aⁿ")
        case .squared: Text("x²")
        case .sqrt: Text("√")
        case .abs: Text("|x|")
        case .system: Text("{")
        case .annotation: Text("×n")
        case .delete: Image(systemName: "delete.left")
        case .left: Image(systemName: "arrow.left")
        case .right: Image(systemName: "arrow.right")
        case .toggle(let t): Text(t)
        }
    }

    private func spoken(_ key: Key) -> String {
        switch key {
        case .text(let t, _): return MathSpeech.speak(t)
        case .fraction: return "Дробь"
        case .power: return "Степень"
        case .squared: return "x в квадрате"
        case .sqrt: return "Корень"
        case .abs: return "Модуль"
        case .system: return "Система"
        case .annotation: return "Дополнительный множитель над дробью"
        case .delete: return "Стереть"
        case .left: return "Курсор влево"
        case .right: return "Следующее поле"
        case .toggle(let t): return t == "123" ? "Цифры" : "Буквы"
        }
    }

    private func press(_ key: Key) {
        tick += 1
        switch key {
        case .text(let t, let insert):
            if t == "смеш." {
                // Смешанное число: целая часть уже набрана, дальше дробь.
                editor.insertFraction()
            } else if t == "a⁻ⁿ" {
                editor.insertPower()
                editor.insert("−")
            } else {
                for ch in insert { editor.insert(String(ch)) }
            }
        case .fraction: editor.insertFraction()
        case .power: editor.insertPower()
        case .squared:
            editor.insert("x")
            editor.insertPower()
            editor.insert("2")
            editor.moveNext()
        case .sqrt: editor.insertSqrt()
        case .abs: editor.insertAbs()
        case .system: editor.insertSystem()
        case .annotation: editor.annotateFraction()
        case .delete: editor.backspace()
        case .left: editor.movePrev()
        case .right: editor.moveNext()
        case .toggle: showDigits.toggle()
        }
    }
}

/// Значок клавиши «дробь»: два поля и черта.
struct FractionKeyIcon: View {
    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3).strokeBorder(Color.ink, lineWidth: 1.6).frame(width: 12, height: 10)
            Rectangle().fill(Color.ink).frame(width: 16, height: 2)
            RoundedRectangle(cornerRadius: 3).strokeBorder(Color.ink, lineWidth: 1.6).frame(width: 12, height: 10)
        }
        .accessibilityHidden(true)
    }
}
