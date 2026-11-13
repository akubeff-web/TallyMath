import SwiftUI
import MathCore

/// Открывает нужный экран сразу по launch-аргументам — для скриншотов в CI.
/// Пример: -previewScreen training -previewState wrong
struct PreviewRouter: View {
    let options: LaunchOptions
    @Environment(AppModel.self) private var model

    /// Один и тот же пример на всех скриншотах: 1/3 + 1/6.
    private var fractions: Problem { (try? CustomProblem.make("1/3 + 1/6").get()) ?? Course.topics[0].example(seed: 1) }

    var body: some View {
        Group {
            switch options.screen ?? "" {
            case "home": RootView(tab: 0)
            case "course": RootView(tab: 1)
            case "stats": RootView(tab: 2)
            default:
                NavigationStack { screen.withRoutes() }
            }
        }
        .onAppear(perform: prepareData)
    }

    @ViewBuilder
    private var screen: some View {
        let state = options.state ?? ""
        switch options.screen ?? "" {
        case "training":
            let answer = state == "wrong" ? "2/9" : (state == "correct" ? "1/2" : "")
            let phase: TrainingView.Phase = state == "input" ? .input : .checked(fractions.check(answer))
            TrainingView(request: SessionRequest(topicIDs: [fractions.topicID]),
                         preset: TrainingPreset(problems: [fractions] + (1...9).map { Course.topic("g6.addGen")!.example(seed: UInt64($0)) },
                                                index: 0, answer: answer, phase: phase))
        case "lesson":
            switch state {
            case "level1": ExplanationView(problem: fractions, startLevel: 1, onDone: {})
            case "level2": ExplanationView(problem: fractions, startLevel: 2, onDone: {})
            case "level3": ExplanationView(problem: fractions, startLevel: 3, onDone: {})
            default: LessonView(topicID: "g6.addGen")
            }
        case "fullSolution":
            FullSolutionView(problem: fractions, onDone: {})
        case "result":
            if state == "perfect" {
                let ps = (1...10).map { Course.topic("g5.sameAdd")!.example(seed: UInt64($0)) }
                ResultView(problems: ps, results: ps.map { ($0.topicID, true) }, isReview: false, onHome: {}, onMore: {})
            } else {
                let ps = [fractions] + (1...9).map { Course.topic("g6.addGen")!.example(seed: UInt64($0)) }
                ResultView(problems: ps, results: ps.enumerated().map { ($0.element.topicID, $0.offset != 0 && $0.offset != 6) },
                           isReview: false, onHome: {}, onMore: {})
            }
        case "statsTopic":
            TopicStatsView(topicID: "g6.addGen")
        case "solve":
            switch state {
            case "error":
                SolveView(problem: fractions, preset: SolvePreset(lines: ["= 2/3 + 1/6"], checked: true))
            case "algebra":
                let q = (try? CustomProblem.make("x² − 5x + 6 = 0").get()) ?? fractions
                SolveView(problem: q, preset: SolvePreset(lines: ["D = 25 − 24 = 1", "по Виета подбираю 2 и 3", "x = 2 или x = 3"],
                                                          quick: true, checked: true))
            default:
                SolveView(problem: fractions, preset: SolvePreset(lines: ["= 2/6 + 1/6", "= 3/6"], checked: true))
            }
        case "custom":
            CustomExampleView(presetText: "3/4 − 2/3")
        case "topicCard":
            TopicCardView(topicID: "g5.percent")
        case "draft":
            DraftView()
        case "bit":
            BitSheet()
        default:
            HomeView()
        }
    }

    /// Демо-данные под состояние: на главной без повторения — показываем слабое место.
    private func prepareData() {
        if options.screen == "home" && options.state != "review" {
            model.progress.topics["g5.sameAdd"]?.review = nil
        }
    }
}

/// Все состояния Bit на одном экране — для проверки рисунка.
struct BitSheet: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(BitMood.allCases) { mood in
                    VStack {
                        BitView(mood: mood, size: 150)
                        Text(mood.rawValue).font(.footnote).foregroundStyle(Color.sub)
                    }
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Bit")
    }
}
