/// «Неправильные» преобразования выражения: так обычно ошибаются люди.
/// Если строка ученика совпала с одной из них — мы знаем, какую ошибку назвать.
enum Mutations {
    static func candidates(of e: Expr) -> [(MistakeReport, Expr)] {
        var result: [(MistakeReport, Expr)] = []
        for path in e.allPaths {
            for (report, replacement) in local(e.node(at: path)) {
                result.append((report, e.replacing(at: path, with: replacement)))
            }
        }
        return result
    }

    /// Ошибки внутри одного узла.
    static func local(_ node: Expr) -> [(MistakeReport, Expr)] {
        var out: [(MistakeReport, Expr)] = []
        switch node {
        case .add(let x, let y), .sub(let x, let y):
            let isAdd: Bool
            if case .add = node { isAdd = true } else { isAdd = false }
            // a/b ± c/d → (a ± c)/(b ± d)
            if let (a, b) = intFraction(x), let (c, d) = intFraction(y) {
                let top = isAdd ? a + c : a - c
                let detail = isAdd
                    ? "Низ не складываем: \(b) + \(d) — так нельзя."
                    : "Низ не вычитаем: низ остаётся общим."
                out.append((MistakeReport(.addedTopsAndBottoms, detail: detail),
                            .fraction(.integer(top), .integer(isAdd ? b + d : b - d), annotation: nil)))
            }
            // Перепутан знак действия.
            out.append((MistakeReport(.signError), isAdd ? .sub(x, y) : .add(x, y)))
            // Минус перед скобкой: a − (b + c) → a − b + c.
            if !isAdd, case .group(let inner) = y {
                switch inner {
                case .add(let b, let c):
                    out.append((MistakeReport(.minusBeforeBracket), .add(.sub(x, b), c)))
                case .sub(let b, let c):
                    out.append((MistakeReport(.minusBeforeBracket), .sub(.sub(x, b), c)))
                default: break
                }
            }
        case .neg(let inner):
            out.append((MistakeReport(.signError), inner))
            if case .group(let g) = inner {
                switch g {
                case .add(let b, let c): out.append((MistakeReport(.minusBeforeBracket), .add(.neg(b), c)))
                case .sub(let b, let c): out.append((MistakeReport(.minusBeforeBracket), .sub(.neg(b), c)))
                default: break
                }
            }
        case .fraction(let top, let bottom, _):
            if case .integer(let a) = top, case .integer(let b) = bottom {
                for k in 2...10 {
                    out.append((MistakeReport(.multipliedOnlyTop,
                                              detail: "Умножил только верх. Низ \(b) тоже умножь на \(k)."),
                                .frac(a * k, b)))
                    out.append((MistakeReport(.multipliedOnlyBottom,
                                              detail: "Умножил только низ. Верх \(a) тоже умножь на \(k)."),
                                .frac(a, b * k)))
                    if a % k == 0 {
                        out.append((MistakeReport(.dividedOnlyTop, detail: "Поделил только верх. Низ \(b) тоже раздели на \(k)."),
                                    .frac(a / k, b)))
                    }
                    if b % k == 0 {
                        out.append((MistakeReport(.dividedOnlyBottom, detail: "Поделил только низ. Верх \(a) тоже раздели на \(k)."),
                                    .frac(a, b / k)))
                    }
                }
            }
            out += cancelled(top, bottom)
        case .div(let x, let y):
            // a/b : c/d → a/b · c/d (не перевернул).
            out.append((MistakeReport(.divisionNotFlipped), .mul(x, y)))
            out += cancelled(x, y)
        case .pow(let base, let exp):
            if case .integer(2) = exp, case .group(let g) = base {
                switch g {
                case .add(let a, let b):
                    out.append((MistakeReport(.squareMissingDoubleProduct),
                                .add(.pow(a, .integer(2)), .pow(b, .integer(2)))))
                case .sub(let a, let b):
                    out.append((MistakeReport(.squareMissingDoubleProduct),
                                .sub(.pow(a, .integer(2)), .pow(b, .integer(2)))))
                    out.append((MistakeReport(.squareMissingDoubleProduct),
                                .add(.pow(a, .integer(2)), .pow(b, .integer(2)))))
                default: break
                }
            }
            if case .pow(let a, let m) = base.unwrapped {
                out.append((MistakeReport(.powersAdded), .pow(a, .add(m, exp))))
            }
        case .mul(let x, let y):
            if case .pow(let a, let m) = x.unwrapped, case .pow(let b, let n) = y.unwrapped, a == b {
                out.append((MistakeReport(.powersMultiplied), .pow(a, .mul(m, n))))
            }
        default:
            break
        }
        return out
    }

    /// (a + b)/a → b: сокращение слагаемых.
    static func cancelled(_ top: Expr, _ bottom: Expr) -> [(MistakeReport, Expr)] {
        var out: [(MistakeReport, Expr)] = []
        let t = top.unwrapped.terms, b = bottom.unwrapped.terms
        guard t.count >= 2 else { return out }
        for (i, term) in t.enumerated() {
            if b.count == 1, equivalent(term, b[0]) == true {
                let rest = t.enumerated().filter { $0.offset != i }.map(\.element)
                out.append((MistakeReport(.cancelledTerms), sum(rest)))
            }
            if b.count >= 2, let j = b.firstIndex(where: { equivalent($0, term) == true }) {
                let restT = t.enumerated().filter { $0.offset != i }.map(\.element)
                let restB = b.enumerated().filter { $0.offset != j }.map(\.element)
                out.append((MistakeReport(.cancelledTerms), .fraction(sum(restT), sum(restB), annotation: nil)))
            }
        }
        return out
    }

    static func sum(_ terms: [Expr]) -> Expr {
        guard var acc = terms.first else { return .integer(0) }
        for t in terms.dropFirst() {
            if case .neg(let inner) = t { acc = .sub(acc, inner) } else { acc = .add(acc, t) }
        }
        return acc
    }

    static func intFraction(_ e: Expr) -> (Int, Int)? {
        switch e.unwrapped {
        case .fraction(.integer(let a), .integer(let b), _): return (a, b)
        default: return nil
        }
    }
}

/// Ошибки, которые видны по самому значению ответа.
enum ValueMistakes {
    static func detect(correct v: Rational, answer u: Rational, problem: Expr?) -> MistakeReport? {
        if v.isZero { return nil }
        // Целая часть потеряна: 5/3 → 2/3.
        if !v.isInteger, v.absolute > .one,
           let frac = try? v.absolute.subtracting(Rational(v.absolute.floor)), u.absolute == frac {
            return MistakeReport(.forgotWholePart,
                                 detail: "Потерял целую часть \(v.absolute.floor).")
        }
        // Запятая.
        for k in [10, 100, 1000] {
            if let a = try? v.multiplying(Rational(k)), a == u { return MistakeReport(.decimalPoint) }
            if let b = try? v.dividing(Rational(k)), b == u { return MistakeReport(.decimalPoint) }
        }
        if u == v.negated() { return MistakeReport(.signError, detail: "Знак не тот.") }
        // Соседний факт таблицы умножения: 7 × 8 = 48 — это 6 × 8.
        if let p = problem, case .mul(.integer(let a), .integer(let b)) = p.unwrapped, u.isInteger {
            for (x, y) in [(a - 1, b), (a + 1, b), (a, b - 1), (a, b + 1)] where x * y == u.num {
                return MistakeReport(.neighbourTableFact, detail: "\(x) × \(y) = \(u.num). А у нас \(a) × \(b).")
            }
        }
        if let p = problem, case .div(.integer(let a), .integer(let b)) = p.unwrapped, u.isInteger, b != 0 {
            let q = a / b
            if u.num == q + 1 || u.num == q - 1 {
                return MistakeReport(.neighbourTableFact, detail: "Проверь: \(u.num) × \(b) = \(u.num * b), а не \(a).")
            }
        }
        return nil
    }
}
