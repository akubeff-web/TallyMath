import Testing
@testable import MathCore

@Suite("Точные дроби")
struct RationalTests {
    @Test func reducesAndKeepsSign() throws {
        let r = try Rational(6, -8)
        #expect(r.num == -3 && r.den == 4)
    }

    @Test func arithmetic() throws {
        let a = Rational.of(1, 3), b = Rational.of(1, 6)
        #expect(try a.adding(b) == .of(1, 2))
        #expect(try a.subtracting(b) == .of(1, 6))
        #expect(try a.multiplying(b) == .of(1, 18))
        #expect(try a.dividing(b) == .of(2))
    }

    @Test func divisionByZeroThrows() {
        #expect(throws: MathError.divisionByZero) { try Rational(1, 0) }
    }

    @Test func overflowThrows() {
        let big = Rational(Int.max / 2)
        #expect(throws: MathError.overflow) { try big.multiplying(Rational(4)) }
    }

    @Test func mixedAndDecimal() {
        #expect(Rational.of(7, 3).mixedParts == (2, 1, 3))
        #expect(Rational.of(1, 4).decimalString == "0,25")
        #expect(Rational.of(-3, 2).decimalString == "-1,5")
        #expect(Rational.of(1, 3).decimalString == nil)
        #expect(Rational.of(-7, 2).floor == -4)
    }

    @Test func squareFreeParts() {
        #expect(squareFree(12) == (2, 3))
        #expect(squareFree(50) == (5, 2))
        #expect(primeFactors(360) == [2, 2, 2, 3, 3, 5])
    }
}

@Suite("Разбор записи")
struct ParserTests {
    @Test func fractionsAndMixed() throws {
        #expect(try Parser.expression("1/3 + 1/6") == .add(.frac(1, 3), .frac(1, 6)))
        #expect(try Parser.expression("2 1/3") == .mixed(2, 1, 3))
        #expect(try Parser.expression("2{1}/{3}") == .mixed(2, 1, 3))
        #expect(try Parser.expression("{x+1}/{x−1}") ==
            .fraction(.add(.variable("x"), .integer(1)), .sub(.variable("x"), .integer(1)), annotation: nil))
        #expect(try Parser.expression("1/3[×2]") == .fraction(.integer(1), .integer(3), annotation: 2))
    }

    @Test func implicitMultiplicationAndPowers() throws {
        let e = try Parser.expression("2x² − 5x + 6")
        #expect(try e.normalForm().equals(Parser.expression("2·x^2 - 5*x + 6").normalForm()))
        #expect(try Parser.expression("3(x+1)").normalForm().equals(Parser.expression("3x + 3").normalForm()))
        #expect(try Parser.expression("10⁻³").rationalValue() == .of(1, 1000))
    }

    @Test func statements() throws {
        guard case .relation(_, .eq, _) = try Parser.statement("2x + 1 = 7") else { Issue.record("уравнение"); return }
        guard case .chain(let parts) = try Parser.statement("1/3 + 1/6 = 2/6 + 1/6 = 1/2") else {
            Issue.record("цепочка"); return
        }
        #expect(parts.count == 3)
        guard case .either(let roots) = try Parser.statement("x₁ = 2 или x₂ = 3") else { Issue.record("или"); return }
        #expect(roots.count == 2)
        #expect(try Parser.statement("нет решений") == .noSolution)
        #expect(try Parser.statement("любое число") == .anyNumber)
        guard case .intervals(let ivs) = try Parser.statement("x ∈ (−∞; 2] ∪ (5; +∞)") else {
            Issue.record("промежутки"); return
        }
        #expect(ivs.count == 2 && ivs[0].low == nil && ivs[0].highClosed && ivs[1].high == nil)
        guard case .system(let sys) = try Parser.statement("2x + y = 5; x − y = 1") else { Issue.record("система"); return }
        #expect(sys.count == 2)
        guard case .remainder = try Parser.statement("7 ост. 2") else { Issue.record("остаток"); return }
        guard case .continuation = try Parser.statement("= 2/6 + 1/6") else { Issue.record("продолжение"); return }
    }

    @Test func decimalsPercentAbs() throws {
        #expect(try Parser.expression("0,25 + 0.5").rationalValue() == .of(3, 4))
        #expect(try Parser.expression("15% · 200").rationalValue() == .of(30))
        #expect(try Parser.expression("|−3| + |2 − 7|").rationalValue() == .of(8))
    }

    @Test func roundTripPrinting() throws {
        for text in ["1/3 + 1/6", "2x² − 5x + 6", "{x + 1}/{x − 1}", "√12", "3(x + 1)", "−2 1/3"] {
            let e = try Parser.expression(text)
            #expect(try Parser.expression(e.text) == e, "\(text) → \(e.text)")
        }
    }

    @Test func syntaxErrors() {
        #expect(throws: MathError.self) { try Parser.expression("2 + ") }
        #expect(throws: MathError.self) { try Parser.expression("(1 + 2") }
    }
}

@Suite("Нормальная форма")
struct NormalFormTests {
    func eq(_ a: String, _ b: String) throws -> Bool? {
        equivalent(try Parser.expression(a), try Parser.expression(b))
    }

    @Test func numbers() throws {
        #expect(try eq("1/3 + 1/6", "1/2") == true)
        #expect(try eq("1/3 + 1/6", "2/9") == false)
        #expect(try eq("2 1/3", "7/3") == true)
        #expect(try eq("0,5", "1/2") == true)
    }

    @Test func radicals() throws {
        #expect(try eq("√12", "2√3") == true)
        #expect(try eq("√2 · √8", "4") == true)
        #expect(try eq("1/√2", "√2/2") == true)
        #expect(try eq("√12 + √27", "5√3") == true)
        #expect(try eq("(√3 − 1)(√3 + 1)", "2") == true)
    }

    @Test func polynomials() throws {
        #expect(try eq("(a + b)²", "a² + 2ab + b²") == true)
        #expect(try eq("(a + b)²", "a² + b²") == false)
        #expect(try eq("(x − 3)(x + 3)", "x² − 9") == true)
        #expect(try eq("x²·x³", "x^5") == true)
    }

    @Test func rationalExpressions() throws {
        #expect(try eq("{x² − 1}/{x − 1}", "x + 1") == true)
        #expect(try eq("{1}/{x} + {1}/{x + 1}", "{2x + 1}/{x² + x}") == true)
        #expect(try eq("{x + 3}/{x}", "3") == false)
    }

    @Test func absWithVariableUsesSubstitution() throws {
        #expect(try eq("|x|·|x|", "x²") == true)
        #expect(try eq("|x|", "x") == false)
    }

    @Test func undefinedValues() throws {
        #expect(throws: MathError.self) { try Parser.expression("√(−4)").normalForm() }
        #expect(throws: MathError.divisionByZero) { try Parser.expression("1/(2 − 2)").normalForm() }
    }
}
