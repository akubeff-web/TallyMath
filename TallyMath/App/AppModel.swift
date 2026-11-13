import SwiftUI
import Observation
import MathCore

/// Режим тренировки на главной.
enum TrainingMode: String, CaseIterable, Identifiable {
    case multiplication = "Умножение"
    case fractions = "Дроби"
    case mixed = "Вперемешку"

    var id: String { rawValue }
}

/// Запрос на сессию тренировки.
struct SessionRequest: Hashable {
    var topicIDs: [String]
    var count = 10
    var isReview = false
    var title = "Тренировка"
}

/// Состояние приложения: прогресс, настройки, контент «Зачем это нужно».
@Observable
final class AppModel {
    var progress: ProgressStore
    var mode: TrainingMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode") }
    }
    var columns: Set<Int> {
        didSet { UserDefaults.standard.set(Array(columns), forKey: "columns") }
    }
    var fractionTopics: Set<String> {
        didSet { UserDefaults.standard.set(Array(fractionTopics), forKey: "fractionTopics") }
    }
    let why: [String: WhyEntry]
    let isDemo: Bool
    @ObservationIgnored private var rng: RandomSource

    init(demo: Bool = LaunchOptions.current.demoData) {
        isDemo = demo
        let defaults = UserDefaults.standard
        mode = TrainingMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .fractions
        let cols = defaults.array(forKey: "columns") as? [Int] ?? [2, 3, 6, 7, 8]
        columns = Set(cols.isEmpty ? [2, 3, 6, 7, 8] : cols)
        let fr = defaults.array(forKey: "fractionTopics") as? [String] ?? ["g5.sameAdd", "g6.addGen", "g6.sub"]
        fractionTopics = Set(fr)
        why = WhyEntry.loadAll()
        if demo {
            progress = DemoData.progress(today: AppModel.dayNumber())
            rng = RandomSource(seed: 7)
            mode = .fractions
            columns = [2, 3, 6, 7, 8]
            fractionTopics = ["g5.sameAdd", "g6.addGen", "g6.sub"]
        } else {
            progress = Storage.load() ?? ProgressStore()
            rng = RandomSource(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        }
    }

    // MARK: Время

    /// Номер дня по местному времени — MathCore работает с днями, а не с датами.
    static func dayNumber(_ date: Date = Date()) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: start).day ?? 0
    }

    var today: Int { AppModel.dayNumber() }

    // MARK: Сессии

    /// Темы текущего режима на главной.
    var modeTopicIDs: [String] {
        switch mode {
        case .multiplication: return Course.multiplicationTopics
        case .fractions: return fractionTopics.isEmpty ? Course.fractionTopics : Array(fractionTopics).sorted()
        case .mixed: return Course.multiplicationTopics + Course.fractionTopics
        }
    }

    var context: TopicContext { TopicContext(columns: columns.sorted()) }

    func makeSession(_ request: SessionRequest) -> [Problem] {
        if request.isReview, let id = request.topicIDs.first {
            return SessionPlanner.review(topicID: id, rng: &rng)
        }
        return SessionPlanner.plan(topicIDs: request.topicIDs, count: request.count, progress: progress,
                                   day: today, context: context, rng: &rng)
    }

    func similar(to problem: Problem, easy: Bool = false) -> Problem? {
        guard let topic = Course.topic(problem.topicID) else { return nil }
        var ctx = context
        ctx.easy = easy
        var p = topic.make(&rng, ctx)
        var tries = 0
        while p.id == problem.id && tries < 5 {
            p = topic.make(&rng, ctx)
            tries += 1
        }
        return p
    }

    // MARK: Запись результатов

    func record(_ problem: Problem, status: LineStatus) {
        guard !isDemo else { return }
        progress.record(topicID: problem.topicID, status: status, day: today)
        if problem.topicID == "g5.table", let (a, b) = Self.tableFact(problem.display) {
            progress.recordFact(a, b, correct: status.isCorrect)
        }
        save()
    }

    /// Вводный урок по теме показан — дальше задания этой темы без урока.
    func markIntroduced(_ topicID: String) {
        progress.markIntroduced(topicID)
        save()
    }

    func notUnderstood(_ topicID: String) {
        guard !isDemo else { return }
        progress.recordNotUnderstood(topicID: topicID, day: today)
        save()
    }

    func finishSession(_ results: [(topicID: String, correct: Bool)], seconds: Int, isReview: Bool) {
        guard !isDemo else { return }
        progress.finishSession(results, day: today, seconds: seconds, isReview: isReview)
        save()
    }

    func resetProgress() {
        progress = ProgressStore()
        save()
    }

    func save() {
        guard !isDemo else { return }
        Storage.save(progress)
    }

    /// «7 × 8» или «56 : 7» → (7, 8).
    static func tableFact(_ display: String) -> (Int, Int)? {
        let parts = display.split(whereSeparator: { "×:".contains($0) }).map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, let a = parts[0], let b = parts[1] else { return nil }
        return display.contains("×") ? (a, b) : (b, a / max(b, 1))
    }

    // MARK: Подсказки для главной

    var weakTopic: TopicDef? {
        progress.weakTopics(day: today).first.flatMap(Course.topic)
    }

    var dueReview: TopicDef? {
        progress.dueReviews(day: today).first.flatMap(Course.topic)
    }
}

/// Хранение прогресса в JSON-файле в Application Support. Никакой сети.
enum Storage {
    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }

    static func load() -> ProgressStore? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProgressStore.self, from: data)
    }

    static func save(_ store: ProgressStore) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Launch-аргументы для скриншотов в CI: -previewScreen home -previewState correct -demoData YES.
struct LaunchOptions {
    var screen: String?
    var state: String?
    var demoData: Bool

    static let current: LaunchOptions = {
        let d = UserDefaults.standard
        return LaunchOptions(screen: d.string(forKey: "previewScreen"), state: d.string(forKey: "previewState"),
                             demoData: d.bool(forKey: "demoData") || d.string(forKey: "previewScreen") != nil)
    }()
}

/// Тестовые данные для скриншотов: несколько дней занятий, слабая тема, тема на повторении.
enum DemoData {
    static func progress(today: Int) -> ProgressStore {
        var s = ProgressStore()
        func add(_ id: String, _ pattern: [Bool], day: Int) {
            for ok in pattern {
                s.record(topicID: id, status: ok ? .correct : .wrong(MistakeReport(.addedTopsAndBottoms)), day: day)
            }
        }
        add("g5.sameAdd", Array(repeating: true, count: 11) + [false], day: today - 3)
        add("g6.addGen", [true, false, false, true, false, true, false, true, false, true, false, true, true], day: today - 1)
        add("g6.sub", [true, true, false, true, true, true, true, true, false, true], day: today)
        add("g6.reduce", [true, true, false, true, true, true, false, true, true], day: today - 2)
        add("g5.table", [true, true, true, false, true, true, true, true], day: today)
        for (a, b, ok) in [(7, 8, false), (7, 8, false), (6, 9, false), (6, 8, true), (8, 7, false), (6, 7, false), (3, 4, true)] {
            s.recordFact(a, b, correct: ok)
        }
        s.recordNotUnderstood(topicID: "g6.addGen", day: today - 1)
        s.recordNotUnderstood(topicID: "g6.addGen", day: today)
        s.finishSession(Array(repeating: ("g5.sameAdd", true), count: 10), day: today - 3, seconds: 180, isReview: false)
        for i in 0..<10 {
            s.finishSession([("g6.addGen", i % 3 != 0), ("g6.addGen", i > 4), ("g6.addGen", true)], day: today - 10 + i,
                            seconds: 60, isReview: false)
        }
        s.streak = 5
        s.bestStreak = 12
        return s
    }
}
