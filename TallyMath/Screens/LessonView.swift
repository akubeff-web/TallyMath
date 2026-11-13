import SwiftUI
import MathCore

/// Урок темы: правило и два разобранных примера. «Ещё пример» меняет примеры, «Не понял» — подробное объяснение.
struct LessonView: View {
    let topicID: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var seed: UInt64 = 1
    @State private var explanation: SheetProblem?

    var body: some View {
        let topic = Course.topic(topicID)
        let lesson = topic?.lesson(seed: seed)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let topic, let lesson {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.title).font(.title2.weight(.bold))
                        Text("\(topic.grade.title) · \(topic.section)").font(.subheadline).foregroundStyle(Color.sub)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            SectionLabel(text: "Правило")
                            BitView(mood: .idle, size: 52)
                        }
                        ForEach(lesson.rule, id: \.self) { line in
                            Text(line).font(.body.weight(.semibold))
                        }
                    }
                    .contentCard()
                    ForEach(Array(lesson.examples.enumerated()), id: \.offset) { i, p in
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: i == 0 ? "Пример 1 · попроще" : "Пример 2")
                            if let story = p.story { Text(story).font(.subheadline) }
                            MathText(text: p.display, size: 28, weight: .bold)
                            StepList(steps: p.steps)
                            HStack {
                                Text("Ответ").foregroundStyle(Color.sub)
                                Spacer()
                                MathText(text: p.answerText, size: 22)
                            }
                        }
                        .contentCard()
                    }
                    NavigationLink(value: Route.training(SessionRequest(topicIDs: [topicID], title: topic.title))) {
                        Label("Тренировать тему", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            UnderstoodButtons(onNotUnderstood: {
                model.notUnderstood(topicID)
                if let p = lesson?.examples.last { explanation = SheetProblem(problem: p, level: 2) }
            }, onUnderstood: { dismiss() })
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
        }
        .screenBackground()
        .navigationTitle("Урок")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ещё пример") { withAnimation(.spring) { seed &+= 13 } }
            }
        }
        .sheet(item: $explanation) { item in
            NavigationStack { ExplanationView(problem: item.problem, startLevel: item.level, onDone: { explanation = nil }) }
        }
    }
}
