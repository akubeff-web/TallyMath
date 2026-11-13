/// Весь курс 5–8 классов. Все темы доступны сразу.
public enum Course {
    public static let topics: [TopicDef] = Grade5.topics + Grade6.topics + Grade7.topics + Grade8.topics

    public static func topic(_ id: String) -> TopicDef? {
        topics.first { $0.id == id }
    }

    public static func topics(in grade: Grade) -> [TopicDef] {
        topics.filter { $0.grade == grade }
    }

    /// Разделы класса в порядке курса.
    public static func sections(in grade: Grade) -> [(title: String, topics: [TopicDef])] {
        var order: [String] = []
        var map: [String: [TopicDef]] = [:]
        for t in topics(in: grade) {
            if map[t.section] == nil { order.append(t.section) }
            map[t.section, default: []].append(t)
        }
        return order.map { ($0, map[$0]!) }
    }

    /// Темы режимов на главной.
    public static let multiplicationTopics = ["g5.table"]
    public static let fractionTopics = ["g5.sameAdd", "g5.sameSub", "g6.addDiv", "g6.addGen", "g6.sub", "g6.reduce", "g5.whole"]
}

/// Урок темы: правило и два разобранных примера (попроще и обычный).
public struct Lesson: Sendable {
    public var topic: TopicDef
    public var examples: [Problem]

    public var rule: [String] { topic.rule }
}

extension TopicDef {
    /// Примеры урока. seed меняется кнопкой «Ещё пример».
    public func lesson(seed: UInt64 = 1) -> Lesson {
        Lesson(topic: self, examples: [example(seed: seed, easy: true), example(seed: seed &+ 7)])
    }
}
