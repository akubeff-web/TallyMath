import Testing
@testable import MathCore

@Suite("Прогресс и повторение")
struct ProgressTests {
    @Test func masteredTopicGoesToReview() {
        var store = ProgressStore()
        let results = Array(repeating: (topicID: "g6.addGen", correct: true), count: 10)
        for _ in results { store.record(topicID: "g6.addGen", status: .correct, day: 100) }
        store.finishSession(results, day: 100, seconds: 300, isReview: false)
        #expect(store.progress("g6.addGen").review?.dueDay == 101)
        #expect(store.dueReviews(day: 100).isEmpty)
        #expect(store.dueReviews(day: 101) == ["g6.addGen"])
    }

    @Test func reviewIntervalsGrowAndReset() {
        var store = ProgressStore()
        store.finishSession(Array(repeating: ("g5.whole", true), count: 10), day: 0, seconds: 1, isReview: false)
        var day = 1
        for expected in [3, 7, 14, 30] {
            store.finishSession(Array(repeating: ("g5.whole", true), count: 5), day: day, seconds: 1, isReview: true)
            let r = store.progress("g5.whole").review!
            #expect(r.dueDay - day == expected)
            day = r.dueDay
        }
        // Две ошибки — интервал снова короткий.
        store.finishSession([("g5.whole", false), ("g5.whole", false), ("g5.whole", true), ("g5.whole", true), ("g5.whole", true)],
                            day: day, seconds: 1, isReview: true)
        #expect(store.progress("g5.whole").review!.dueDay == day + 1)
    }

    @Test func weakTopicsAndNotUnderstood() {
        var store = ProgressStore()
        for i in 0..<6 { store.record(topicID: "g6.addGen", status: i < 2 ? .correct : .wrong(MistakeReport(.addedTopsAndBottoms)), day: 10) }
        for _ in 0..<6 { store.record(topicID: "g5.sameAdd", status: .correct, day: 10) }
        #expect(store.isWeak("g6.addGen", day: 10))
        #expect(!store.isWeak("g5.sameAdd", day: 10))
        #expect(store.weight("g6.addGen", day: 10) > store.weight("g5.sameAdd", day: 10))
        #expect(store.topMistakes("g6.addGen").first?.0 == .addedTopsAndBottoms)
        store.recordNotUnderstood(topicID: "g5.sameAdd", day: 11)
        store.recordNotUnderstood(topicID: "g5.sameAdd", day: 12)
        #expect(store.isWeak("g5.sameAdd", day: 12))
    }

    @Test func streakAndTotals() {
        var store = ProgressStore()
        store.record(topicID: "g5.table", status: .correct, day: 1)
        store.record(topicID: "g5.table", status: .correctNotSimplest(.reduce(by: 2)), day: 1)
        store.record(topicID: "g5.table", status: .wrong(nil), day: 1)
        #expect(store.streak == 0 && store.bestStreak == 2 && store.totalSolved == 3)
        #expect(store.accuracyPercent == 66)
    }

    @Test func plannerAvoidsImmediateRepeatsAndPrefersWeak() {
        var store = ProgressStore()
        for _ in 0..<10 { store.record(topicID: "g6.addGen", status: .wrong(nil), day: 1) }
        var rng = RandomSource(seed: 42)
        let plan = SessionPlanner.plan(topicIDs: ["g6.addGen", "g5.sameAdd"], count: 40, progress: store, day: 1, rng: &rng)
        #expect(plan.count == 40)
        for (a, b) in zip(plan, plan.dropFirst()) { #expect(a.id != b.id) }
        let weakCount = plan.filter { $0.topicID == "g6.addGen" }.count
        #expect(weakCount > 20)
    }

    @Test func codableRoundTrip() throws {
        var store = ProgressStore()
        store.record(topicID: "g5.table", status: .wrong(MistakeReport(.neighbourTableFact)), day: 3)
        store.finishSession([("g5.table", false)], day: 3, seconds: 20, isReview: false)
        #expect(store == store)
    }
}

@Suite("Редактор записи")
struct EditorTests {
    @Test func fractionTemplate() throws {
        var e = MathEditor()
        e.insertFraction()
        e.insert("1")
        e.moveNext()
        e.insert("3")
        e.moveNext()
        e.insert("+")
        e.insertFraction(); e.insert("1"); e.moveNext(); e.insert("6"); e.moveNext()
        #expect(e.text == "{1}/{3}+{1}/{6}")
        #expect(try Parser.expression(e.text).rationalValue() == .of(1, 2))
    }

    @Test func mixedNumberAndAnnotation() throws {
        var e = MathEditor()
        e.insert("2")
        e.insertFraction(); e.insert("1"); e.moveNext(); e.insert("3"); e.moveNext()
        #expect(try Parser.expression(e.text) == .mixed(2, 1, 3))
        var f = MathEditor()
        f.insertFraction(); f.insert("1"); f.moveNext(); f.insert("3"); f.moveNext()
        f.annotateFraction(); f.insert("2")
        #expect(f.text == "{1}/{3}[×2]")
        #expect(try Parser.expression(f.text) == .fraction(.integer(1), .integer(3), annotation: 2))
    }

    @Test func powerRootAbsSystem() throws {
        var e = MathEditor()
        e.insert("x"); e.insertPower(); e.insert("2"); e.moveNext(); e.insert("−"); e.insert("4")
        #expect(try Parser.expression(e.text).normalForm().equals(Parser.expression("x² − 4").normalForm()))
        var r = MathEditor()
        r.insertSqrt(); r.insert("1"); r.insert("2")
        #expect(try Parser.expression(r.text).normalForm().equals(Parser.expression("2√3").normalForm()))
        var a = MathEditor()
        a.insertAbs(); a.insert("−"); a.insert("5")
        #expect(try Parser.expression(a.text).rationalValue() == .of(5))
        var s = MathEditor()
        s.insertSystem()
        for c in "x+y=3" { s.insert(String(c)) }
        s.moveNext()
        for c in "x−y=1" { s.insert(String(c)) }
        #expect(try Solver.solve(Parser.statement(s.text)) == .point(["x": .of(2), "y": .of(1)]))
    }

    @Test func backspaceRemovesEmptyTemplate() {
        var e = MathEditor()
        e.insert("5")
        e.insertFraction()
        e.backspace()
        #expect(e.text == "5")
        e.backspace()
        #expect(e.isEmpty)
        e.backspace()
        #expect(e.isEmpty)
    }

    @Test func navigationThroughFraction() {
        var e = MathEditor(text: "1+")
        e.insertFraction(); e.insert("2"); e.moveNext(); e.insert("5"); e.moveNext()
        e.movePrev()
        e.insert("0")
        #expect(e.text == "1+{2}/{50}")
    }
}

@Suite("Разметка записи")
struct LayoutTests {
    @Test func fractionsPowersRoots() {
        #expect(MathLayout.layout("1/3 + 1/6") == [.fraction([.text("1")], [.text("3")], annotation: nil), .text(" + "),
                                                   .fraction([.text("1")], [.text("6")], annotation: nil)])
        #expect(MathLayout.layout("{x + 1}/{x − 1}") ==
            [.fraction([.text("x + 1")], [.text("x − 1")], annotation: nil)])
        #expect(MathLayout.layout("x^(2)") == [.text("x"), .sup([.text("2")])])
        #expect(MathLayout.layout("√(12)") == [.sqrt([.text("12")])])
        #expect(MathLayout.layout("1/3[×2]") == [.fraction([.text("1")], [.text("3")], annotation: "×2")])
        #expect(MathLayout.layout("2 1/3") == [.text("2 "), .fraction([.text("1")], [.text("3")], annotation: nil)])
        #expect(MathLayout.layout("0,25 + 12") == [.text("0,25 + 12")])
    }
}

@Suite("Свой пример")
struct CustomProblemTests {
    func make(_ t: String) -> Problem? { try? CustomProblem.make(t).get() }

    @Test func recognisesTopicsAndAnswers() throws {
        let p = try #require(make("3/4 − 2/3 = ?"))
        #expect(p.topicID == "g6.sub")
        #expect(p.check("1/12") == .correct)
        let q = try #require(make("x² − 5x + 6 = 0"))
        #expect(q.topicID == "g8.quadratic")
        #expect(q.check("x = 3 или x = 2") == .correct)
        let r = try #require(make("2x + y = 5; x − y = 1"))
        #expect(r.check("(2; 1)") == .correct)
        let s = try #require(make("−3x ≤ 6"))
        #expect(s.check("[−2; +∞)") == .correct)
        let t = try #require(make("√12 + √27"))
        #expect(t.check("5√3") == .correct)
        let u = try #require(make("(a + b)²"))
        #expect(u.check("a² + 2ab + b²") == .correct)
        let v = try #require(make("7 × 8"))
        #expect(v.topicID == "g5.table")
        let w = try #require(make("1/3 + 1/6"))
        #expect(w.topicID == "g6.addDiv")
        let wl = w.checkNotebook(w.steps.compactMap { $0.line }, mode: .steps)
        #expect(wl.allSatisfy { $0.isCorrect })
    }

    @Test func explainsWhatIsUnsupported() {
        #expect(CustomProblem.make("((2 +") == .failure(.cannotRead))
        guard case .failure(.unsupported) = CustomProblem.make("x + y = 3") else { Issue.record("ожидался отказ"); return }
        guard case .failure(.unsupported) = CustomProblem.make("x³ + x + 1 = 0") else { Issue.record("ожидался отказ"); return }
        guard case .failure(.unsupported) = CustomProblem.make("1/0") else { Issue.record("ожидался отказ"); return }
    }

    @Test func factStats() {
        var store = ProgressStore()
        store.recordFact(8, 7, correct: false)
        store.recordFact(7, 8, correct: true)
        #expect(store.factErrorRate(7, 8) == .of(1, 2))
        #expect(store.factErrorRate(2, 2) == nil)
    }
}

@Suite("Ответы на вопросы шагов")
struct StepAnswerTests {
    @Test func variants() {
        #expect(StepAnswer.check("12", expected: "12") == .correct)
        #expect(StepAnswer.check(" 2·2·3", expected: "2 · 2 · 3") == .correct)
        #expect(StepAnswer.check("x=3", expected: "x = 3") == .correct)
        #expect(StepAnswer.check("6/12", expected: "1/2") == .correctNotSimplest(.reduce(by: 6)))
        #expect(StepAnswer.check("13", expected: "12") == .wrong(nil))
        #expect(StepAnswer.check("x = 2 или x = 3", expected: "x = 3 или x = 2") == .correct)
        #expect(StepAnswer.check("(x−3)(x+3)", expected: "(x − 3)(x + 3)") == .correct)
    }
}

@Suite("Разнообразие примеров")
struct VarietyTests {
    @Test func sessionHasNoRepeats() {
        var rng = RandomSource(seed: 99)
        for columns in [[2], [2, 5], [7]] {
            let ctx = TopicContext(columns: columns)
            let plan = SessionPlanner.plan(topicIDs: ["g5.table"], count: 10, progress: ProgressStore(), day: 0, context: ctx, rng: &rng)
            #expect(Set(plan.map { $0.id }).count == 10, "столбики \(columns): повторы")
        }
        for id in Course.topics.map(\.id) {
            let plan = SessionPlanner.plan(topicIDs: [id], count: 10, progress: ProgressStore(), day: 0, rng: &rng)
            #expect(Set(plan.map { $0.id }).count >= 9, "\(id): слишком много повторов")
        }
    }

    @Test func introducedTopics() {
        var s = ProgressStore()
        #expect(!s.isIntroduced("g6.reduce"))
        s.markIntroduced("g6.reduce")
        #expect(s.isIntroduced("g6.reduce"))
        s.record(topicID: "g5.table", status: .correct, day: 1)
        #expect(s.isIntroduced("g5.table"))
    }
}
