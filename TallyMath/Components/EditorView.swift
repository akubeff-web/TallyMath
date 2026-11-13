import SwiftUI
import MathCore

/// Поле ввода записи: дроби, степени, корни. Активное поле обведено, в нём мигает курсор.
struct EditorView: View {
    @Binding var editor: MathEditor
    var size: CGFloat = 34
    var placeholder = "Ответ"

    var body: some View {
        Group {
            if editor.isEmpty && editor.cursor.path.isEmpty {
                HStack(spacing: 4) {
                    Caret(size: size)
                    Text(placeholder)
                        .font(.numbers(size * 0.6, .regular))
                        .foregroundStyle(Color.faint)
                }
            } else {
                EditorFieldView(editor: $editor, path: [], size: size)
            }
        }
        .frame(maxWidth: .infinity, minHeight: size * 1.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Поле ответа")
        .accessibilityValue(editor.isEmpty ? "пусто" : MathSpeech.speak(editor.text))
    }
}

struct EditorFieldView: View {
    @Binding var editor: MathEditor
    let path: [EditorCursor.Step]
    let size: CGFloat

    var body: some View {
        let field = editor.field(at: path)
        let active = editor.cursor.path == path
        HStack(alignment: .center, spacing: 1) {
            if field.nodes.isEmpty {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.ink.opacity(active ? 0 : 0.35), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .frame(width: size * 0.55, height: size * 0.8)
                    .overlay { if active { Caret(size: size) } }
            } else {
                ForEach(0..<field.nodes.count, id: \.self) { i in
                    if active && editor.cursor.position == i { Caret(size: size) }
                    EditorNodeView(editor: $editor, node: field.nodes[i], path: path, index: i, size: size)
                }
                if active && editor.cursor.position == field.nodes.count { Caret(size: size) }
            }
        }
        .padding(.horizontal, path.isEmpty ? 0 : 3)
        .padding(.vertical, path.isEmpty ? 0 : 2)
        .background {
            // Активное поле шаблона — толще рамка и заливка (подсветка без цвета).
            if active && !path.isEmpty {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.ink.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ink, lineWidth: 2))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editor.moveCursor(to: path) }
    }
}

struct EditorNodeView: View {
    @Binding var editor: MathEditor
    let node: EditorNode
    let path: [EditorCursor.Step]
    let index: Int
    let size: CGFloat

    func slot(_ i: Int) -> [EditorCursor.Step] { path + [EditorCursor.Step(node: index, slot: i)] }

    var body: some View {
        switch node {
        case .char(let c):
            Text(c).font(.numbers(size, .semibold)).foregroundStyle(Color.ink).fixedSize()
        case .fraction(_, _, let annotation):
            HStack(alignment: .top, spacing: 2) {
                Grid(horizontalSpacing: 0, verticalSpacing: 3) {
                    GridRow { EditorFieldView(editor: $editor, path: slot(0), size: size * 0.8) }
                    GridRow {
                        Rectangle().fill(Color.ink).frame(height: 2).gridCellUnsizedAxes(.horizontal)
                    }
                    GridRow { EditorFieldView(editor: $editor, path: slot(1), size: size * 0.8) }
                }
                .fixedSize()
                if annotation != nil {
                    EditorFieldView(editor: $editor, path: slot(2), size: size * 0.42)
                        .overlay(alignment: .leading) { Text("×").font(.numbers(size * 0.42, .bold)).offset(x: -size * 0.3) }
                        .padding(.leading, size * 0.3)
                }
            }
        case .power:
            EditorFieldView(editor: $editor, path: slot(0), size: size * 0.55)
                .offset(y: -size * 0.38)
        case .sqrt:
            HStack(spacing: 0) {
                Text("√").font(.numbers(size, .semibold)).foregroundStyle(Color.ink)
                EditorFieldView(editor: $editor, path: slot(0), size: size)
                    .padding(.top, 3)
                    .overlay(alignment: .top) { Rectangle().fill(Color.ink).frame(height: 2) }
            }
        case .abs:
            HStack(spacing: 2) {
                Rectangle().fill(Color.ink).frame(width: 2, height: size)
                EditorFieldView(editor: $editor, path: slot(0), size: size)
                Rectangle().fill(Color.ink).frame(width: 2, height: size)
            }
        case .system:
            HStack(spacing: 4) {
                Text("{").font(.system(size: size * 1.8, weight: .light)).foregroundStyle(Color.ink)
                VStack(alignment: .leading, spacing: 6) {
                    EditorFieldView(editor: $editor, path: slot(0), size: size * 0.8)
                    EditorFieldView(editor: $editor, path: slot(1), size: size * 0.8)
                }
            }
        }
    }
}

/// Мигающий курсор. При Reduce Motion не мигает.
struct Caret: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let on = reduceMotion || Int(tl.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.ink)
                .frame(width: 2, height: size * 0.85)
                .opacity(on ? 1 : 0.15)
        }
        .accessibilityHidden(true)
    }
}
