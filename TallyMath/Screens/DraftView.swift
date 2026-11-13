import SwiftUI
import PencilKit

/// Черновик: свободное рисование пальцем или Apple Pencil. Не проверяется.
struct DraftView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()

    var body: some View {
        DraftCanvas(canvas: canvas)
            .background(NotebookPaper())
            .background(Color.canvas)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Черновик")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Закрыть")
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Черновик").font(.headline)
                        Text("не проверяется").font(.caption2).foregroundStyle(Color.sub)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { canvas.undoManager?.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                        .accessibilityLabel("Отменить")
                    Button { canvas.undoManager?.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                        .accessibilityLabel("Повторить")
                    Button { canvas.drawing = PKDrawing() } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Очистить")
                }
            }
    }
}

/// Холст PencilKit с системной палитрой инструментов.
struct DraftCanvas: UIViewRepresentable {
    let canvas: PKCanvasView

    /// Палитра инструментов должна жить, пока открыт черновик, — держим её в координаторе.
    final class Coordinator {
        let picker = PKToolPicker()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .label, width: 4)
        let picker = context.coordinator.picker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
