import Testing
@testable import MathCore

/// Проверяет каждую тему на многих случайных примерах: верное решение проходит, неверное — нет,
/// а собственные шаги решения проходят проверку тетради.
@Suite("Темы курса")
struct TopicTests {
    static let seeds: [UInt64] = Array(1...30)

    @Test("Курс содержит темы всех классов")
    func courseCoversAllGrades() {
        for g in Grade.allCases { #expect(Course.topics(in: g).count >= 8, "мало тем в \(g.title)") }
        #expect(Set(Course.topics.map(\.id)).count == Course.topics.count, "повторяющиеся id")
    }

    @Test("Правильный ответ принимается", arguments: Course.topics)
    func correctAnswerAccepted(_ topic: TopicDef) {
        for seed in Self.seeds {
            for easy in [false, true] {
                let p = topic.example(seed: seed, easy: easy)
                #expect(p.check(p.answerText) == .correct, "\(topic.id) \(p.display): ответ \(p.answerText) → \(p.check(p.answerText))")
            }
        }
    }

    @Test("Неверный ответ отклоняется", arguments: Course.topics)
    func wrongAnswerRejected(_ topic: TopicDef) {
        for seed in Self.seeds {
            let p = topic.example(seed: seed)
            let wrong = Self.wrongAnswer(for: p)
            let status = p.check(wrong)
            #expect(!status.isCorrect, "\(topic.id) \(p.display): «\(wrong)» принят как \(status)")
            if case .unverifiable = status { Issue.record("\(topic.id): «\(wrong)» не проверен: \(status)") }
        }
    }

    @Test("Шаги решения проходят проверку тетради", arguments: Course.topics)
    func ownStepsPassNotebook(_ topic: TopicDef) {
        for seed in Self.seeds {
            let p = topic.example(seed: seed)
            #expect(!p.steps.isEmpty, "\(topic.id): нет шагов")
            let lines = p.steps.compactMap(\.line).filter { !$0.contains("?") }
            guard !lines.isEmpty, p.statement != nil else { continue }
            let statuses = p.checkNotebook(lines, mode: .steps)
            for (line, s) in zip(lines, statuses) {
                if case .wrong = s { Issue.record("\(topic.id) \(p.display): строка «\(line)» → \(s)") }
            }
            if let last = statuses.last, case .unverifiable = last {
                Issue.record("\(topic.id) \(p.display): последняя строка «\(lines.last!)» не проверена")
            }
        }
    }

    @Test("Ответы уровня 3 разбираются", arguments: Course.topics)
    func level3AnswersParse(_ topic: TopicDef) {
        for seed in Self.seeds.prefix(10) {
            let p = topic.example(seed: seed, easy: true)
            for step in p.steps {
                if let a = step.answer {
                    #expect((try? Parser.statement(a)) != nil, "\(topic.id): ответ «\(a)» на «\(step.ask ?? "")» не разбирается")
                }
            }
        }
    }

    @Test("Урок: два примера с шагами", arguments: Course.topics)
    func lessonHasTwoExamples(_ topic: TopicDef) {
        let lesson = topic.lesson()
        #expect(lesson.examples.count == 2)
        #expect(!lesson.rule.isEmpty)
        #expect(topic.lesson(seed: 2).examples[1].display != "" )
    }

    static func wrongAnswer(for p: Problem) -> String {
        switch p.spec.kind {
        case .roots: return "x = 1000"
        case .interval: return "(1000; +∞)"
        case .point: return "x = 1000; y = 1000"
        case .remainder: return "1000 ост. 0"
        case .primeFactorization: return "2 · 2 · 2 · 2 · 2 · 2 · 2 · 2 · 2 · 2 · 2"
        case .standardForm: return "9,9 · 10⁹"
        default:
            guard let e = Simplest.answerExpression(p.expected) else { return "1000" }
            return Expr.add(.group(e), .integer(1)).text
        }
    }
}

/// Типичные ошибки на конкретных темах: по 5 примеров верных и неверных решений.
@Suite("Ошибки по темам")
struct TopicMistakeTests {
    func kind(_ topicID: String, problem: String, answer: String, expected: String, spec: AnswerSpec) throws -> MistakeKind? {
        let s = AnswerChecker.check(answer, problem: try Parser.statement(problem), expected: try Parser.statement(expected), spec: spec)
        if case .wrong(let m) = s { return m?.kind }
        return nil
    }

    @Test func fractionsSameDenominator() throws {
        let spec = AnswerSpec(.number, requireMixed: true)
        #expect(try kind("g5.sameAdd", problem: "2/7 + 3/7", answer: "5/14", expected: "5/7", spec: spec) == .addedTopsAndBottoms)
        #expect(try kind("g5.sameAdd", problem: "4/9 + 2/9", answer: "6/18", expected: "2/3", spec: spec) == .addedTopsAndBottoms)
        #expect(AnswerChecker.check("6/9", problem: try Parser.statement("4/9 + 2/9"), expected: try Parser.statement("2/3"), spec: spec)
            == .correctNotSimplest(.reduce(by: 3)))
        #expect(AnswerChecker.check("2/3", problem: try Parser.statement("4/9 + 2/9"), expected: try Parser.statement("2/3"), spec: spec) == .correct)
        #expect(try kind("g5.sameSub", problem: "5/8 − 1/8", answer: "4/0", expected: "1/2", spec: spec) == nil)
    }

    @Test func fractionsDifferentDenominators() throws {
        let spec = AnswerSpec(.number, requireMixed: true)
        #expect(try kind("g6.addDiv", problem: "1/3 + 1/6", answer: "2/9", expected: "1/2", spec: spec) == .addedTopsAndBottoms)
        #expect(try kind("g6.addGen", problem: "1/4 + 1/6", answer: "2/10", expected: "5/12", spec: spec) == .addedTopsAndBottoms)
        let lines = LineChecker.check(problem: try Parser.statement("1/4 + 1/6"), lines: ["= 1/12 + 1/12"], spec: spec)
        guard case .wrong = lines[0] else { Issue.record("ожидалась ошибка"); return }
        let ok = LineChecker.check(problem: try Parser.statement("1/4 + 1/6"), lines: ["= 3/12 + 2/12", "= 5/12"], spec: spec)
        #expect(ok == [.correct, .correct])
        let improper = AnswerChecker.check("7/6", problem: try Parser.statement("2/3 + 1/2"), expected: try Parser.statement("1 1/6"), spec: spec)
        #expect(improper == .correctNotSimplest(.extractWhole))
    }

    @Test func wholePartAndImproper() throws {
        let spec = AnswerSpec(.number, requireMixed: true)
        #expect(try kind("g5.whole", problem: "17/5", answer: "2/5", expected: "3 2/5", spec: spec) == .forgotWholePart)
        #expect(try kind("g5.whole", problem: "11/4", answer: "3/4", expected: "2 3/4", spec: spec) == .forgotWholePart)
        #expect(AnswerChecker.check("3 2/5", problem: try Parser.statement("17/5"), expected: try Parser.statement("3 2/5"), spec: spec) == .correct)
        let imp = AnswerSpec(.improperFraction)
        #expect(AnswerChecker.check("2 1/3", problem: try Parser.statement("2 1/3"), expected: try Parser.statement("7/3"), spec: imp)
            == .correctNotSimplest(.writeAsImproper))
        #expect(AnswerChecker.check("7/3", problem: try Parser.statement("2 1/3"), expected: try Parser.statement("7/3"), spec: imp) == .correct)
    }

    @Test func divisionOfFractions() throws {
        let spec = AnswerSpec(.number, requireMixed: true)
        #expect(try kind("g6.div", problem: "2/3 : 4/5", answer: "8/15", expected: "5/6", spec: spec) == .divisionNotFlipped)
        #expect(try kind("g6.div", problem: "1/2 : 3/4", answer: "3/8", expected: "2/3", spec: spec) == .divisionNotFlipped)
        #expect(AnswerChecker.check("5/6", problem: try Parser.statement("2/3 : 4/5"), expected: try Parser.statement("5/6"), spec: spec) == .correct)
        #expect(AnswerChecker.check("10/12", problem: try Parser.statement("2/3 : 4/5"), expected: try Parser.statement("5/6"), spec: spec)
            == .correctNotSimplest(.reduce(by: 2)))
        #expect(try kind("g6.div", problem: "2/3 : 4/5", answer: "6/5", expected: "5/6", spec: spec) != nil)
    }

    @Test func negativeNumbersAndBrackets() throws {
        #expect(try kind("g6.negAdd", problem: "−7 + 3", answer: "4", expected: "−4", spec: AnswerSpec(.number)) == .signError)
        #expect(try kind("g6.negAdd", problem: "5 − (−3)", answer: "2", expected: "8", spec: AnswerSpec(.number)) == .signError)
        #expect(try kind("g6.brackets", problem: "7x − (2x + 3)", answer: "5x + 3", expected: "5x − 3", spec: AnswerSpec(.polynomial))
            == .minusBeforeBracket)
        #expect(try kind("g6.negMul", problem: "−6 · (−4)", answer: "−24", expected: "24", spec: AnswerSpec(.number)) == .signError)
        #expect(AnswerChecker.check("5x − 3", problem: try Parser.statement("7x − (2x + 3)"), expected: try Parser.statement("5x − 3"),
                                    spec: AnswerSpec(.polynomial)) == .correct)
    }

    @Test func algebra7() throws {
        #expect(try kind("g7.formulas", problem: "(x + 5)²", answer: "x² + 25", expected: "x² + 10x + 25", spec: AnswerSpec(.polynomial))
            == .squareMissingDoubleProduct)
        #expect(try kind("g7.powers", problem: "(a³)²", answer: "a⁵", expected: "a⁶", spec: AnswerSpec(.polynomial)) == .powersAdded)
        #expect(try kind("g7.powers", problem: "a³ · a²", answer: "a⁶", expected: "a⁵", spec: AnswerSpec(.polynomial)) == .powersMultiplied)
        let lines = LineChecker.check(problem: try Parser.statement("3(x + 2) = 2x + 9"), lines: ["3x + 6 = 2x + 9", "3x − 2x = 9 + 6"],
                                      spec: AnswerSpec(.roots))
        #expect(lines[0] == .correct)
        guard case .wrong(let m?) = lines[1] else { Issue.record("ожидалась ошибка переноса"); return }
        #expect(m.kind == .transferWithoutSignChange)
    }

    @Test func algebra8() throws {
        #expect(try kind("g8.ratReduce", problem: "{x + 3}/{x}", answer: "3", expected: "{x + 3}/{x}", spec: AnswerSpec(.rationalFraction))
            == .cancelledTerms)
        #expect(try kind("g8.ratEq", problem: "{x²}/{x − 2} = {5x − 6}/{x − 2}", answer: "x = 2 или x = 3", expected: "x = 3",
                         spec: AnswerSpec(.roots)) == .extraneousRoot)
        #expect(try kind("g8.vieta", problem: "x² − 7x + 10 = 0", answer: "x = −2 или x = −5", expected: "x = 2 или x = 5",
                         spec: AnswerSpec(.roots)) == .rootsSignSwapped)
        #expect(try kind("g8.ineq", problem: "−2x > 6", answer: "(−3; +∞)", expected: "(−∞; −3)", spec: AnswerSpec(.interval))
            == .inequalityNotFlipped)
        #expect(try kind("g8.ineq", problem: "x + 1 ≤ 4", answer: "(−∞; 3)", expected: "(−∞; 3]", spec: AnswerSpec(.interval))
            == .intervalBracket)
    }
}
