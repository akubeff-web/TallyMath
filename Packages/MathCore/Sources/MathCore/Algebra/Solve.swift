/// Промежуток с рациональными концами; nil — бесконечность.
public struct Interval: Hashable, Sendable {
    public var low: Rational?
    public var lowClosed: Bool
    public var high: Rational?
    public var highClosed: Bool

    public init(low: Rational?, lowClosed: Bool, high: Rational?, highClosed: Bool) {
        self.low = low
        self.lowClosed = low == nil ? false : lowClosed
        self.high = high
        self.highClosed = high == nil ? false : highClosed
    }

    public static let all = Interval(low: nil, lowClosed: false, high: nil, highClosed: false)

    var isEmpty: Bool {
        guard let l = low, let h = high else { return false }
        if l > h { return true }
        return l == h && !(lowClosed && highClosed)
    }

    func intersect(_ o: Interval) -> Interval {
        var lo = low, loC = lowClosed
        if let ol = o.low {
            if lo == nil || ol > lo! { lo = ol; loC = o.lowClosed } else if ol == lo! { loC = loC && o.lowClosed }
        }
        var hi = high, hiC = highClosed
        if let oh = o.high {
            if hi == nil || oh < hi! { hi = oh; hiC = o.highClosed } else if oh == hi! { hiC = hiC && o.highClosed }
        }
        return Interval(low: lo, lowClosed: loC, high: hi, highClosed: hiC)
    }
}

/// Объединение промежутков в каноническом виде (отсортировано, без пересечений).
public struct IntervalSet: Hashable, Sendable {
    public private(set) var parts: [Interval]

    public init(_ parts: [Interval]) {
        let sorted = parts.filter { !$0.isEmpty }.sorted { a, b in
            switch (a.low, b.low) {
            case (nil, nil): return false
            case (nil, _): return true
            case (_, nil): return false
            case let (x?, y?): return x < y || (x == y && a.lowClosed && !b.lowClosed)
            }
        }
        var merged: [Interval] = []
        for p in sorted {
            if var last = merged.last, IntervalSet.touches(last, p) {
                if last.high != nil {
                    if p.high == nil || p.high! > last.high! {
                        last.high = p.high
                        last.highClosed = p.highClosed
                    } else if p.high == last.high {
                        last.highClosed = last.highClosed || p.highClosed
                    }
                }
                merged[merged.count - 1] = last
            } else {
                merged.append(p)
            }
        }
        self.parts = merged
    }

    static func touches(_ a: Interval, _ b: Interval) -> Bool {
        guard let ah = a.high, let bl = b.low else { return true }
        if bl < ah { return true }
        return bl == ah && (a.highClosed || b.lowClosed)
    }

    public func intersect(_ o: IntervalSet) -> IntervalSet {
        IntervalSet(parts.flatMap { a in o.parts.map { a.intersect($0) } })
    }
}

/// Множество решений уравнения, неравенства или системы.
public enum SolutionSet: Sendable, Equatable {
    /// Конечный набор чисел (могут быть с корнями: 2 ± √3).
    case values([Poly])
    /// Любое число, кроме перечисленных (ОДЗ).
    case all(except: [Poly])
    case intervals(IntervalSet)
    /// Решения системы: набор значений переменных.
    case point([String: Rational])
    /// У системы бесконечно много решений.
    case infinite
    case none

    public static func == (a: SolutionSet, b: SolutionSet) -> Bool {
        switch (a.normalized, b.normalized) {
        case (.values(let x), .values(let y)): return sameSet(x, y)
        case (.all(let x), .all(let y)): return sameSet(x, y)
        case (.intervals(let x), .intervals(let y)): return x == y
        case (.point(let x), .point(let y)): return x == y
        case (.infinite, .infinite), (.none, .none): return true
        default: return false
        }
    }

    /// Пустое множество и «все числа» в одном виде, как бы их ни записали.
    var normalized: SolutionSet {
        switch self {
        case .values(let v) where v.isEmpty: return .none
        case .intervals(let s) where s.parts.isEmpty: return .none
        case .intervals(let s) where s.parts == [.all]: return .all(except: [])
        case .intervals(let s):
            // Набор отдельных точек [a; a] — это конечное множество.
            if s.parts.allSatisfy({ $0.low != nil && $0.low == $0.high }) {
                return .values(s.parts.map { Poly(constant: $0.low!) })
            }
            // Вся прямая без точек: (−∞; a) ∪ (a; +∞) — это «все, кроме a».
            if s.parts.first?.low == nil, s.parts.last?.high == nil,
               zip(s.parts, s.parts.dropFirst()).allSatisfy({ $0.high == $1.low && !$0.highClosed && !$1.lowClosed }) {
                return .all(except: s.parts.dropLast().compactMap { $0.high.map { Poly(constant: $0) } })
            }
            return self
        default: return self
        }
    }

    public var values: [Poly]? {
        if case .values(let v) = normalized { return v }
        return nil
    }
}

func sameSet(_ a: [Poly], _ b: [Poly]) -> Bool {
    let x = Set(a), y = Set(b)
    return x == y
}

public enum Solver {
    /// Решает уравнение, неравенство, систему или разбирает запись ответа.
    public static func solve(_ s: Statement) throws -> SolutionSet {
        switch s {
        case .relation(let l, let r, let rr):
            let vars = l.variables.union(rr.variables)
            guard vars.count <= 1 else {
                throw MathError.unsupported("уравнение с несколькими переменными решается в системе")
            }
            guard let v = vars.first.map(baseName) else {
                throw MathError.unsupported("в записи нет переменной")
            }
            let left = l.renamingVariables(baseName), right = rr.renamingVariables(baseName)
            return r == .eq ? try solveEquation(left, right, v) : try solveInequality(left, r, right, v)
        case .either(let parts):
            var all: [Poly] = []
            for p in parts {
                guard let vals = try solve(p).values else {
                    throw MathError.unsupported("в «или» ожидаются отдельные значения")
                }
                all.append(contentsOf: vals)
            }
            return .values(all)
        case .system(let parts):
            return try solveSystem(parts)
        case .intervals(let list):
            return .intervals(IntervalSet(try list.map { iv in
                Interval(low: try iv.low.map(rationalEndpoint), lowClosed: iv.lowClosed,
                         high: try iv.high.map(rationalEndpoint), highClosed: iv.highClosed)
            }))
        case .noSolution: return .none
        case .anyNumber: return .all(except: [])
        default:
            throw MathError.unsupported("это не уравнение и не ответ")
        }
    }

    static func rationalEndpoint(_ e: Expr) throws -> Rational {
        guard let r = try e.rationalValue() else { throw MathError.unsupported("конец промежутка должен быть числом") }
        return r
    }

    // MARK: Уравнения

    static func solveEquation(_ l: Expr, _ r: Expr, _ v: String) throws -> SolutionSet {
        let f: RatFunc
        do {
            f = try l.normalForm().subtracting(r.normalForm())
        } catch MathError.unsupported {
            return try solveByCases(l, r, v)
        }
        // ОДЗ берём из исходной записи: после сокращения знаменатель (x − 1) может исчезнуть.
        let denRoots = try domainExclusions([l, r], v)
        if f.num.isZero { return .all(except: denRoots) }
        guard f.num.variables.isSubset(of: [v]) else { throw MathError.unsupported("лишние переменные") }
        let roots = try polyRoots(f.num, v)
        // Корни знаменателя — посторонние.
        return .values(roots.filter { !denRoots.contains($0) })
    }

    /// Значения переменной, при которых какой-то знаменатель записи равен нулю.
    static func domainExclusions(_ exprs: [Expr], _ v: String) throws -> [Poly] {
        var result: [Poly] = []
        for e in exprs {
            for node in e.allNodes {
                var den: Expr?
                switch node {
                case .fraction(_, let b, _), .div(_, let b): den = b
                case .pow(let b, let ex):
                    if let k = try? ex.rationalValue(), k.sign < 0 { den = b }
                default: break
                }
                guard let d = den, d.variables.contains(v),
                      let nf = try? d.normalForm(), !nf.num.isConstant else { continue }
                for root in try polyRoots(nf.num, v) where !result.contains(root) { result.append(root) }
            }
        }
        return result
    }

    /// Уравнения с модулем: раскрываем первый модуль двумя случаями.
    static func solveByCases(_ l: Expr, _ r: Expr, _ v: String) throws -> SolutionSet {
        let whole = Expr.sub(.group(l), .group(r))
        guard let path = whole.allPaths.first(where: { if case .abs = whole.node(at: $0) { return true }; return false }),
              case .abs(let inner) = whole.node(at: path) else {
            throw MathError.unsupported("не умею решать такое уравнение")
        }
        var result: [Poly] = []
        for sign in [1, -1] {
            let replaced = whole.replacing(at: path, with: sign == 1 ? .group(inner) : .neg(.group(inner)))
            guard case .values(let vals) = try solveEquation(replaced, .integer(0), v).normalized else { continue }
            for x in vals {
                guard let xr = x.rational,
                      let s = try inner.substituting([v: xr]).normalForm().rational?.sign else { continue }
                if (sign == 1 && s >= 0) || (sign == -1 && s < 0) { result.append(x) }
            }
        }
        return .values(Array(Set(result)))
    }

    /// Корни многочлена от одной переменной: рациональные — подбором, остаток до 2-й степени — по формуле.
    public static func polyRoots(_ p: Poly, _ v: String) throws -> [Poly] {
        if p.degree <= 1 || p.hasRadicals { return try linearRoot(p, v) }
        guard var c = p.coefficients(in: v) else { throw MathError.unsupported("коэффициенты с корнями") }
        var roots: [Poly] = []
        // x = 0 как корень.
        while c.count > 1, c[0].isZero {
            if !roots.contains(.zero) { roots.append(.zero) }
            c.removeFirst()
        }
        // Выше второй степени — сначала снимаем рациональные корни подбором.
        for r in rationalRootCandidates(c) {
            if c.count <= 3 { break }
            while c.count > 3, evaluate(c, r).isZero {
                let root = Poly(constant: r)
                if !roots.contains(root) { roots.append(root) }
                c = polyDivide(c, [r.negated(), .one]).q
            }
        }
        switch c.count {
        case 1: break
        case 2:
            let x = try c[0].negated().dividing(c[1])
            if !roots.contains(Poly(constant: x)) { roots.append(Poly(constant: x)) }
        case 3:
            for x in try quadraticRoots(a: c[2], b: c[1], c: c[0]) where !roots.contains(x) { roots.append(x) }
        default:
            throw MathError.unsupported("уравнение выше второй степени без рациональных корней")
        }
        return roots
    }

    static func linearRoot(_ p: Poly, _ v: String) throws -> [Poly] {
        guard p.degree <= 1 else { throw MathError.unsupported("коэффициенты с корнями") }
        var a = Poly.zero, b = Poly.zero
        for (m, coef) in p.terms {
            let term = Poly([Monomial(radicand: m.radicand): coef])
            if m.powers[v] == 1 { a = try a.adding(term) } else { b = try b.adding(term) }
        }
        if a.isZero { return [] }
        guard let x = try RatFunc(b.negated(), a).constant else { throw MathError.unsupported("не число") }
        return [x]
    }

    /// (−b ± √D) / 2a, где D = b² − 4ac.
    static func quadraticRoots(a: Rational, b: Rational, c: Rational) throws -> [Poly] {
        let d = try b.multiplying(b).subtracting(Rational(4).multiplying(a).multiplying(c))
        if d.sign < 0 { return [] }
        let twoA = try Rational(2).multiplying(a)
        let base = Poly(constant: try b.negated().dividing(twoA))
        if d.isZero { return [base] }
        let root = try sqrtPoly(d).scaled(twoA.reciprocal())
        return [try base.adding(root), try base.subtracting(root)]
    }

    static func evaluate(_ c: [Rational], _ x: Rational) -> Rational {
        var acc = Rational.zero
        for coef in c.reversed() {
            acc = (try? acc.multiplying(x).adding(coef)) ?? acc
        }
        return acc
    }

    /// ±p/q, где p делит свободный член, q — старший (после приведения к целым).
    static func rationalRootCandidates(_ c: [Rational]) -> [Rational] {
        var l = 1
        for x in c { l = (try? lcm(l, x.den)) ?? l }
        let ints = c.map { $0.num * (l / $0.den) }
        guard let a0 = ints.first, let an = ints.last, a0 != 0, an != 0,
              abs(a0) <= 1_000_000, abs(an) <= 1_000_000 else { return [] }
        var result: [Rational] = []
        for p in divisors(abs(a0)) {
            for q in divisors(abs(an)) {
                for s in [1, -1] {
                    let r = Rational.of(s * p, q)
                    if !result.contains(r) { result.append(r) }
                }
            }
        }
        return result
    }

    static func divisors(_ n: Int) -> [Int] {
        guard n > 0 else { return [] }
        var d: [Int] = []
        var i = 1
        while i * i <= n {
            if n % i == 0 {
                d.append(i)
                if i != n / i { d.append(n / i) }
            }
            i += 1
        }
        return d.sorted()
    }

    // MARK: Неравенства

    static func solveInequality(_ l: Expr, _ r: Relation, _ rr: Expr, _ v: String) throws -> SolutionSet {
        let f = try l.normalForm().subtracting(rr.normalForm())
        guard let p = f.polynomial, let c = p.coefficients(in: v) else {
            throw MathError.unsupported("неравенство с дробью или корнем")
        }
        switch c.count {
        case 1:
            // Без переменной: верно всегда или никогда.
            return holds(c[0], r) ? .all(except: []) : .none
        case 2:
            var rel = r
            var a = c[1], b = c[0]
            if a.isZero { return holds(b, r) ? .all(except: []) : .none }
            if a.sign < 0 {
                a = a.negated()
                b = b.negated()
                rel = r.flipped
            }
            let x = try b.negated().dividing(a)
            return .intervals(IntervalSet([interval(for: rel, at: x)]))
        case 3:
            return try solveQuadraticInequality(a: c[2], b: c[1], c: c[0], r)
        default:
            throw MathError.unsupported("неравенство выше второй степени")
        }
    }

    static func holds(_ value: Rational, _ r: Relation) -> Bool {
        switch r {
        case .eq: return value.isZero
        case .ne: return !value.isZero
        case .lt: return value.sign < 0
        case .gt: return value.sign > 0
        case .le: return value.sign <= 0
        case .ge: return value.sign >= 0
        }
    }

    /// x rel a, где после приведения x стоит слева с положительным коэффициентом.
    static func interval(for r: Relation, at a: Rational) -> Interval {
        switch r {
        case .lt: return Interval(low: nil, lowClosed: false, high: a, highClosed: false)
        case .le: return Interval(low: nil, lowClosed: false, high: a, highClosed: true)
        case .gt: return Interval(low: a, lowClosed: false, high: nil, highClosed: false)
        case .ge: return Interval(low: a, lowClosed: true, high: nil, highClosed: false)
        case .eq: return Interval(low: a, lowClosed: true, high: a, highClosed: true)
        case .ne: return .all
        }
    }

    /// Квадратное неравенство с рациональными корнями (иррациональные концы не поддерживаем).
    static func solveQuadraticInequality(a: Rational, b: Rational, c: Rational, _ r: Relation) throws -> SolutionSet {
        var rel = r, aa = a, bb = b, cc = c
        if aa.sign < 0 { aa = aa.negated(); bb = bb.negated(); cc = cc.negated(); rel = r.flipped }
        let roots = try quadraticRoots(a: aa, b: bb, c: cc)
        let rs = roots.compactMap(\.rational).sorted()
        guard rs.count == roots.count else { throw MathError.unsupported("концы промежутка с корнями") }
        let closed = rel == .le || rel == .ge
        switch rs.count {
        case 0:
            return (rel == .gt || rel == .ge || rel == .ne) ? .all(except: []) : .none
        case 1:
            switch rel {
            case .gt, .ne: return .all(except: [Poly(constant: rs[0])])
            case .ge: return .all(except: [])
            case .lt: return .none
            default: return .values([Poly(constant: rs[0])])
            }
        default:
            if rel == .lt || rel == .le {
                return .intervals(IntervalSet([Interval(low: rs[0], lowClosed: closed, high: rs[1], highClosed: closed)]))
            }
            return .intervals(IntervalSet([
                Interval(low: nil, lowClosed: false, high: rs[0], highClosed: closed),
                Interval(low: rs[1], lowClosed: closed, high: nil, highClosed: false),
            ]))
        }
    }

    // MARK: Системы

    static func solveSystem(_ parts: [Statement]) throws -> SolutionSet {
        let relations: [(Expr, Relation, Expr)] = try parts.map {
            guard case .relation(let l, let r, let rr) = $0 else { throw MathError.unsupported("в системе только уравнения") }
            return (l.renamingVariables(baseName), r, rr.renamingVariables(baseName))
        }
        let vars = Set(relations.flatMap { $0.0.variables.union($0.2.variables) }).sorted()
        // Система неравенств с одной переменной — пересечение промежутков.
        if vars.count == 1, relations.contains(where: { $0.1.isInequality }) {
            var acc = IntervalSet([.all])
            for (l, r, rr) in relations {
                let s = try solveInequality(l, r, rr, vars[0])
                acc = acc.intersect(try intervalSet(of: s))
            }
            return .intervals(acc)
        }
        guard relations.allSatisfy({ $0.1 == .eq }), (1...3).contains(vars.count) else {
            throw MathError.unsupported("такую систему проверить не могу")
        }
        // Линейная система: строки a1·x + a2·y = c.
        var rows: [[Rational]] = []
        for (l, _, r) in relations {
            let f = try l.normalForm().subtracting(r.normalForm())
            guard let p = f.polynomial, p.degree <= 1, !p.hasRadicals else {
                throw MathError.unsupported("нелинейная система")
            }
            var row = vars.map { p.terms[Monomial([$0: 1])] ?? .zero }
            row.append((p.terms[.one] ?? .zero).negated())
            rows.append(row)
        }
        return try gauss(rows, vars)
    }

    static func intervalSet(of s: SolutionSet) throws -> IntervalSet {
        switch s.normalized {
        case .intervals(let i): return i
        case .all(let except) where except.isEmpty: return IntervalSet([.all])
        case .none: return IntervalSet([])
        case .values(let v):
            return IntervalSet(try v.map {
                guard let r = $0.rational else { throw MathError.unsupported("не число") }
                return Interval(low: r, lowClosed: true, high: r, highClosed: true)
            })
        default: throw MathError.unsupported("не промежуток")
        }
    }

    /// Метод Гаусса над точными дробями.
    static func gauss(_ input: [[Rational]], _ vars: [String]) throws -> SolutionSet {
        var m = input
        let n = vars.count
        var pivotRow = 0
        var pivots: [Int] = []
        for col in 0..<n {
            guard let sel = (pivotRow..<m.count).first(where: { !m[$0][col].isZero }) else { continue }
            m.swapAt(pivotRow, sel)
            let inv = try m[pivotRow][col].reciprocal()
            m[pivotRow] = try m[pivotRow].map { try $0.multiplying(inv) }
            for r in 0..<m.count where r != pivotRow && !m[r][col].isZero {
                let k = m[r][col]
                for c in 0...n { m[r][c] = try m[r][c].subtracting(k.multiplying(m[pivotRow][c])) }
            }
            pivots.append(col)
            pivotRow += 1
            if pivotRow == m.count { break }
        }
        // 0 = c ≠ 0 — решений нет.
        for row in m where row.prefix(n).allSatisfy(\.isZero) && !row[n].isZero { return .none }
        if pivots.count < n { return .infinite }
        var point: [String: Rational] = [:]
        for (i, col) in pivots.enumerated() { point[vars[col]] = m[i][n] }
        return .point(point)
    }
}

/// «x1», «x2» в ответе — это та же переменная x.
func baseName(_ v: String) -> String {
    String(v.prefix { !$0.isNumber })
}

extension Expr {
    func renamingVariables(_ f: (String) -> String) -> Expr {
        switch self {
        case .variable(let v): return .variable(f(v))
        case .fraction(let a, let b, let ann):
            return .fraction(a.renamingVariables(f), b.renamingVariables(f), annotation: ann)
        case .add(let a, let b): return .add(a.renamingVariables(f), b.renamingVariables(f))
        case .sub(let a, let b): return .sub(a.renamingVariables(f), b.renamingVariables(f))
        case .mul(let a, let b): return .mul(a.renamingVariables(f), b.renamingVariables(f))
        case .div(let a, let b): return .div(a.renamingVariables(f), b.renamingVariables(f))
        case .pow(let a, let b): return .pow(a.renamingVariables(f), b.renamingVariables(f))
        case .neg(let a): return .neg(a.renamingVariables(f))
        case .sqrt(let a): return .sqrt(a.renamingVariables(f))
        case .abs(let a): return .abs(a.renamingVariables(f))
        case .percent(let a): return .percent(a.renamingVariables(f))
        case .group(let a): return .group(a.renamingVariables(f))
        default: return self
        }
    }
}
