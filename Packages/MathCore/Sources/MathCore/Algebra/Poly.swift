/// Одночлен: произведение степеней переменных и корня √radicand (radicand свободен от квадратов).
/// Корни √2, √3, √6 … линейно независимы над рациональными числами, поэтому запись однозначна.
public struct Monomial: Hashable, Sendable, Comparable {
    public var powers: [String: Int]
    public var radicand: Int

    public init(_ powers: [String: Int] = [:], radicand: Int = 1) {
        self.powers = powers.filter { $0.value != 0 }
        self.radicand = radicand
    }

    public static let one = Monomial()

    public var degree: Int { powers.values.reduce(0, +) }
    public var isConstant: Bool { powers.isEmpty }

    /// Ключ для устойчивого порядка: по убыванию степени, потом по алфавиту.
    var sortKey: String {
        powers.keys.sorted().map { "\($0)\(powers[$0]!)" }.joined() + "r\(radicand)"
    }

    public static func < (a: Monomial, b: Monomial) -> Bool {
        if a.degree != b.degree { return a.degree > b.degree }
        return a.sortKey < b.sortKey
    }
}

/// Многочлен с точными коэффициентами. Пустой словарь — ноль.
public struct Poly: Hashable, Sendable {
    public var terms: [Monomial: Rational]

    public init(_ terms: [Monomial: Rational] = [:]) {
        self.terms = terms.filter { !$0.value.isZero }
    }

    public init(constant r: Rational) { self.init([.one: r]) }

    public static func variable(_ name: String) -> Poly { Poly([Monomial([name: 1]): .one]) }

    public static let zero = Poly()
    public static let one = Poly(constant: .one)

    public var isZero: Bool { terms.isEmpty }
    public var variables: Set<String> { Set(terms.keys.flatMap { $0.powers.keys }) }
    public var isConstant: Bool { terms.keys.allSatisfy(\.isConstant) }
    public var hasRadicals: Bool { terms.keys.contains { $0.radicand != 1 } }

    /// Рациональное число, если многочлен — просто число без корней.
    public var rational: Rational? {
        if isZero { return .zero }
        guard terms.count == 1, let (m, c) = terms.first, m == .one else { return nil }
        return c
    }

    public var degree: Int { terms.keys.map(\.degree).max() ?? 0 }

    public func adding(_ o: Poly) throws -> Poly {
        var r = terms
        for (m, c) in o.terms { r[m] = try (r[m] ?? .zero).adding(c) }
        return Poly(r)
    }

    public func negated() -> Poly { Poly(terms.mapValues { $0.negated() }) }

    public func subtracting(_ o: Poly) throws -> Poly { try adding(o.negated()) }

    public func scaled(_ k: Rational) throws -> Poly {
        var r: [Monomial: Rational] = [:]
        for (m, c) in terms { r[m] = try c.multiplying(k) }
        return Poly(r)
    }

    public func multiplying(_ o: Poly) throws -> Poly {
        var r: [Monomial: Rational] = [:]
        for (m1, c1) in terms {
            for (m2, c2) in o.terms {
                var p = m1.powers
                for (v, e) in m2.powers { p[v, default: 0] += e }
                // √a · √b = s·√k, где a·b = s²·k.
                let (outside, inside) = squareFree(try mul(m1.radicand, m2.radicand))
                let m = Monomial(p, radicand: inside)
                let c = try c1.multiplying(c2).multiplying(Rational(outside))
                r[m] = try (r[m] ?? .zero).adding(c)
            }
        }
        guard r.count <= 400 else { throw MathError.unsupported("слишком длинное выражение") }
        return Poly(r)
    }

    public func power(_ n: Int) throws -> Poly {
        guard n >= 0, n <= 32 else { throw MathError.unsupported("слишком большая степень") }
        var result = Poly.one
        for _ in 0..<n { result = try result.multiplying(self) }
        return result
    }

    /// Значение при подстановке рациональных чисел (корни должны отсутствовать).
    public func evaluate(_ values: [String: Rational]) throws -> Poly {
        var r = Poly.zero
        for (m, c) in terms {
            var term = Poly([Monomial(radicand: m.radicand): c])
            for (v, e) in m.powers {
                guard let x = values[v] else {
                    term = try term.multiplying(Poly([Monomial([v: e]): .one]))
                    continue
                }
                term = try term.scaled(x.power(e))
            }
            r = try r.adding(term)
        }
        return r
    }

    /// Приблизительное значение константы — только чтобы узнать знак числа с корнями.
    public var approximate: Double? {
        guard isConstant else { return nil }
        return terms.reduce(0.0) { acc, t in
            acc + Double(t.value.num) / Double(t.value.den) * Double(t.key.radicand).squareRoot()
        }
    }

    /// Знак константы. Для a + b√k считаем точно, для сложных — по приближению.
    public var sign: Int? {
        guard isConstant else { return nil }
        if let r = rational { return r.sign }
        if terms.count <= 2 {
            let a = terms[.one] ?? .zero
            let radical = terms.first { $0.key.radicand != 1 }
            if let (m, b) = radical {
                // sign(a + b√k): сравниваем a² и b²·k.
                let sa = a.sign, sb = b.sign
                if sa == 0 { return sb }
                if sa == sb { return sa }
                guard let a2 = try? a.multiplying(a), let b2k = try? b.multiplying(b).multiplying(Rational(m.radicand)) else {
                    return approximate.map { $0 > 0 ? 1 : ($0 < 0 ? -1 : 0) }
                }
                if a2 == b2k { return 0 }
                return a2 > b2k ? sa : sb
            }
        }
        return approximate.map { $0 > 1e-12 ? 1 : ($0 < -1e-12 ? -1 : 0) }
    }

    /// Коэффициенты по одной переменной: [a0, a1, …]. nil — если есть другие переменные или корни.
    public func coefficients(in v: String) -> [Rational]? {
        guard variables.isSubset(of: [v]), !hasRadicals else { return nil }
        var result = Array(repeating: Rational.zero, count: degree + 1)
        for (m, c) in terms { result[m.powers[v] ?? 0] = c }
        return result
    }

    public static func fromCoefficients(_ cs: [Rational], _ v: String) -> Poly {
        var t: [Monomial: Rational] = [:]
        for (i, c) in cs.enumerated() { t[i == 0 ? .one : Monomial([v: i])] = c }
        return Poly(t)
    }
}

/// Рациональная функция: многочлен / многочлен. Равенство — крест-накрест,
/// поэтому (x² − 1)/(x − 1) и x + 1 считаются равными (как в школе — при x ≠ 1).
public struct RatFunc: Sendable {
    public var num: Poly
    public var den: Poly

    public init(_ num: Poly, _ den: Poly = .one) throws {
        guard !den.isZero else { throw MathError.divisionByZero }
        self.num = num
        self.den = den
        try normalize()
    }

    public init(constant r: Rational) {
        num = Poly(constant: r)
        den = .one
    }

    public static func variable(_ v: String) -> RatFunc {
        // swiftlint:disable:next force_try
        try! RatFunc(.variable(v))
    }

    public var isPolynomial: Bool { den.rational != nil }
    public var variables: Set<String> { num.variables.union(den.variables) }

    /// Значение-число, если переменных нет (может содержать корни).
    public var constant: Poly? {
        guard variables.isEmpty, let d = den.rational else { return nil }
        return try? num.scaled(d.reciprocal())
    }

    public var rational: Rational? { constant?.rational }

    /// Многочлен (если знаменатель — число).
    public var polynomial: Poly? {
        guard let d = den.rational else { return nil }
        return try? num.scaled(d.reciprocal())
    }

    public func adding(_ o: RatFunc) throws -> RatFunc {
        if den == o.den { return try RatFunc(num.adding(o.num), den) }
        return try RatFunc(num.multiplying(o.den).adding(o.num.multiplying(den)), den.multiplying(o.den))
    }

    public func negated() -> RatFunc {
        // swiftlint:disable:next force_try
        try! RatFunc(num.negated(), den)
    }

    public func subtracting(_ o: RatFunc) throws -> RatFunc { try adding(o.negated()) }

    public func multiplying(_ o: RatFunc) throws -> RatFunc {
        try RatFunc(num.multiplying(o.num), den.multiplying(o.den))
    }

    public func dividing(_ o: RatFunc) throws -> RatFunc {
        guard !o.num.isZero else { throw MathError.divisionByZero }
        return try RatFunc(num.multiplying(o.den), den.multiplying(o.num))
    }

    public func power(_ n: Int) throws -> RatFunc {
        if n >= 0 { return try RatFunc(num.power(n), den.power(n)) }
        guard !num.isZero else { throw MathError.divisionByZero }
        return try RatFunc(den.power(-n), num.power(-n))
    }

    public func equals(_ o: RatFunc) -> Bool {
        guard let l = try? num.multiplying(o.den), let r = try? o.num.multiplying(den) else { return false }
        return l == r
    }

    /// Убирает числовой знаменатель, корни из знаменателя-числа и общий делитель многочленов от одной переменной.
    private mutating func normalize() throws {
        if let d = den.rational {
            if d != .one {
                num = try num.scaled(d.reciprocal())
                den = .one
            }
            return
        }
        // Избавляемся от корня в знаменателе: a + b√k → умножаем на a − b√k.
        var guardCount = 0
        while den.isConstant, den.hasRadicals, guardCount < 3 {
            guardCount += 1
            let conj = Poly(den.terms.mapValues { $0 }.reduce(into: [Monomial: Rational]()) { acc, t in
                acc[t.key] = t.key.radicand == 1 ? t.value : t.value.negated()
            })
            num = try num.multiplying(conj)
            den = try den.multiplying(conj)
            if let d = den.rational {
                num = try num.scaled(d.reciprocal())
                den = .one
                return
            }
        }
        let vars = variables
        if vars.count == 1, let v = vars.first,
           let n = num.coefficients(in: v), let d = den.coefficients(in: v) {
            let g = polyGCD(n, d)
            if g.count > 1 {
                let (qn, _) = polyDivide(n, g)
                let (qd, _) = polyDivide(d, g)
                num = Poly.fromCoefficients(qn, v)
                den = Poly.fromCoefficients(qd, v)
            }
            // Старший коэффициент знаменателя — 1, чтобы запись была однозначной.
            if let lead = den.coefficients(in: v)?.last, lead != .one, !lead.isZero {
                num = try num.scaled(lead.reciprocal())
                den = try den.scaled(lead.reciprocal())
            }
            if let d = den.rational, d != .one {
                num = try num.scaled(d.reciprocal())
                den = .one
            }
        }
    }
}

// MARK: - Многочлены от одной переменной (коэффициенты от младшего к старшему)

func trimmed(_ a: [Rational]) -> [Rational] {
    var a = a
    while a.count > 1, a.last!.isZero { a.removeLast() }
    return a
}

/// Деление с остатком.
func polyDivide(_ a: [Rational], _ b: [Rational]) -> (q: [Rational], r: [Rational]) {
    var r = trimmed(a)
    let b = trimmed(b)
    guard let lead = b.last, !lead.isZero else { return ([.zero], r) }
    if r.count < b.count { return ([.zero], r) }
    var q = Array(repeating: Rational.zero, count: r.count - b.count + 1)
    for shift in stride(from: r.count - b.count, through: 0, by: -1) {
        guard let c = try? r[shift + b.count - 1].dividing(lead) else { continue }
        q[shift] = c
        for i in 0..<b.count {
            if let prod = try? b[i].multiplying(c), let v = try? r[i + shift].subtracting(prod) { r[i + shift] = v }
        }
    }
    let rem = trimmed(Array(r.prefix(b.count - 1)))
    return (trimmed(q), rem.isEmpty ? [.zero] : rem)
}

/// НОД многочленов (нормирован: старший коэффициент 1).
func polyGCD(_ a: [Rational], _ b: [Rational]) -> [Rational] {
    var x = trimmed(a), y = trimmed(b)
    var steps = 0
    while !(y.count == 1 && y[0].isZero), steps < 50 {
        steps += 1
        let r = polyDivide(x, y).r
        x = y
        y = r
    }
    guard let lead = x.last, !lead.isZero, let inv = try? lead.reciprocal() else { return [.one] }
    return x.map { (try? $0.multiplying(inv)) ?? $0 }
}
