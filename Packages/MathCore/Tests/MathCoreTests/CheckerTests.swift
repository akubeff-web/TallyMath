import Testing
@testable import MathCore

@Suite("Проверка ответа")
struct AnswerCheckerTests {
    func check(_ answer: String, _ problem: String, _ expected: String, _ spec: AnswerSpec) throws -> LineStatus {
        AnswerChecker.check(answer, problem: try Parser.statement(problem), expected: try Parser.statement(expected), spec: spec)
    }

    @Test func fractionAnswers() throws {
        let spec = AnswerSpec(.number, requireMixed: true)
        #expect(try check("1/2", "1/3 + 1/6", "1/2", spec) == .correct)
        #expect(try check("3/6", "1/3 + 1/6", "1/2", spec) == .correctNotSimplest(.reduce(by: 3)))
        #expect(try check("2/9", "1/3 + 1/6", "1/2", spec) ==
            .wrong(MistakeReport(.addedTopsAndBottoms, detail: "Низ не складываем: 3 + 6 — так нельзя.")))
        #expect(try check("5/3", "2/3 + 1", "1 2/3", spec) == .correctNotSimplest(.extractWhole))
        #expect(try check("1 2/3", "2/3 + 1", "1 2/3", spec) == .correct)
    }

    @Test func forgotWholePart() throws {
        let s = try check("2/3", "5/3", "1 2/3", AnswerSpec(.number, requireMixed: true))
        guard case .wrong(let m?) = s else { Issue.record("ожидалась ошибка"); return }
        #expect(m.kind == .forgotWholePart)
    }

    @Test func tableNeighbour() throws {
        let s = try check("48", "7 × 8", "56", AnswerSpec(.number))
        guard case .wrong(let m?) = s else { Issue.record("ожидалась ошибка"); return }
        #expect(m.kind == .neighbourTableFact)
        #expect(try check("56", "7 × 8", "56", AnswerSpec(.number)) == .correct)
    }

    @Test func decimals() throws {
        let s = try check("0,12", "0,3 · 4", "1,2", AnswerSpec(.decimal))
        guard case .wrong(let m?) = s else { Issue.record("ожидалась ошибка"); return }
        #expect(m.kind == .decimalPoint)
        #expect(try check("6/5", "0,3 · 4", "1,2", AnswerSpec(.decimal)) == .correctNotSimplest(.writeAsDecimal))
    }

    @Test func roots() throws {
        let spec = AnswerSpec(.roots)
        #expect(try check("x₁ = 3 или x₂ = 2", "x² − 5x + 6 = 0", "x = 2 или x = 3", spec) == .correct)
        #expect(try check("x = (5 ± 1)/2", "x² − 5x + 6 = 0", "x = 2 или x = 3", spec) == .correct)
        guard case .wrong(let m?) = try check("x = −2 или x = −3", "x² − 5x + 6 = 0", "x = 2 или x = 3", spec) else {
            Issue.record("ожидалась ошибка"); return
        }
        #expect(m.kind == .rootsSignSwapped)
        guard case .wrong(let m2?) = try check("x = 1 или x = 2", "{x² − 3x + 2}/{x − 1} = 0", "x = 2", spec) else {
            Issue.record("ожидалась ошибка"); return
        }
        #expect(m2.kind == .extraneousRoot)
    }

    @Test func intervals() throws {
        let spec = AnswerSpec(.interval)
        #expect(try check("[−2; +∞)", "−3x ≤ 6", "x ≥ −2", spec) == .correct)
        #expect(try check("x ≥ −2", "−3x ≤ 6", "x ≥ −2", spec) == .correctNotSimplest(.writeAsInterval))
        guard case .wrong(let m?) = try check("(−2; +∞)", "−3x ≤ 6", "x ≥ −2", spec) else { Issue.record(""); return }
        #expect(m.kind == .intervalBracket)
        guard case .wrong(let m2?) = try check("(−∞; −2]", "−3x ≤ 6", "x ≥ −2", spec) else { Issue.record(""); return }
        #expect(m2.kind == .inequalityNotFlipped)
    }

    @Test func systemsAndRemainder() throws {
        #expect(try check("(2; 1)", "2x + y = 5; x − y = 1", "x = 2; y = 1", AnswerSpec(.point)) == .correct)
        #expect(try check("x = 2; y = 1", "2x + y = 5; x − y = 1", "x = 2; y = 1", AnswerSpec(.point)) == .correct)
        #expect(try check("7 ост. 2", "37 : 5", "7 ост. 2", AnswerSpec(.remainder, divisor: 5)) == .correct)
        guard case .wrong(let m?) = try check("6 ост. 7", "37 : 5", "7 ост. 2", AnswerSpec(.remainder, divisor: 5)) else {
            Issue.record(""); return
        }
        #expect(m.kind == .remainderTooBig)
    }

    @Test func algebraForms() throws {
        #expect(try check("a² + 2ab + b²", "(a + b)²", "a² + 2ab + b²", AnswerSpec(.polynomial)) == .correct)
        guard case .wrong(let m?) = try check("a² + b²", "(a + b)²", "a² + 2ab + b²", AnswerSpec(.polynomial)) else {
            Issue.record(""); return
        }
        #expect(m.kind == .squareMissingDoubleProduct)
        #expect(try check("x(x − 4) + 2x", "x² − 2x", "x² − 2x", AnswerSpec(.polynomial)) == .correctNotSimplest(.combineLikeTerms))
        #expect(try check("(x − 3)(x + 3)", "x² − 9", "(x − 3)(x + 3)", AnswerSpec(.factored)) == .correct)
        #expect(try check("x² − 9", "x² − 9", "(x − 3)(x + 3)", AnswerSpec(.factored)) == .correctNotSimplest(.notFactored))
        #expect(try check("2(x² − 4)", "2x² − 8", "2(x − 2)(x + 2)", AnswerSpec(.factored)) == .correctNotSimplest(.factorFurther))
        #expect(try check("3,2 · 10⁴", "32000", "3,2 · 10⁴", AnswerSpec(.standardForm)) == .correct)
        #expect(try check("32 · 10³", "32000", "3,2 · 10⁴", AnswerSpec(.standardForm)) == .correctNotSimplest(.standardForm))
        #expect(try check("2√3", "√12", "2√3", AnswerSpec(.number)) == .correct)
        #expect(try check("√12", "√12", "2√3", AnswerSpec(.number)) == .correctNotSimplest(.simplifyRadical))
    }

    @Test func unparseableIsNotAVerdict() throws {
        #expect(try check("по Виета 2 и 3", "x² − 5x + 6 = 0", "x = 2 или x = 3", AnswerSpec(.roots)) ==
            .unverifiable("не понял запись ответа"))
    }
}

@Suite("Проверка тетради")
struct LineCheckerTests {
    func check(_ problem: String, _ lines: [String], _ spec: AnswerSpec = AnswerSpec(.number, requireMixed: true),
               mode: LineChecker.Mode = .steps) throws -> [LineStatus] {
        LineChecker.check(problem: try Parser.statement(problem), lines: lines, spec: spec, mode: mode)
    }

    @Test func fractionChain() throws {
        let s = try check("1/3 + 1/6", ["= 2/6 + 1/6", "= 3/6", "= 1/2"])
        #expect(s == [.correct, .correct, .correct])
        let notReduced = try check("1/3 + 1/6", ["= 2/6 + 1/6", "= 3/6"])
        #expect(notReduced.last == .correctNotSimplest(.reduce(by: 3)))
    }

    @Test func onlyTopMultiplied() throws {
        let s = try check("1/3 + 1/6", ["= 2/3 + 1/6"])
        guard case .wrong(let m?) = s[0] else { Issue.record("ожидалась ошибка"); return }
        #expect(m.kind == .multipliedOnlyTop)
    }

    @Test func wrongCommonDenominator() throws {
        let s = try check("1/4 + 1/6", ["= 2/8 + 1/8"])
        guard case .wrong(let m?) = s[0] else { Issue.record("ожидалась ошибка"); return }
        #expect(m.kind == .wrongCommonDenominator)
    }

    @Test func quickModeChecksOnlyAgainstStart() throws {
        let s = try check("1/3 + 1/6", ["= 1/2"], mode: .quick)
        #expect(s == [.correct])
    }

    @Test func minusBracket() throws {
        let s = try check("5x − (2x + 3)", ["= 5x − 2x + 3"], AnswerSpec(.polynomial))
        guard case .wrong(let m?) = s[0] else { Issue.record("ожидалась ошибка"); return }
        #expect(m.kind == .minusBeforeBracket)
    }

    @Test func linearEquationSteps() throws {
        let s = try check("2x + 5 = 17", ["2x = 12", "x = 6"], AnswerSpec(.roots))
        #expect(s == [.correct, .correct])
        let bad = try check("2x + 5 = 17", ["2x = 22"], AnswerSpec(.roots))
        guard case .wrong(let m?) = bad[0] else { Issue.record("ожидалась ошибка"); return }
        #expect(m.kind == .transferWithoutSignChange)
    }

    @Test func quadraticWithDiscriminantAndUnverifiableText() throws {
        let s = try check("x² − 5x + 6 = 0", ["D = 25 − 24 = 1", "по Виета подбираю 2 и 3", "x₁ = 2 или x₂ = 3"],
                          AnswerSpec(.roots))
        #expect(s[0] == .correct)
        guard case .unverifiable = s[1] else { Issue.record("ожидалось «не удалось проверить»"); return }
        #expect(s[2] == .correct)
        let badD = try check("x² − 5x + 6 = 0", ["D = 25 + 24 = 49"], AnswerSpec(.roots))
        guard case .wrong = badD[0] else { Issue.record("ожидалась ошибка в D"); return }
    }

    @Test func inequalityFlip() throws {
        let s = try check("−3x ≤ 6", ["x ≤ −2"], AnswerSpec(.interval))
        guard case .wrong(let m?) = s[0] else { Issue.record("ожидалась ошибка"); return }
        #expect(m.kind == .inequalityNotFlipped)
        #expect(try check("−3x ≤ 6", ["x ≥ −2", "[−2; +∞)"], AnswerSpec(.interval)) == [.correct, .correct])
    }

    @Test func systemSubstitution() throws {
        let s = try check("2x + y = 5; x − y = 1", ["y = 5 − 2x", "x − (5 − 2x) = 1", "3x = 6", "x = 2; y = 1"],
                          AnswerSpec(.point))
        #expect(s.allSatisfy { $0 == .correct }, "\(s)")
    }

    @Test func rationalEquationMultiplyStepIsAccepted() throws {
        let s = try check("{x}/{x − 1} = {1}/{x − 1}", ["x = 1", "нет решений"], AnswerSpec(.roots))
        #expect(s == [.correct, .correct])
    }
}
