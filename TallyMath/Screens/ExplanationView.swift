import SwiftUI
import MathCore

/// Объяснение решения в трёх уровнях: кратко → подробно со стрелками → сам на примере попроще.
/// «Не понял» ведёт на следующий уровень, «Понял» закрывает.
struct ExplanationView: View {
    let problem: Problem
    var startLevel = 1
    var onDone: () -> Void

    @Environment(AppModel.self) private var model
    @State private var level = 1
    @State private var stepIndex = 0
    @State private var easy: Problem?
    @State private var guidedIndex = 0
    @State private var guidedEditor = MathEditor()
    @State private var guidedStatus: LineStatus?
    @State private var showFull = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            Picker("Уровень", selection: $level) {
                Text("Кратко").tag(1)
                Text("Подробно").tag(2)
                Text("Сам").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Metrics.gutter)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch level {
                    case 1: levelOne
                    case 2: levelTwo
                    default: levelThree
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 12)
            }
            if level == 3, let easy, guidedIndex < easy.steps.count, easy.steps[guidedIndex].ask != nil, guidedStatus?.isCorrect != true {
                MathKeyboard(editor: $guidedEditor, set: KeyboardSet.forTopic(easy.topicID))
                    .padding(.horizontal, Metrics.gutter)
            }
            UnderstoodButtons(onNotUnderstood: notUnderstood, onUnderstood: onDone)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 8)
        }
        .screenBackground()
        .navigationTitle("Как решать")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { onDone() } label: { Image(systemName: "xmark") }.accessibilityLabel("Закрыть")
            }
        }
        .onAppear {
            level = startLevel
            if easy == nil { easy = model.similar(to: problem, easy: true) }
        }
        .sheet(isPresented: $showFull) { FullSolutionView(problem: problem, onDone: { showFull = false }) }
        .sensoryFeedback(.success, trigger: guidedIndex)
    }

    private func notUnderstood() {
        model.notUnderstood(problem.topicID)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if level < 3 {
                level += 1
                stepIndex = 0
            } else {
                showFull = true
            }
        }
    }

    // MARK: Уровень 1

    private var levelOne: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Course.topic(problem.topicID)?.title ?? "").font(.title2.weight(.bold))
            MathText(text: problem.display, size: 30, weight: .bold)
            BitBubble(mood: .hint, title: problem.steps.first?.rule ?? "Смотри шаги.", subtitle: "Шагов: \(problem.steps.count)",
                      bitSize: 56)
            StepList(steps: problem.steps).contentCard()
            HStack {
                Text("Вся запись").font(.subheadline).foregroundStyle(Color.sub)
                Spacer()
                Button("Полное решение") { showFull = true }.buttonStyle(.glass)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                MathText(text: problem.fullSolution.joined(separator: " "), size: 22)
            }
            .contentCard(padding: 12)
            Text("«Не понял» — покажу подробнее, со стрелками.").font(.footnote).foregroundStyle(Color.sub)
        }
    }

    // MARK: Уровень 2

    private var levelTwo: some View {
        let steps = problem.steps
        let i = min(stepIndex, max(steps.count - 1, 0))
        return VStack(alignment: .leading, spacing: 14) {
            BitBubble(mood: .hint, title: steps.contains { !$0.arrows.isEmpty } ? "Смотри на стрелки." : "По одному шагу.", bitSize: 56)
            HStack {
                Text("Шаг \(i + 1) из \(steps.count)").font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<steps.count, id: \.self) { k in
                        Capsule().fill(Color.ink.opacity(k <= i ? 1 : 0.15)).frame(width: 16, height: 6)
                    }
                }
            }
            if !steps.isEmpty {
                StepDetail(step: steps[i], previousLine: i == 0 ? problem.display : (steps[i - 1].line ?? problem.display))
                    .id(i)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                      removal: .opacity))
            }
            GlassEffectContainer(spacing: 10) {
                HStack {
                    GlassButton(title: "Назад", systemImage: "chevron.left", fill: false) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { stepIndex = max(0, i - 1) }
                    }
                    .disabled(i == 0)
                    Spacer()
                    GlassButton(title: "Дальше", systemImage: "chevron.right", fill: false) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { stepIndex = min(steps.count - 1, i + 1) }
                    }
                    .disabled(i >= steps.count - 1)
                }
            }
        }
    }

    // MARK: Уровень 3

    @ViewBuilder
    private var levelThree: some View {
        if let easy {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Попроще: ").font(.subheadline.weight(.semibold))
                    MathText(text: easy.display, size: 20)
                    Spacer()
                    Text("Шаг \(min(guidedIndex + 1, easy.steps.count)) из \(easy.steps.count)").font(.footnote).foregroundStyle(Color.sub)
                }
                if guidedIndex < easy.steps.count {
                    let step = easy.steps[guidedIndex]
                    VStack(alignment: .leading, spacing: 12) {
                        MathText(text: guidedIndex == 0 ? easy.display : (easy.steps[guidedIndex - 1].line ?? easy.display), size: 34, weight: .bold)
                            .frame(maxWidth: .infinity)
                        Text(step.ask ?? step.rule).font(.title3.weight(.semibold)).multilineTextAlignment(.leading)
                        if step.ask != nil {
                            EditorView(editor: $guidedEditor, size: 32, placeholder: "Твой ответ")
                                .contentCard(radius: 20, padding: 8)
                        } else {
                            Text(step.detail).foregroundStyle(Color.sub)
                        }
                    }
                    .contentCard()
                    if let s = guidedStatus {
                        BitBubble(mood: s.isCorrect ? .correct : .hint,
                                  title: s.isCorrect ? "Верно." : step.rule,
                                  subtitle: s.isCorrect ? step.detail : (step.why ?? step.detail), bitSize: 56)
                    } else {
                        BitBubble(mood: .waiting, title: "Твой ход.", subtitle: "Один шаг за раз.", bitSize: 56)
                    }
                    GlassEffectContainer(spacing: 10) {
                        HStack(spacing: 10) {
                            GlassButton(title: "Подсказка", systemImage: "lightbulb") {
                                guidedStatus = .wrong(nil)
                            }
                            if step.ask == nil || guidedStatus?.isCorrect == true {
                                PrimaryButton(title: "Дальше", systemImage: "arrow.right") { advanceGuided() }
                            } else {
                                PrimaryButton(title: "Проверить шаг", systemImage: "checkmark") {
                                    guidedStatus = StepAnswer.check(guidedEditor.text, expected: step.answer ?? "")
                                }
                                .disabled(guidedEditor.isEmpty)
                            }
                        }
                    }
                } else {
                    BitBubble(mood: .correct, title: "Готово.", subtitle: "Ответ: \(easy.answerText)", bitSize: 90)
                }
            }
        }
    }

    private func advanceGuided() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            guidedIndex += 1
            guidedStatus = nil
            guidedEditor.clear()
        }
    }
}

/// Один шаг крупно: стрелки «что во что превратилось», откуда множитель, почему не другое, как проверить.
struct StepDetail: View {
    let step: SolutionStep
    let previousLine: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(step.rule).font(.headline)
            if step.arrows.isEmpty {
                MathText(text: previousLine, size: 30, weight: .bold)
                if let line = step.line {
                    Image(systemName: "arrow.down").font(.title3.weight(.semibold))
                    MathText(text: line, size: 30, weight: .bold)
                }
            } else {
                ForEach(Array(step.arrows.enumerated()), id: \.offset) { _, arrow in
                    HStack(spacing: 10) {
                        MathText(text: arrow.from, size: 34, weight: .bold)
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.ink).frame(width: 18, height: 2.4)
                            Text(arrow.label)
                                .font(.numbers(15, .bold))
                                .foregroundStyle(Color.inverse)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.ink))
                            Image(systemName: "arrow.right").font(.headline)
                        }
                        MathText(text: arrow.to, size: 34, weight: .bold)
                            .padding(4)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.ink, lineWidth: 2.4))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Text(step.detail).font(.subheadline).foregroundStyle(Color.sub)
            if let why = step.why {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Почему так").font(.caption).foregroundStyle(Color.inverse.opacity(0.75))
                    Text(why).font(.headline).foregroundStyle(Color.inverse)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.ink))
            }
            if let whyNot = step.whyNot {
                Label { Text(whyNot).font(.subheadline) } icon: { Image(systemName: "xmark.circle") }
            }
            if let check = step.check {
                Label { Text("Проверка: ").font(.subheadline.weight(.semibold)) + Text(check).font(.subheadline) }
                    icon: { Image(systemName: "checkmark") }
            }
        }
        .contentCard()
    }
}

/// Полное решение одной цепочкой сверху вниз; между строками — действие («× 2», «÷ 3»).
struct FullSolutionView: View {
    let problem: Problem
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MathText(text: problem.display, size: 30, weight: .bold)
                        .padding(.bottom, 8)
                    ForEach(Array(problem.steps.enumerated()), id: \.offset) { _, step in
                        if let line = step.line {
                            HStack(alignment: .center, spacing: 10) {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.down").font(.subheadline.weight(.semibold))
                                    if let label = step.arrows.first?.label {
                                        Text(label).font(.numbers(12, .bold)).foregroundStyle(Color.inverse)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Capsule().fill(Color.ink))
                                    }
                                }
                                .frame(width: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.rule).font(.subheadline.weight(.semibold))
                                    Text(step.detail).font(.caption).foregroundStyle(Color.sub)
                                }
                            }
                            .padding(.vertical, 6)
                            MathText(text: line, size: 26, weight: .bold)
                                .padding(.bottom, 6)
                        }
                    }
                    Divider().overlay(Color.hairline).padding(.vertical, 10)
                    HStack {
                        Label("Ответ", systemImage: "checkmark").foregroundStyle(Color.sub)
                        Spacer()
                        MathText(text: problem.answerText, size: 24)
                    }
                }
                .padding(Metrics.gutter)
            }
            .screenBackground()
            .navigationTitle("Полное решение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onDone() } label: { Image(systemName: "xmark") }.accessibilityLabel("Закрыть")
                }
            }
        }
        .presentationDetents([.large])
    }
}
