import SwiftUI
import MathCore

/// «Свой пример»: ввожу пример из домашки, приложение определяет тему, считает ответ и шаги.
struct CustomExampleView: View {
    var presetText: String?
    @Environment(AppModel.self) private var model
    @State private var editor = MathEditor()
    @State private var result: Result<Problem, CustomProblem.Failure>?
    @State private var showAnswer = false
    @State private var showSolution = false
    @State private var keyboardSet: KeyboardSet = .algebra

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Пример из домашки").font(.caption.weight(.semibold)).foregroundStyle(Color.sub)
                        EditorView(editor: $editor, size: 30, placeholder: "Введи пример")
                    }
                    .padding(16)
                    .background(NotebookPaper().clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)))
                    .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Color.card))
                    switch result {
                    case .success(let p)?: found(p)
                    case .failure(let f)?:
                        BitBubble(mood: .wrong, title: f.message, subtitle: "Можно проверить скобки или записать иначе.", bitSize: 64)
                    case nil:
                        BitBubble(mood: .waiting, title: "Введи пример или уравнение.",
                                  subtitle: "Определю класс и тему, посчитаю ответ и шаги.", bitSize: 64)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            if result == nil || isFailure {
                MathKeyboard(editor: $editor, set: keyboardSet).padding(.horizontal, Metrics.gutter)
                PrimaryButton(title: "Разобрать пример", systemImage: "sparkle.magnifyingglass") {
                    withAnimation(.spring) { result = CustomProblem.make(editor.text) }
                }
                .disabled(editor.isEmpty)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 8)
            }
        }
        .screenBackground()
        .navigationTitle("Свой пример")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if result != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Изменить") { withAnimation { result = nil; showAnswer = false } }
                }
            }
        }
        .sheet(isPresented: $showSolution) {
            if case .success(let p)? = result { FullSolutionView(problem: p, onDone: { showSolution = false }) }
        }
        .onAppear {
            if let presetText, editor.isEmpty {
                editor = MathEditor(text: presetText)
                result = CustomProblem.make(presetText)
            }
        }
    }

    private var isFailure: Bool {
        if case .failure? = result { return true }
        return false
    }

    @ViewBuilder
    private func found(_ p: Problem) -> some View {
        let topic = Course.topic(p.topicID)
        VStack(alignment: .leading, spacing: 10) {
            Text("Нашёл тему").font(.caption.weight(.semibold)).foregroundStyle(Color.sub)
            Text("\(topic?.grade.title ?? "") · \(topic?.title ?? "")").font(.headline)
            Divider().overlay(Color.hairline)
            HStack {
                Text("Ответ").foregroundStyle(Color.sub)
                Spacer()
                if showAnswer {
                    MathText(text: p.answerText, size: 22)
                } else {
                    Button { withAnimation { showAnswer = true } } label: { Label("Показать", systemImage: "eye") }
                        .buttonStyle(.glass)
                }
            }
            Text("Решение: шагов \(p.steps.count)").font(.footnote).foregroundStyle(Color.sub)
        }
        .contentCard()
        if let topic {
            BitBubble(mood: .hint, title: "По этой теме есть урок.", subtitle: "Повторить перед решением?", bitSize: 56)
            NavigationLink(value: Route.lesson(topic.id)) {
                Label("Повторить урок", systemImage: "book").font(.headline).frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.glass)
        }
        GlassButton(title: "Полное решение", systemImage: "list.number") { showSolution = true }
        NavigationLink(value: Route.solve(p)) {
            Label("Решить самому", systemImage: "pencil").font(.headline).foregroundStyle(Color.inverse)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.ink)
        .controlSize(.large)
    }
}
