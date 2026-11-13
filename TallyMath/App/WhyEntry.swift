import Foundation

/// Блок «Зачем это нужно» для темы. Контент собран на этапе разработки (why.json), в приложении сети нет.
struct WhyEntry: Codable, Hashable {
    struct Source: Codable, Hashable {
        var site: String
        var url: String
        var summary: String
        var checked: String
    }

    var topic: String
    /// «нужно», «желательно» или «можно пропустить».
    var verdict: String
    /// На чём основана оценка.
    var reason: String
    /// Где встречается в программировании (или null).
    var programming: String?
    /// Где пригодится в жизни, если в программировании не нужна.
    var life: String?
    /// Короткий пример на Swift (проверяется в CI через swiftc -typecheck).
    var swift: String?
    var sources: [Source]

    static func loadAll() -> [String: WhyEntry] {
        guard let url = Bundle.main.url(forResource: "why", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([WhyEntry].self, from: data) else { return [:] }
        return Dictionary(list.map { ($0.topic, $0) }, uniquingKeysWith: { a, _ in a })
    }
}
