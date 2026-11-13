extension Expr {
    /// Нормальная форма. Бросает unsupported, если запись нельзя привести к ней надёжно
    /// (модуль от выражения с переменной, корень из выражения с переменной, дробная степень).
    public func normalForm() throws -> RatFunc {
        switch self {
        case .integer(let n): return RatFunc(constant: Rational(n))
        case .decimal(let r, _): return RatFunc(constant: r)
        case .mixed(let w, let a, let b):
            return RatFunc(constant: try Rational(w).adding(Rational(a, b)))
        case .variable(let v): return .variable(v)
        case .fraction(let a, let b, _), .div(let a, let b):
            return try a.normalForm().dividing(b.normalForm())
        case .add(let a, let b): return try a.normalForm().adding(b.normalForm())
        case .sub(let a, let b): return try a.normalForm().subtracting(b.normalForm())
        case .mul(let a, let b): return try a.normalForm().multiplying(b.normalForm())
        case .neg(let a): return try a.normalForm().negated()
        case .group(let a): return try a.normalForm()
        case .percent(let a): return try a.normalForm().dividing(RatFunc(constant: Rational(100)))
        case .pow(let a, let b):
            guard let e = try b.normalForm().rational, e.isInteger else {
                throw MathError.unsupported("показатель степени должен быть целым числом")
            }
            let base = try a.normalForm()
            if e.num < 0, base.num.isZero { throw MathError.divisionByZero }
            if e.num == 0, base.num.isZero { throw MathError.undefined("0⁰ не определено") }
            return try base.power(e.num)
        case .sqrt(let a):
            let inner = try a.normalForm()
            guard let r = inner.rational else {
                throw MathError.unsupported("корень из выражения с переменной или с корнем")
            }
            return try RatFunc(sqrtPoly(r))
        case .abs(let a):
            let inner = try a.normalForm()
            guard let c = inner.constant, let s = c.sign else {
                throw MathError.unsupported("модуль выражения с переменной")
            }
            return s < 0 ? inner.negated() : inner
        }
    }

    /// Точное значение-число (может содержать корни). nil — если есть переменные.
    public func value() throws -> Poly? {
        try normalForm().constant
    }

    public func rationalValue() throws -> Rational? {
        try normalForm().rational
    }
}

/// √(p/q) = √(p·q)/q, выносим квадраты из-под корня.
func sqrtPoly(_ r: Rational) throws -> Poly {
    guard r.sign >= 0 else { throw MathError.undefined("корень из отрицательного числа") }
    if r.isZero { return .zero }
    let pq = try mul(r.num, r.den)
    let (outside, inside) = squareFree(pq)
    let coef = try Rational(outside, r.den)
    return Poly([Monomial(radicand: inside): coef])
}

/// Равенство двух записей по значению (или тождественно, если есть переменные).
/// nil — сравнить надёжно нельзя.
public func equivalent(_ a: Expr, _ b: Expr) -> Bool? {
    do {
        return try a.normalForm().equals(b.normalForm())
    } catch MathError.unsupported {
        return substitutionEquivalent(a, b)
    } catch {
        return nil
    }
}

/// Запасной путь для модулей и т. п.: подставляем несколько рациональных значений,
/// пропуская точки, где выражение не определено.
func substitutionEquivalent(_ a: Expr, _ b: Expr) -> Bool? {
    let vars = Array(a.variables.union(b.variables)).sorted()
    guard !vars.isEmpty else { return nil }
    let samples: [Rational] = [.of(3, 7), .of(-5, 3), .of(11, 2), .of(-2), .of(7), .of(1, 9), .of(-13, 4)]
    var checked = 0
    for (i, _) in samples.enumerated() {
        var values: [String: Rational] = [:]
        for (j, v) in vars.enumerated() { values[v] = samples[(i + j * 3) % samples.count] }
        guard let x = try? a.substituting(values).normalForm(), let y = try? b.substituting(values).normalForm(),
              let cx = x.constant, let cy = y.constant else { continue }
        if cx != cy { return false }
        checked += 1
    }
    return checked >= 4 ? true : nil
}

extension Expr {
    public func substituting(_ values: [String: Rational]) -> Expr {
        switch self {
        case .variable(let v):
            if let r = values[v] { return .group(.number(r)) }
            return self
        case .fraction(let a, let b, let ann):
            return .fraction(a.substituting(values), b.substituting(values), annotation: ann)
        case .add(let a, let b): return .add(a.substituting(values), b.substituting(values))
        case .sub(let a, let b): return .sub(a.substituting(values), b.substituting(values))
        case .mul(let a, let b): return .mul(a.substituting(values), b.substituting(values))
        case .div(let a, let b): return .div(a.substituting(values), b.substituting(values))
        case .pow(let a, let b): return .pow(a.substituting(values), b.substituting(values))
        case .neg(let a): return .neg(a.substituting(values))
        case .sqrt(let a): return .sqrt(a.substituting(values))
        case .abs(let a): return .abs(a.substituting(values))
        case .percent(let a): return .percent(a.substituting(values))
        case .group(let a): return .group(a.substituting(values))
        default: return self
        }
    }
}
