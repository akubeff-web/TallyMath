/// Какой ответ ждём — от этого зависит, что считать «простейшим видом».
public enum AnswerKind: String, Sendable, Codable, Hashable {
    /// Число: дробь сокращена, корень упрощён; целая часть — если requireMixed.
    case number
    /// Неправильная дробь (из смешанного числа).
    case improperFraction
    /// Десятичная дробь.
    case decimal
    /// Многочлен стандартного вида.
    case polynomial
    /// Разложение на множители.
    case factored
    /// Рациональная дробь (сокращённая).
    case rationalFraction
    /// Корни уравнения.
    case roots
    /// Промежуток.
    case interval
    /// Решение системы (x; y).
    case point
    /// Частное и остаток.
    case remainder
    /// Стандартный вид a · 10ⁿ.
    case standardForm
    /// Разложение на простые множители.
    case primeFactorization
}

public struct AnswerSpec: Sendable, Hashable, Codable {
    public var kind: AnswerKind
    public var requireMixed: Bool
    /// Для деления с остатком.
    public var divisor: Int?

    public init(_ kind: AnswerKind, requireMixed: Bool = false, divisor: Int? = nil) {
        self.kind = kind
        self.requireMixed = requireMixed
        self.divisor = divisor
    }
}

// MARK: - Простейший вид

enum Simplest {
    static func issue(_ s: Statement, spec: AnswerSpec) -> SimplestIssue? {
        switch spec.kind {
        case .interval:
            if case .relation = s { return .writeAsInterval }
            if case .system = s { return .writeAsInterval }
            return nil
        case .roots, .point, .remainder: return nil
        default: break
        }
        guard let e = answerExpression(s) else { return nil }
        switch spec.kind {
        case .number: return numberIssue(e, requireMixed: spec.requireMixed)
        case .improperFraction:
            if case .mixed = stripNeg(e) { return .writeAsImproper }
            return numberIssue(e, requireMixed: false)
        case .decimal:
            if let issue = numberIssue(e, requireMixed: false) { return issue }
            if case .fraction = stripNeg(e), (try? e.rationalValue())??.isTerminatingDecimal == true { return .writeAsDecimal }
            return nil
        case .polynomial: return polynomialIssue(e)
        case .factored: return factoredIssue(e)
        case .rationalFraction: return fractionIssue(e)
        case .standardForm: return standardFormIssue(e)
        case .primeFactorization:
            return e.unwrapped.factors.allSatisfy(isPrimePower) ? nil : .factorFurther
        default: return nil
        }
    }

    static func answerExpression(_ s: Statement) -> Expr? {
        switch s {
        case .expression(let e), .continuation(let e): return e
        case .relation(.variable, .eq, let e): return e
        case .chain(let es): return es.last
        default: return nil
        }
    }

    static func stripNeg(_ e: Expr) -> Expr {
        if case .neg(let i) = e.unwrapped { return i.unwrapped }
        return e.unwrapped
    }

    static func numberIssue(_ e: Expr, requireMixed: Bool) -> SimplestIssue? {
        let x = stripNeg(e)
        switch x {
        case .integer, .decimal:
            return nil
        case .mixed(_, let a, let b):
            if a >= b { return .extractWhole }
            let g = gcd(a, b)
            return g > 1 ? .reduce(by: g) : nil
        case .fraction(.integer(let a), .integer(let b), _):
            let g = gcd(a, b)
            if g > 1 { return b / g == 1 ? .finishComputation : .reduce(by: g) }
            if requireMixed && a > b && b != 1 { return .extractWhole }
            return nil
        default:
            break
        }
        // Число с корнями: корни упрощены и нет корня в знаменателе.
        guard (try? x.value()) != nil else { return .finishComputation }
        let sqrtNodes = x.allNodes.compactMap { n -> Expr? in if case .sqrt(let i) = n { return i } else { return nil } }
        if sqrtNodes.isEmpty { return .finishComputation }
        for inner in sqrtNodes {
            guard case .integer(let n) = inner.unwrapped else { return .simplifyRadical }
            if squareFree(n).outside > 1 { return .simplifyRadical }
        }
        // Остальные действия должны быть только «a + b√k», «b√k», «(a + b√k)/c».
        guard let value = try? x.value(), countTerms(x) <= value.terms.count else { return .finishComputation }
        return nil
    }

    static func countTerms(_ e: Expr) -> Int {
        if case .fraction(let a, _, _) = e.unwrapped { return a.unwrapped.terms.count }
        return e.unwrapped.terms.count
    }

    static func polynomialIssue(_ e: Expr) -> SimplestIssue? {
        guard let p = try? e.normalForm().polynomial else { return .finishComputation }
        let terms = e.unwrapped.terms
        if terms.count != max(p.terms.count, 1) { return .combineLikeTerms }
        for t in terms where !isMonomialTerm(t) { return .combineLikeTerms }
        return nil
    }

    /// Одночлен: число, переменные и их степени, без скобок с суммами внутри.
    static func isMonomialTerm(_ t: Expr) -> Bool {
        var seen: [String] = []
        for f in stripNeg(t).factors {
            switch f.unwrapped {
            case .integer, .decimal, .fraction(.integer, .integer, _): continue
            case .variable(let v):
                if seen.contains(v) { return false }
                seen.append(v)
            case .pow(.variable(let v), .integer):
                if seen.contains(v) { return false }
                seen.append(v)
            default: return false
            }
        }
        return true
    }

    static func factoredIssue(_ e: Expr) -> SimplestIssue? {
        let factors = stripNeg(e).factors.map { f -> Expr in
            if case .pow(let b, _) = f.unwrapped { return b.unwrapped }
            return f.unwrapped
        }
        let nonConstant = factors.filter(\.hasVariables)
        let isProduct = stripNeg(e).factors.count > 1 || {
            if case .pow(.group, _) = stripNeg(e) { return true } else { return false }
        }()
        guard isProduct, !nonConstant.isEmpty else { return .notFactored }
        for f in nonConstant where f.terms.count >= 2 {
            guard let p = try? f.normalForm().polynomial else { continue }
            // Общий числовой множитель.
            let coefs = p.terms.values
            if coefs.allSatisfy(\.isInteger) {
                let g = coefs.reduce(0) { gcd($0, $1.num) }
                if g > 1 { return .factorFurther }
            }
            // Общая переменная.
            for v in p.variables where p.terms.keys.allSatisfy({ ($0.powers[v] ?? 0) > 0 }) { return .factorFurther }
            // Квадратный трёхчлен с рациональными корнями раскладывается дальше.
            if p.variables.count == 1, let v = p.variables.first, let c = p.coefficients(in: v), c.count == 3,
               let roots = try? Solver.polyRoots(p, v), !roots.isEmpty, roots.allSatisfy({ $0.rational != nil }) {
                return .factorFurther
            }
            // Разность квадратов.
            if p.variables.count >= 1, p.terms.count == 2, isDifferenceOfSquares(p) { return .factorFurther }
        }
        return nil
    }

    static func isDifferenceOfSquares(_ p: Poly) -> Bool {
        let t = Array(p.terms)
        guard t.count == 2, t[0].value.sign != t[1].value.sign else { return false }
        return t.allSatisfy { m, c in
            m.radicand == 1 && m.powers.values.allSatisfy { $0 % 2 == 0 } &&
                squareFree(c.absolute.num).inside == 1 && squareFree(c.den).inside == 1
        }
    }

    static func fractionIssue(_ e: Expr) -> SimplestIssue? {
        guard let nf = try? e.normalForm() else { return nil }
        let x = stripNeg(e)
        guard case .fraction(let top, let bottom, _) = x,
              let tn = try? top.normalForm().polynomial, let bn = try? bottom.normalForm().polynomial else {
            return nf.isPolynomial ? polynomialIssue(e) : nil
        }
        // Если после сокращения степень знаменателя меньше — значит, можно было сократить.
        if nf.den.degree < bn.degree || (nf.isPolynomial && bn.degree > 0) { return .reduce(by: nil) }
        let coefs = Array(tn.terms.values) + Array(bn.terms.values)
        if coefs.allSatisfy(\.isInteger) {
            let g = coefs.reduce(0) { gcd($0, $1.num) }
            if g > 1 { return .reduce(by: g) }
        }
        return nil
    }

    static func standardFormIssue(_ e: Expr) -> SimplestIssue? {
        let x = stripNeg(e)
        guard case .mul(let a, let p) = x, case .pow(.integer(10), _) = p.unwrapped,
              let av = try? a.rationalValue() else {
            if case .pow(.integer(10), _) = x { return nil }
            return .standardForm
        }
        return (av.absolute >= .one && av.absolute < Rational(10)) ? nil : .standardForm
    }

    static func isPrimePower(_ e: Expr) -> Bool {
        switch e.unwrapped {
        case .integer(let n): return isPrime(n)
        case .pow(.integer(let n), .integer): return isPrime(n)
        default: return false
        }
    }
}

// MARK: - Проверка ответа

public enum AnswerChecker {
    /// Проверяет ответ на задание. problem — условие, expected — правильный ответ.
    public static func check(_ input: String, problem: Statement, expected: Statement, spec: AnswerSpec) -> LineStatus {
        guard let answer = try? Parser.statement(input) else {
            return .unverifiable("не понял запись ответа")
        }
        return check(answer, problem: problem, expected: expected, spec: spec)
    }

    public static func check(_ answer: Statement, problem: Statement, expected: Statement, spec: AnswerSpec) -> LineStatus {
        switch spec.kind {
        case .roots, .interval, .point:
            return checkSet(answer, problem: problem, expected: expected, spec: spec)
        case .remainder:
            return checkRemainder(answer, expected: expected, spec: spec)
        default:
            break
        }
        guard let e = Simplest.answerExpression(answer), let target = Simplest.answerExpression(expected) else {
            return .unverifiable("ожидалось одно число или выражение")
        }
        switch equivalent(e, target) {
        case true?:
            if let issue = Simplest.issue(answer, spec: spec) { return .correctNotSimplest(issue) }
            return .correct
        case false?:
            return .wrong(detectAnswerMistake(e, target: target, problem: problem))
        case nil:
            return .unverifiable("не получилось сравнить с ответом")
        }
    }

    static func detectAnswerMistake(_ e: Expr, target: Expr, problem: Statement) -> MistakeReport? {
        let problemExpr = Simplest.answerExpression(problem) ?? {
            if case .chain(let es) = problem { return es.first }
            return nil
        }()
        if let p = problemExpr, let m = LineChecker.mutationMatch(from: p, to: e) { return m }
        if let v = try? target.rationalValue(), let u = try? e.rationalValue() {
            return ValueMistakes.detect(correct: v, answer: u, problem: problemExpr)
        }
        return nil
    }

    static func checkRemainder(_ answer: Statement, expected: Statement, spec: AnswerSpec) -> LineStatus {
        guard case .remainder(let q, let r) = answer, case .remainder(let eq, let er) = expected,
              let qv = try? q.rationalValue(), let rv = try? r.rationalValue(),
              let eqv = try? eq.rationalValue(), let erv = try? er.rationalValue() else {
            return .unverifiable("ожидается запись «частное ост. остаток»")
        }
        if qv == eqv && rv == erv { return .correct }
        if let d = spec.divisor, rv >= Rational(d) {
            return .wrong(MistakeReport(.remainderTooBig, detail: "Остаток \(rv) не меньше делителя \(d)."))
        }
        return .wrong(MistakeReport(.arithmetic))
    }

    static func checkSet(_ answer: Statement, problem: Statement, expected: Statement, spec: AnswerSpec) -> LineStatus {
        guard let target = try? Solver.solve(expected) else { return .unverifiable("не получилось решить задание") }
        var given = answer
        // «(2; 1)» как ответ системы — это точка.
        if spec.kind == .point, case .intervals(let list) = answer, list.count == 1,
           let lo = list[0].low, let hi = list[0].high, case .point(let p) = target {
            let vars = p.keys.sorted()
            guard vars.count == 2 else { return .unverifiable("ожидалась пара чисел") }
            given = .system([.relation(.variable(vars[0]), .eq, lo), .relation(.variable(vars[1]), .eq, hi)])
        }
        guard let got = try? Solver.solve(given) else { return .unverifiable("не понял ответ") }
        if got == target {
            if let issue = Simplest.issue(answer, spec: spec) { return .correctNotSimplest(issue) }
            return .correct
        }
        return .wrong(LineChecker.setMistake(got: got, target: target, problem: problem))
    }
}
