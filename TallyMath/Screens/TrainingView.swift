import SwiftUI
import MathCore

/// Начальное состояние тренировки — для скриншотов.
struct TrainingPreset {
    var problems: [Problem]
    var index = 0
    var answer = ""
    var phase: TrainingView.Phase = .input
}

/// Тренировка: пример, поле ответа, своя клавиатура, проверка и реакция Bit.
struct TrainingView: View {
    enum Phase: Equatable {
        case input
        case checked(LineStatus)
    }

    let request: SessionRequest
    var preset: TrainingPreset?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var problems: [Problem] = []
    @State private var index = 0
    @State private var editor = MathEditor()
    @State private var phase: Phase = .input
    @State private var results: [(topicID: String, correct: Bool)] = []
    @State private var start = Date()
    @State private var explanation: SheetProblem?
    @State private var fullSolution: SheetProblem?
    @State private var lessonTopic: String?
    @State private var finished = false
    @State private var successTick = 0
    @State private var errorTick = 0

    init(request: SessionRequest, preset: TrainingPreset? = nil) {
        self.request = request
        self.preset = preset
    }

    var body: some View {
        Group {
            if finished {
                ResultView(problems: problems, results: results, isReview: request.isReview,
                           onHome: { dismiss() }, onMore: restart)
            } else if let problem = current {
                content(problem)
            } else {
                ProgressView()
            }
        }
        .screenBackground()
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbar }
        .onAppear(perform: setup)
        .sensoryFeedback(.success, trigger: successTick)
        .sensoryFeedback(.error, trigger: errorTick)
        .sheet(item: $explanation) { item in
            NavigationStack {
                ExplanationView(problem: item.problem, startLevel: item.level, onDone: { explanation = nil })
            }
        }
        .sheet(item: $fullSolution) { item in
            FullSolutionView(problem: item.problem, onDone: { fullSolution = nil })
        }
        .sheet(item: Binding(get: { lessonTopic.map(LessonID.init) }, set: { lessonTopic = $0?.id })) { item in
            NavigationStack { LessonView(topicID: item.id) }
        }
    }

    private var current: Problem? { index < problems.count ? problems[index] : nil }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Закончить")
        }
        ToolbarItem(placement: .principal) {
            if !finished {
                Text("\(min(index + 1, max(problems.count, 1))) из \(problems.count)").font(.headline)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if !finished, let p = current {
                Button { lessonTopic = p.topicID } label: { Label("Объясни", systemImage: "lightbulb") }
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    @ViewBuilder
    private func content(_ problem: Problem) -> some View {
        VStack(spacing: 14) {
            progressBar
            ScrollView {
                VStack(spacing: 16) {
                    Text(Course.topic(problem.topicID)?.title ?? "")
                        .font(.subheadline).foregroundStyle(Color.sub)
                    if let story = problem.story {
                        Text(story).font(.title3.weight(.medium)).multilineTextAlignment(.center)
                    } else {
                        Text(problem.prompt).font(.subheadline.weight(.medium)).foregroundStyle(Color.sub)
                        MathText(text: problem.display, size: 40, weight: .bold)
                            .minimumScaleFactor(0.5)
                    }
                    switch phase {
                    case .input:
                        answerArea
                    case .checked(let status):
                        feedback(problem, status)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollBounceBehavior(.basedOnSize)
            bottomControls(problem)
        }
    }

    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(problems.count, 1), id: \.self) { i in
                Capsule()
                    .fill(Color.ink.opacity(i < index ? 1 : (i == index ? 0.45 : 0.12)))
                    .frame(height: 5)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .accessibilityElement()
        .accessibilityLabel("Пример \(index + 1) из \(problems.count)")
    }

    private var answerArea: some View {
        HStack(spacing: 12) {
            BitView(mood: .waiting, size: 84)
            EditorView(editor: $editor, size: 36)
                .padding(.vertical, 8)
                .contentCard(radius: 22, padding: 10)
        }
    }

    @ViewBuilder
    private func feedback(_ problem: Problem, _ status: LineStatus) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                MathText(text: editor.isEmpty ? "—" : editor.text, size: 26, color: status.isCorrect ? .ink : .sub)
                    .overlay {
                        if case .wrong = status {
                            Rectangle().fill(Color.ink).frame(height: 2).rotationEffect(.degrees(-12))
                        }
                    }
                Spacer()
                StatusBadge(status: status)
            }
            switch status {
            case .correct:
                BitBubble(mood: model.progress.streak >= 5 ? .streak : .correct, title: "Верно.",
                          subtitle: model.progress.streak >= 3 ? "Серия: \(model.progress.streak)" : nil, bitSize: 110)
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        GlassButton(title: "Как решать правильно", systemImage: "lightbulb") {
                            explanation = SheetProblem(problem: problem, level: 1)
                        }
                        HStack(spacing: 10) {
                            GlassButton(title: "Похожий пример") { insertSimilar(problem) }
                            GlassButton(title: "Полное решение") { fullSolution = SheetProblem(problem: problem) }
                        }
                    }
                }
            case .correctNotSimplest(let issue):
                BitBubble(mood: .hint, title: issue.message, subtitle: "Ответ: \(problem.answerText)", bitSize: 90)
                GlassButton(title: "Полное решение", systemImage: "list.number") { fullSolution = SheetProblem(problem: problem) }
            case .wrong(let mistake):
                BitBubble(mood: .wrong, title: mistake?.message ?? "Почти. Смотри шаги ниже.",
                          subtitle: mistake.map { _ in "Смотри шаги ниже." }, bitSize: 90)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Как решать").font(.headline)
                        Spacer()
                        Text("уровень 1").font(.caption).foregroundStyle(Color.sub)
                    }
                    if let hint = mistake?.kind.hint {
                        Text(hint).font(.subheadline).foregroundStyle(Color.sub)
                    }
                    StepList(steps: problem.steps)
                    Divider().overlay(Color.hairline)
                    HStack {
                        Text("Ответ").foregroundStyle(Color.sub)
                        Spacer()
                        MathText(text: problem.answerText, size: 22)
                    }
                }
                .contentCard()
            case .unverifiable(let why):
                BitBubble(mood: .waiting, title: "Не понял запись.", subtitle: why, bitSize: 80)
            }
        }
    }

    @ViewBuilder
    private func bottomControls(_ problem: Problem) -> some View {
        VStack(spacing: 10) {
            switch phase {
            case .input:
                MathKeyboard(editor: $editor, set: KeyboardSet.forTopic(problem.topicID))
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        PrimaryButton(title: "Проверить", systemImage: "checkmark") { check(problem) }
                            .disabled(editor.isEmpty)
                        GlassButton(title: "Дальше", fill: false) { next() }
                            .disabled(true)
                    }
                }
            case .checked(let status):
                if case .wrong = status {
                    UnderstoodButtons(onNotUnderstood: {
                        model.notUnderstood(problem.topicID)
                        explanation = SheetProblem(problem: problem, level: 2)
                    }, onUnderstood: { insertSimilar(problem) })
                } else if case .unverifiable = status {
                    GlassButton(title: "Исправить запись") { phase = .input }
                } else {
                    PrimaryButton(title: "Дальше", systemImage: "arrow.right") { next() }
                }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 8)
    }

    // MARK: Действия

    private func setup() {
        guard problems.isEmpty else { return }
        if let preset {
            problems = preset.problems
            index = preset.index
            editor = MathEditor(text: preset.answer)
            phase = preset.phase
        } else {
            problems = model.makeSession(request)
        }
        start = Date()
    }

    private func check(_ problem: Problem) {
        let status = problem.check(editor.text)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { phase = .checked(status) }
        if case .unverifiable = status { return }
        model.record(problem, status: status)
        results.append((problem.topicID, status.isCorrect))
        if status.isCorrect { successTick += 1 } else { errorTick += 1 }
    }

    private func next() {
        editor.clear()
        if index + 1 >= problems.count {
            model.finishSession(results, seconds: Int(Date().timeIntervalSince(start)), isReview: request.isReview)
            withAnimation(.spring) { finished = true }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                index += 1
                phase = .input
            }
        }
    }

    /// «Понял» после ошибки или «Похожий пример»: следующий пример той же темы.
    private func insertSimilar(_ problem: Problem) {
        if let p = model.similar(to: problem) {
            problems.insert(p, at: index + 1)
        }
        next()
    }

    private func restart() {
        problems = model.makeSession(request)
        results = []
        index = 0
        phase = .input
        editor.clear()
        start = Date()
        finished = false
    }
}

struct LessonID: Identifiable {
    let id: String
}
