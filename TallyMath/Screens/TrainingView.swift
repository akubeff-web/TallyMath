import SwiftUI
import MathCore

/// Начальное состояние тренировки — для скриншотов.
struct TrainingPreset {
    var problems: [Problem]
    var index = 0
    var answer = ""
    var phase: TrainingView.Phase = .input
}

/// Тренировка. Порядок: новая тема → сначала урок; потом задание, решение записывается по строкам,
/// проверяется каждая строка и итог. «Не знаю, как решать» — разбор этого примера без штрафа.
struct TrainingView: View {
    enum Phase: Equatable {
        /// Урок перед первым заданием новой темы.
        case intro
        case input
        case checked(LineStatus)
    }

    let request: SessionRequest
    var preset: TrainingPreset?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var problems: [Problem] = []
    @State private var index = 0
    @State private var lines: [MathEditor] = [MathEditor()]
    @State private var lineStatuses: [LineStatus?] = [nil]
    @State private var active = 0
    @State private var phase: Phase = .input
    @State private var introStep = 0
    @State private var results: [(topicID: String, correct: Bool)] = []
    @State private var start = Date()
    @State private var explanation: SheetProblem?
    @State private var fullSolution: SheetProblem?
    @State private var lessonTopic: String?
    @State private var finished = false
    @State private var successTick = 0
    @State private var errorTick = 0
    /// «Не знаю, как решать»: после разбора этот пример пропускаем без штрафа.
    @State private var skipAfterExplanation = false

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
        .sheet(item: $explanation, onDismiss: afterExplanation) { item in
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
            if !finished, let p = current, phase != .intro {
                Button { lessonTopic = p.topicID } label: { Label("Урок", systemImage: "book") }
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    @ViewBuilder
    private func content(_ problem: Problem) -> some View {
        VStack(spacing: 14) {
            progressBar
            if phase == .intro {
                TopicIntro(topicID: problem.topicID, step: $introStep)
            } else {
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
                        case .input: solutionArea(problem)
                        case .checked(let status): feedback(problem, status)
                        case .intro: EmptyView()
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
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

    /// Решение по строкам, как в тетради: «= 2/6 + 1/6», «= 3/6», «= 1/2».
    private func solutionArea(_ problem: Problem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                BitView(mood: .waiting, size: 64)
                Text("Запиши решение по шагам — каждую строку с «=». Последняя строка — ответ.")
                    .font(.footnote).foregroundStyle(Color.sub)
            }
            ForEach(lines.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    LineStatusIcon(status: lineStatuses[safe: i] ?? nil).frame(width: 22)
                    Group {
                        if i == active {
                            EditorView(editor: $lines[i], size: 28, placeholder: i == 0 ? "= …" : "= …")
                        } else {
                            MathText(text: lines[i].isEmpty ? "…" : lines[i].text, size: 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { active = i }
                }
                .padding(.vertical, 4)
            }
            HStack {
                Button {
                    lines.append(MathEditor())
                    lineStatuses.append(nil)
                    active = lines.count - 1
                } label: { Label("строка", systemImage: "plus").font(.subheadline.weight(.semibold)) }
                    .buttonStyle(.glass)
                Spacer()
                Text("Смешанное число: целая часть, потом «смеш.»").font(.caption2).foregroundStyle(Color.sub)
            }
        }
        .padding(14)
        .background(NotebookPaper().clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)))
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Color.card))
    }

    @ViewBuilder
    private func feedback(_ problem: Problem, _ status: LineStatus) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lines.indices, id: \.self) { i in
                        if !lines[i].isEmpty {
                            HStack(spacing: 8) {
                                LineStatusIcon(status: lineStatuses[safe: i] ?? nil).frame(width: 22)
                                MathText(text: lines[i].text, size: 22)
                            }
                        }
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
                          subtitle: firstWrongLine.map { "Ошибка в строке \($0 + 1)." }, bitSize: 90)
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

    private var firstWrongLine: Int? {
        lineStatuses.firstIndex { s in if case .wrong? = s { return true } else { return false } }
    }

    @ViewBuilder
    private func bottomControls(_ problem: Problem) -> some View {
        VStack(spacing: 10) {
            switch phase {
            case .intro:
                UnderstoodButtons(onNotUnderstood: {
                    model.notUnderstood(problem.topicID)
                    if let topic = Course.topic(problem.topicID) {
                        explanation = SheetProblem(problem: topic.example(seed: 3), level: 2)
                    }
                }, onUnderstood: {
                    model.markIntroduced(problem.topicID)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { phase = .input }
                })
            case .input:
                MathKeyboard(editor: $lines[active], set: KeyboardSet.forTopic(problem.topicID))
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        GlassButton(title: "Не знаю, как решать", systemImage: "questionmark.circle") {
                            skipAfterExplanation = true
                            explanation = SheetProblem(problem: problem, level: 2)
                        }
                        PrimaryButton(title: "Проверить", systemImage: "checkmark") { check(problem) }
                            .disabled(lines.allSatisfy { $0.isEmpty })
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
            lines = [MathEditor(text: preset.answer)]
            lineStatuses = [nil]
            phase = preset.phase
            if case .checked = phase, let p = current {
                lineStatuses = p.checkNotebook([preset.answer], mode: .steps).map { Optional($0) }
            }
        } else {
            problems = model.makeSession(request)
            phase = introNeeded ? .intro : .input
        }
        start = Date()
    }

    /// Урок нужен, если тему ещё не объясняли.
    private var introNeeded: Bool {
        guard let p = current, !model.isDemo else { return false }
        return !model.progress.isIntroduced(p.topicID)
    }

    private func check(_ problem: Problem) {
        let texts = lines.map(\.text)
        let indices = texts.indices.filter { !texts[$0].isEmpty }
        guard let last = indices.last else { return }
        // Каждая строка — по шагам; итог — как ответ (простейший вид, целая часть).
        let stepStatuses = problem.checkNotebook(indices.map { texts[$0] }, mode: .steps)
        lineStatuses = Array(repeating: nil, count: lines.count)
        for (k, i) in indices.enumerated() { lineStatuses[i] = stepStatuses[k] }
        var status = problem.check(texts[last])
        if status.isCorrect, let firstWrong = stepStatuses.first(where: { if case .wrong = $0 { return true }; return false }) {
            // Ответ верный, но в промежуточной строке ошибка — засчитываем как ошибку решения.
            status = firstWrong
        } else if !status.isCorrect, case .wrong(nil) = status,
                  let firstWrong = stepStatuses.first(where: { if case .wrong(_?) = $0 { return true }; return false }) {
            status = firstWrong
        }
        lineStatuses[last] = status
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { phase = .checked(status) }
        if case .unverifiable = status { return }
        model.record(problem, status: status)
        results.append((problem.topicID, status.isCorrect))
        if status.isCorrect { successTick += 1 } else { errorTick += 1 }
    }

    private func next() {
        lines = [MathEditor()]
        lineStatuses = [nil]
        active = 0
        if index + 1 >= problems.count {
            model.finishSession(results, seconds: Int(Date().timeIntervalSince(start)), isReview: request.isReview)
            withAnimation(.spring) { finished = true }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                index += 1
                introStep = 0
                phase = introNeeded ? .intro : .input
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

    /// После разбора «Не знаю, как решать» — похожий пример вместо этого, без штрафа.
    private func afterExplanation() {
        guard skipAfterExplanation, let p = current else { return }
        skipAfterExplanation = false
        if let similar = model.similar(to: p) {
            problems[index] = similar
        }
        lines = [MathEditor()]
        lineStatuses = [nil]
        active = 0
        phase = .input
    }

    private func restart() {
        problems = model.makeSession(request)
        results = []
        index = 0
        lines = [MathEditor()]
        lineStatuses = [nil]
        active = 0
        introStep = 0
        phase = introNeeded ? .intro : .input
        start = Date()
        finished = false
    }
}

/// Урок перед первым заданием темы: правило, потом пример по одному шагу.
struct TopicIntro: View {
    let topicID: String
    @Binding var step: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let topic = Course.topic(topicID)
        let example = topic?.example(seed: 3)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let topic {
                    Text("Новая тема").font(.caption.weight(.semibold)).foregroundStyle(Color.sub)
                    Text(topic.title).font(.title2.weight(.bold))
                    BitBubble(mood: .hint, title: "Сначала разберём, потом попробуешь сам.", bitSize: 60)
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Правило")
                        ForEach(topic.rule, id: \.self) { Text($0).font(.body.weight(.semibold)) }
                    }
                    .contentCard()
                }
                if let example, !example.steps.isEmpty {
                    let i = min(step, example.steps.count - 1)
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Пример", trailing: "шаг \(i + 1) из \(example.steps.count)")
                        if let story = example.story { Text(story).font(.subheadline) }
                        MathText(text: example.display, size: 30, weight: .bold)
                    }
                    StepDetail(step: example.steps[i], previousLine: i == 0 ? example.display : (example.steps[i - 1].line ?? example.display))
                        .id(i)
                        .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                    GlassEffectContainer(spacing: 10) {
                        HStack {
                            GlassButton(title: "Назад", systemImage: "chevron.left", fill: false) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { step = max(0, i - 1) }
                            }
                            .disabled(i == 0)
                            Spacer()
                            GlassButton(title: i == example.steps.count - 1 ? "Ответ: \(example.answerText)" : "Следующий шаг",
                                        systemImage: "chevron.right", fill: false) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { step = min(example.steps.count - 1, i + 1) }
                            }
                            .disabled(i == example.steps.count - 1)
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 12)
        }
    }
}

struct LessonID: Identifiable {
    let id: String
}
