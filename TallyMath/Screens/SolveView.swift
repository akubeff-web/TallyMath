import SwiftUI
import MathCore

/// Начальное состояние «Решаю сам» — для скриншотов.
struct SolvePreset {
    var lines: [String]
    var quick = false
    var checked = false
}

/// «Решаю сам»: тетрадь, строки решения одна под другой, проверка по шагам или быстрая.
struct SolveView: View {
    let problem: Problem
    var preset: SolvePreset?

    @Environment(AppModel.self) private var model
    @State private var lines: [MathEditor] = [MathEditor()]
    @State private var statuses: [LineStatus?] = [nil]
    @State private var active = 0
    @State private var quick = false
    @State private var showSolution = false
    @State private var showDraft = false
    @State private var hint: String?
    @State private var recorded = false
    @State private var tick = 0

    init(problem: Problem, preset: SolvePreset? = nil) {
        self.problem = problem
        self.preset = preset
    }

    var body: some View {
        VStack(spacing: 10) {
            Picker("Режим", selection: $quick) {
                Text("По шагам").tag(false)
                Text("Быстрый").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Metrics.gutter)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    notebook
                    if let message = bitMessage {
                        BitBubble(mood: message.mood, title: message.title, subtitle: message.subtitle, bitSize: 60)
                        if message.mood == .hint {
                            GlassEffectContainer(spacing: 10) {
                                HStack(spacing: 10) {
                                    GlassButton(title: "Подсказка", systemImage: "lightbulb") { hint = stepHint }
                                    GlassButton(title: "Показать решение", systemImage: "eye") { showSolution = true }
                                }
                            }
                            if let hint { Text(hint).font(.subheadline).contentCard(radius: 18, padding: 12) }
                        }
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            MathKeyboard(editor: $lines[active], set: KeyboardSet.forTopic(problem.topicID))
                .padding(.horizontal, Metrics.gutter)
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    GlassButton(title: "Проверить шаг") { checkStep() }
                    PrimaryButton(title: "Проверить всё", systemImage: "checkmark") { checkAll() }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
        }
        .screenBackground()
        .navigationTitle("Решаю сам")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showDraft = true } label: { Label("Черновик", systemImage: "pencil") }.labelStyle(.titleAndIcon)
            }
        }
        .sheet(isPresented: $showSolution) { FullSolutionView(problem: problem, onDone: { showSolution = false }) }
        .sheet(isPresented: $showDraft) { NavigationStack { DraftView() } }
        .sensoryFeedback(.selection, trigger: tick)
        .onAppear(perform: applyPreset)
    }

    private var notebook: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Пример · \(Course.topic(problem.topicID).map { "\($0.grade.title) · \($0.title.lowercased())" } ?? "")")
                .font(.caption.weight(.semibold)).foregroundStyle(Color.sub)
            if let story = problem.story { Text(story).font(.subheadline) }
            MathText(text: problem.display, size: 26, weight: .bold).padding(.leading, 34)
            ForEach(lines.indices, id: \.self) { i in
                HStack(alignment: .center, spacing: 10) {
                    LineStatusIcon(status: statuses[safe: i] ?? nil).frame(width: 24)
                    Group {
                        if i == active {
                            EditorView(editor: $lines[i], size: 26, placeholder: "= …")
                        } else {
                            MathText(text: lines[i].isEmpty ? "…" : lines[i].text, size: 24,
                                     color: isWrong(i) ? .inverse : .ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { active = i }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .background {
                    // Первая ошибочная строка — инверсия заливки.
                    if isWrong(i) && i != active {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.ink)
                    }
                }
            }
            HStack {
                Button {
                    lines.append(MathEditor())
                    statuses.append(nil)
                    active = lines.count - 1
                    tick += 1
                } label: { Label("шаг", systemImage: "plus").font(.subheadline.weight(.semibold)) }
                    .buttonStyle(.glass)
                Spacer()
                Text("строка \(active + 1) из \(lines.count)").font(.caption).foregroundStyle(Color.sub)
            }
        }
        .padding(16)
        .background(NotebookPaper().clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)))
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Color.card))
    }

    private func isWrong(_ i: Int) -> Bool {
        if case .wrong? = statuses[safe: i] ?? nil { return i == firstWrong }
        return false
    }

    private var firstWrong: Int? {
        statuses.firstIndex { s in if case .wrong? = s { return true } else { return false } }
    }

    private var bitMessage: (mood: BitMood, title: String, subtitle: String?)? {
        if let i = firstWrong, case .wrong(let m)? = statuses[i] {
            return (.hint, m?.message ?? "В строке \(i + 1) ошибка.", "Исправь строку \(i + 1).")
        }
        if let last = statuses.last, let s = last {
            switch s {
            case .correct where recorded: return (.correct, "Верно.", "Решение проверено.")
            case .correctNotSimplest(let issue): return (.hint, issue.message, nil)
            case .unverifiable(let why): return (.waiting, "Не удалось проверить этот шаг.", why)
            default: return nil
            }
        }
        return nil
    }

    /// Подсказка к шагу: правило соответствующего шага решения, без готового ответа.
    private var stepHint: String {
        let i = min(firstWrong ?? active, max(problem.steps.count - 1, 0))
        guard i < problem.steps.count else { return "Сравни с правилом темы." }
        if case .wrong(let m?)? = statuses[safe: firstWrong ?? -1] ?? nil { return m.kind.hint }
        return problem.steps[i].rule
    }

    private func texts() -> [String] { lines.map(\.text) }

    private func checkStep() {
        let all = problem.checkNotebook(Array(texts().prefix(active + 1)), mode: quick ? .quick : .steps)
        for (i, s) in all.enumerated() { statuses[i] = s }
        hint = nil
        tick += 1
        if let s = all.last, s.isCorrect, firstWrong == nil, active == lines.count - 1 {
            lines.append(MathEditor())
            statuses.append(nil)
            active += 1
        }
    }

    private func checkAll() {
        let all = texts()
        let indices = all.indices.filter { !all[$0].isEmpty }
        guard let lastIndex = indices.last else { return }
        let result = problem.checkNotebook(indices.map { all[$0] }, mode: quick ? .quick : .steps)
        for (k, i) in indices.enumerated() { statuses[i] = result[k] }
        hint = nil
        tick += 1
        // Итог: последняя строка должна быть верным ответом в простейшем виде.
        let final = problem.check(all[lastIndex])
        var verifiable = true
        if case .unverifiable = final { verifiable = false }
        if !recorded && verifiable {
            model.record(problem, status: final)
            recorded = true
        }
        if verifiable, final != .correct, statuses[lastIndex]?.isCorrect == true {
            statuses[lastIndex] = final
        }
    }

    private func applyPreset() {
        guard let preset, lines.count == 1, lines[0].isEmpty else { return }
        quick = preset.quick
        lines = preset.lines.map { MathEditor(text: $0) } + [MathEditor()]
        statuses = Array(repeating: nil, count: lines.count)
        active = lines.count - 1
        if preset.checked {
            let r = problem.checkNotebook(preset.lines, mode: preset.quick ? .quick : .steps)
            for (i, s) in r.enumerated() { statuses[i] = s }
            if r.contains(where: { if case .wrong = $0 { return true }; return false }) {
                lines.removeLast()
                statuses.removeLast()
                active = 0
            }
        }
    }
}

/// Клетка тетради.
struct NotebookPaper: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            stride(from: 0, through: size.width, by: 16).forEach { x in
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: 0, through: size.height, by: 16).forEach { y in
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(p, with: .color(Color.ink.opacity(0.06)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
