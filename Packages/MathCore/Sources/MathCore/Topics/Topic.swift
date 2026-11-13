public enum Grade: Int, Codable, Sendable, CaseIterable, Comparable {
    case five = 5, six, seven, eight

    public static func < (a: Grade, b: Grade) -> Bool { a.rawValue < b.rawValue }
    public var title: String { "\(rawValue) класс" }
}

/// Стрелка на объяснении уровня 2: «1/3 → 2/6, ×2».
public struct Arrow: Sendable, Hashable, Codable {
    public var from: String
    public var to: String
    public var label: String

    public init(_ from: String, _ to: String, _ label: String) {
        self.from = from
        self.to = to
        self.label = label
    }
}

/// Шаг решения. Одни и те же шаги показываются на трёх уровнях:
/// 1 — rule + detail; 2 — ещё why / whyNot / check и стрелки; 3 — ask/answer, ученик вводит сам.
public struct SolutionStep: Sendable, Hashable {
    public var rule: String
    public var detail: String
    /// Строка записи после шага («= 2/6 + 1/6»), если она есть.
    public var line: String?
    public var why: String?
    public var whyNot: String?
    public var check: String?
    public var arrows: [Arrow]
    /// Вопрос для уровня 3 и ответ на него (запись, которую проверит AnswerChecker).
    public var ask: String?
    public var answer: String?

    public init(_ rule: String, _ detail: String, line: String? = nil, why: String? = nil, whyNot: String? = nil,
                check: String? = nil, arrows: [Arrow] = [], ask: String? = nil, answer: String? = nil) {
        self.rule = rule
        self.detail = detail
        self.line = line
        self.why = why
        self.whyNot = whyNot
        self.check = check
        self.arrows = arrows
        self.ask = ask
        self.answer = answer
    }
}

/// Задание.
public struct Problem: Sendable, Hashable, Identifiable {
    public var topicID: String
    /// Что сделать: «Вычисли», «Реши уравнение».
    public var prompt: String
    /// Условие в виде записи — для проверки тетради и распознавания ошибок. nil — у задач со словами.
    public var statement: Statement?
    /// Что показать крупно (запись, которую рисует приложение).
    public var display: String
    /// Текст задачи словами (вероятность, статистика), если есть.
    public var story: String?
    public var expected: Statement
    public var spec: AnswerSpec
    public var steps: [SolutionStep]

    public var id: String { topicID + "|" + display + "|" + (story ?? "") }

    /// Правильный ответ записью.
    public var answerText: String { expected.text }

    /// Полное решение одной цепочкой: условие и строки шагов.
    public var fullSolution: [String] {
        [display] + steps.compactMap(\.line)
    }

    public func check(_ input: String) -> LineStatus {
        AnswerChecker.check(input, problem: statement ?? expected, expected: expected, spec: spec)
    }

    public func checkNotebook(_ lines: [String], mode: LineChecker.Mode) -> [LineStatus] {
        // Деление с остатком: строки «37 = 5 · 7 + 2» проверяем как верные равенства, итог — как ответ.
        if spec.kind == .remainder {
            return lines.map { line in
                guard let s = try? Parser.statement(line) else { return .unverifiable("не понял запись строки") }
                switch s {
                case .remainder: return check(line)
                case .relation(let a, .eq, let b) where !a.hasVariables && !b.hasVariables:
                    guard let ok = equivalent(a, b) else { return .unverifiable("не получилось сравнить") }
                    return ok ? .correct : .wrong(MistakeReport(.arithmetic))
                default: return .unverifiable("здесь ожидается «частное ост. остаток»")
                }
            }
        }
        guard let st = statement else {
            // Для задач словами проверяем только итоговую строку.
            return lines.enumerated().map { i, line in
                i == lines.count - 1 ? check(line) : .unverifiable("промежуточные записи в задаче словами не проверяю")
            }
        }
        return LineChecker.check(problem: st, lines: lines, spec: spec, mode: mode)
    }
}

/// Настройки генерации: облегчённый пример (для уровня 3) и выбранные столбики таблицы умножения.
public struct TopicContext: Sendable {
    public var easy: Bool
    public var columns: [Int]

    public init(easy: Bool = false, columns: [Int] = Array(2...9)) {
        self.easy = easy
        self.columns = columns.isEmpty ? Array(2...9) : columns
    }
}

/// Тема курса: генератор примеров и урок.
public struct TopicDef: Sendable, Identifiable, Hashable {
    public let id: String
    public let grade: Grade
    public let section: String
    public let title: String
    /// Правило урока: 2–4 коротких предложения.
    public let rule: [String]
    let generator: @Sendable (inout RandomSource, TopicContext) -> Problem

    public init(_ id: String, _ grade: Grade, section: String, title: String, rule: [String],
                generator: @escaping @Sendable (inout RandomSource, TopicContext) -> Problem) {
        self.id = id
        self.grade = grade
        self.section = section
        self.title = title
        self.rule = rule
        self.generator = generator
    }

    public func make(_ rng: inout RandomSource, _ context: TopicContext = TopicContext()) -> Problem {
        generator(&rng, context)
    }

    /// Пример с фиксированным зерном — для урока и скриншотов.
    public func example(seed: UInt64, easy: Bool = false) -> Problem {
        var r = RandomSource(seed: seed)
        return make(&r, TopicContext(easy: easy))
    }

    public static func == (a: TopicDef, b: TopicDef) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

/// Детерминированный генератор (SplitMix64): одинаковое зерно — одинаковые примеры, это нужно тестам.
public struct RandomSource: Sendable, RandomNumberGenerator {
    var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func int(_ range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    public mutating func pick<T>(_ items: [T]) -> T {
        items[int(0...(items.count - 1))]
    }

    public mutating func bool() -> Bool { int(0...1) == 1 }

    /// Ненулевое число со случайным знаком.
    public mutating func signed(_ range: ClosedRange<Int>) -> Int {
        int(range) * (bool() ? 1 : -1)
    }
}

/// Разбор записи, которую генерирует сам MathCore (заведомо корректной).
func st(_ text: String) -> Statement {
    do { return try Parser.statement(text) } catch { preconditionFailure("генератор дал непонятную запись: \(text)") }
}

func ex(_ text: String) -> Expr {
    do { return try Parser.expression(text) } catch { preconditionFailure("генератор дал непонятную запись: \(text)") }
}
