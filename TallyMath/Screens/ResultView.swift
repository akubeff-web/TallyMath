import SwiftUI
import MathCore

/// Итоги сессии: счёт, ряд верных и неверных, ошибки с разбором, слабое место и повторение.
struct ResultView: View {
    let problems: [Problem]
    let results: [(topicID: String, correct: Bool)]
    let isReview: Bool
    var onHome: () -> Void
    var onMore: () -> Void

    @Environment(AppModel.self) private var model
    @State private var explanation: SheetProblem?

    private var correct: Int { results.filter { $0.correct }.count }
    private var perfect: Bool { !results.isEmpty && correct == results.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                BitView(mood: perfect ? .streak : (correct * 2 >= results.count ? .correct : .waiting), size: 170)
                Text("\(correct) из \(results.count)").font(.numbers(46, .bold))
                Text(subtitle).font(.subheadline).foregroundStyle(Color.sub)
                squares
                if let topic = masteredTopic {
                    masteredCard(topic)
                }
                if !mistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ошибки").font(.headline)
                        ForEach(mistakes, id: \.id) { p in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Course.topic(p.topicID)?.title ?? "").font(.caption).foregroundStyle(Color.sub)
                                    HStack(spacing: 6) {
                                        MathText(text: p.display, size: 20)
                                        Text("=").font(.numbers(20))
                                        MathText(text: p.answerText, size: 20)
                                    }
                                }
                                Spacer()
                                Button("Разобрать") { explanation = SheetProblem(problem: p, level: 1) }
                                    .buttonStyle(.glass)
                            }
                        }
                    }
                    .contentCard()
                }
                if let weak = model.weakTopic {
                    BitBubble(mood: .hint, title: "Слабое место: \(weak.title.lowercased()).",
                              subtitle: "Следующие примеры — чаще по нему.", bitSize: 56)
                }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .safeAreaInset(edge: .bottom) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    GlassButton(title: "На главную", action: onHome)
                    PrimaryButton(title: isReview ? "Ещё раз" : "Ещё 10 примеров", action: onMore)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
        }
        .sheet(item: $explanation) { item in
            NavigationStack { ExplanationView(problem: item.problem, startLevel: item.level, onDone: { explanation = nil }) }
        }
    }

    private var subtitle: String {
        let acc = results.isEmpty ? 0 : correct * 100 / results.count
        return isReview ? "Повторение · точность \(acc)%" : "Серия \(model.progress.streak) · точность \(acc)%"
    }

    private var mistakes: [Problem] {
        zip(problems, results).filter { !$0.1.correct }.map { $0.0 }
    }

    /// 10/10 по одной теме — тема освоена.
    private var masteredTopic: TopicDef? {
        guard perfect, results.count >= 10, Set(results.map { $0.topicID }).count == 1 else { return nil }
        return Course.topic(results[0].topicID)
    }

    private var squares: some View {
        HStack(spacing: 6) {
            ForEach(Array(results.enumerated()), id: \.offset) { _, r in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(r.correct ? Color.ink : .clear)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ink, lineWidth: 1.5))
                    .overlay(Image(systemName: r.correct ? "checkmark" : "xmark").font(.caption.weight(.bold))
                        .foregroundStyle(r.correct ? Color.inverse : Color.ink))
                    .frame(width: 26, height: 26)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Верно \(correct) из \(results.count)")
    }

    private func masteredCard(_ topic: TopicDef) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Тема освоена")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.inverse)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(Color.ink))
            Text("Повторю завтра, чтобы запомнилось.").font(.headline)
            ReviewTimeline(done: 0)
            Text("5 примеров на каждое повторение").font(.footnote).foregroundStyle(Color.sub)
        }
        .contentCard()
    }
}

/// График повторений 1–3–7–14–30 дней: пройденные залиты, следующее обведено.
struct ReviewTimeline: View {
    /// Сколько этапов пройдено (0 — только что освоили).
    let done: Int

    var body: some View {
        let labels = ["сегодня", "1 д", "3 д", "7 д", "14 д", "30 д"]
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { i in
                VStack(spacing: 6) {
                    ZStack {
                        if i <= done {
                            Circle().fill(Color.ink).frame(width: 18, height: 18)
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .black)).foregroundStyle(Color.inverse)
                        } else if i == done + 1 {
                            Circle().strokeBorder(Color.ink, lineWidth: 2.4).frame(width: 20, height: 20)
                        } else {
                            Circle().strokeBorder(Color.ink.opacity(0.35), lineWidth: 1.6).frame(width: 12, height: 12)
                        }
                    }
                    .frame(height: 22)
                    Text(labels[i]).font(.caption2.weight(i == done + 1 ? .bold : .regular))
                        .foregroundStyle(i == done + 1 ? Color.ink : Color.sub)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Повторения: через 1, 3, 7, 14 и 30 дней. Пройдено этапов: \(done).")
    }
}
