/// Прогресс хранится локально в JSON. Дата — номер дня (дни с 1970-01-01), чтобы логика не зависела от часов и легко тестировалась.
public struct TopicProgress: Codable, Sendable, Hashable {
    public var attempts = 0
    public var correct = 0
    /// Последние 20 ответов: верно / неверно.
    public var recent: [Bool] = []
    /// Дни, когда нажимали «Не понял».
    public var notUnderstoodDays: [Int] = []
    /// Сколько раз встречалась каждая ошибка (ключ — MistakeKind.rawValue).
    public var mistakes: [String: Int] = [:]
    public var review: ReviewState?
    /// Сколько раз ответ был «верно, но не в простейшем виде».
    public var notSimplest = 0

    public init() {}

    /// Точность по последним ответам (nil — ещё не решали).
    public var accuracy: Rational? {
        guard !recent.isEmpty else { return nil }
        return Rational.of(recent.filter { $0 }.count, recent.count)
    }

    public var accuracyPercent: Int? {
        accuracy.map { $0.num * 100 / $0.den }
    }
}

/// Повторение освоенной темы: этап и день следующего повтора.
public struct ReviewState: Codable, Sendable, Hashable {
    /// Интервалы между повторами, в днях.
    public static let intervals = [1, 3, 7, 14, 30, 60]

    public var stage: Int
    public var dueDay: Int
    public var masteredDay: Int
    public var history: [ReviewEntry]

    public var nextInterval: Int { Self.intervals[min(stage, Self.intervals.count - 1)] }
}

public struct ReviewEntry: Codable, Sendable, Hashable {
    public var day: Int
    public var correct: Int
    public var total: Int
    public var mastered: Bool
}

public struct SessionRecord: Codable, Sendable, Hashable {
    public var day: Int
    public var topicIDs: [String]
    public var results: [Bool]
    public var seconds: Int
    public var isReview: Bool

    public var correctCount: Int { results.filter { $0 }.count }
}

public struct ProgressStore: Codable, Sendable, Hashable {
    public var topics: [String: TopicProgress] = [:]
    public var sessions: [SessionRecord] = []
    /// День → сколько примеров решено.
    public var solvedByDay: [Int: Int] = [:]
    public var streak = 0
    public var bestStreak = 0

    public init() {}

    public func progress(_ id: String) -> TopicProgress { topics[id] ?? TopicProgress() }

    public var totalSolved: Int { topics.values.reduce(0) { $0 + $1.attempts } }

    public var accuracyPercent: Int? {
        let all = topics.values.reduce(into: (0, 0)) { $0.0 += $1.correct; $0.1 += $1.attempts }
        return all.1 == 0 ? nil : all.0 * 100 / all.1
    }

    /// Ответ на один пример.
    public mutating func record(topicID: String, status: LineStatus, day: Int) {
        var p = progress(topicID)
        p.attempts += 1
        let ok = status.isCorrect
        if ok { p.correct += 1 }
        p.recent.append(ok)
        if p.recent.count > 20 { p.recent.removeFirst(p.recent.count - 20) }
        if case .wrong(let m?) = status { p.mistakes[m.kind.rawValue, default: 0] += 1 }
        if case .correctNotSimplest = status { p.notSimplest += 1 }
        topics[topicID] = p
        solvedByDay[day, default: 0] += 1
        streak = ok ? streak + 1 : 0
        bestStreak = max(bestStreak, streak)
    }

    /// «Не понял»: тема становится слабой и чаще попадается.
    public mutating func recordNotUnderstood(topicID: String, day: Int) {
        var p = progress(topicID)
        p.notUnderstoodDays.append(day)
        if p.notUnderstoodDays.count > 20 { p.notUnderstoodDays.removeFirst() }
        topics[topicID] = p
    }

    /// Итог сессии. 10/10 по одной теме — тема освоена и уходит на повторение;
    /// на повторении 2 ошибки и больше — интервал снова короткий.
    public mutating func finishSession(_ results: [(topicID: String, correct: Bool)], day: Int, seconds: Int, isReview: Bool) {
        let ids = results.map(\.topicID)
        sessions.append(SessionRecord(day: day, topicIDs: ids, results: results.map(\.correct), seconds: seconds, isReview: isReview))
        if sessions.count > 200 { sessions.removeFirst(sessions.count - 200) }

        for id in Set(ids) {
            let mine = results.filter { $0.topicID == id }
            let ok = mine.filter(\.correct).count
            var p = progress(id)
            if isReview, var r = p.review {
                let passed = mine.count - ok <= 1
                r.stage = passed ? min(r.stage + 1, ReviewState.intervals.count - 1) : 0
                r.dueDay = day + (passed ? r.nextInterval : ReviewState.intervals[0])
                r.history.append(ReviewEntry(day: day, correct: ok, total: mine.count, mastered: false))
                p.review = r
            } else if mine.count >= 10 && ok == mine.count {
                var r = p.review ?? ReviewState(stage: 0, dueDay: day + 1, masteredDay: day, history: [])
                r.stage = 0
                r.dueDay = day + ReviewState.intervals[0]
                r.masteredDay = day
                r.history.append(ReviewEntry(day: day, correct: ok, total: mine.count, mastered: true))
                p.review = r
            }
            topics[id] = p
        }
    }

    /// Темы, которым пора на повторение (самые просроченные — первыми).
    public func dueReviews(day: Int) -> [String] {
        var due: [(id: String, day: Int)] = []
        for (id, p) in topics {
            if let r = p.review, r.dueDay <= day { due.append((id, r.dueDay)) }
        }
        due.sort { a, b in a.day != b.day ? a.day < b.day : a.id < b.id }
        return due.map(\.id)
    }

    /// Слабая тема: мало верных ответов или недавно жали «Не понял».
    public func isWeak(_ id: String, day: Int) -> Bool {
        let p = progress(id)
        if p.notUnderstoodDays.filter({ day - $0 <= 14 }).count >= 2 { return true }
        guard p.recent.count >= 5, let a = p.accuracy else { return false }
        return a < Rational.of(7, 10)
    }

    /// Слабые темы, худшие первыми.
    public func weakTopics(day: Int) -> [String] {
        topics.keys.filter { isWeak($0, day: day) }.sorted {
            (progress($0).accuracy ?? .one) < (progress($1).accuracy ?? .one)
        }
    }

    /// Вес темы при подборе примеров: слабые и «пора повторить» выпадают чаще.
    public func weight(_ id: String, day: Int) -> Int {
        let p = progress(id)
        var w = 10
        if let a = p.accuracy, let miss = try? Rational.one.subtracting(a).multiplying(Rational(30)) { w += miss.floor }
        w += min(p.notUnderstoodDays.filter { day - $0 <= 14 }.count * 8, 24)
        if let r = p.review, r.dueDay <= day { w += 15 }
        return w
    }

    /// Самые частые ошибки темы.
    public func topMistakes(_ id: String) -> [(MistakeKind, Int)] {
        progress(id).mistakes.compactMap { k, v in MistakeKind(rawValue: k).map { ($0, v) } }
            .sorted { $0.1 > $1.1 || ($0.1 == $1.1 && $0.0.rawValue < $1.0.rawValue) }
    }
}

/// Подбор примеров для тренировки.
public enum SessionPlanner {
    /// count примеров из тем topicIDs с учётом слабых мест. Один и тот же пример два раза подряд не выпадает.
    public static func plan(topicIDs: [String], count: Int = 10, progress: ProgressStore, day: Int,
                            context: TopicContext = TopicContext(), rng: inout RandomSource) -> [Problem] {
        let defs = topicIDs.compactMap(Course.topic)
        guard !defs.isEmpty else { return [] }
        var result: [Problem] = []
        for _ in 0..<count {
            let def = weightedPick(defs, progress: progress, day: day, rng: &rng)
            var p = def.make(&rng, context)
            var tries = 0
            while tries < 8, let last = result.last, last.id == p.id || result.suffix(3).contains(where: { $0.id == p.id }) {
                p = def.make(&rng, context)
                tries += 1
            }
            result.append(p)
        }
        return result
    }

    /// Повторение: 5 примеров одной темы.
    public static func review(topicID: String, rng: inout RandomSource) -> [Problem] {
        plan(topicIDs: [topicID], count: 5, progress: ProgressStore(), day: 0, rng: &rng)
    }

    static func weightedPick(_ defs: [TopicDef], progress: ProgressStore, day: Int, rng: inout RandomSource) -> TopicDef {
        let weights = defs.map { progress.weight($0.id, day: day) }
        let total = weights.reduce(0, +)
        var x = rng.int(0...(total - 1))
        for (d, w) in zip(defs, weights) {
            if x < w { return d }
            x -= w
        }
        return defs[defs.count - 1]
    }
}
