/// Обратное преобразование: дерево → запись, которую понимает Parser и рисует приложение.
/// Знак минуса — «−», умножение — «·» только там, где без него нельзя.
extension Expr {
    public var text: String { print(self, parentPrec: 0) }
}

extension Statement {
    public var text: String {
        switch self {
        case .expression(let e): return e.text
        case .continuation(let e): return "= " + e.text
        case .chain(let es): return es.map(\.text).joined(separator: " = ")
        case .relation(let a, let r, let b): return "\(a.text) \(r.rawValue) \(b.text)"
        case .either(let ss): return ss.map(\.text).joined(separator: " или ")
        case .system(let ss): return ss.map(\.text).joined(separator: "; ")
        case .intervals(let list):
            return list.map { iv in
                let lo = iv.low.map(\.text) ?? "−∞"
                let hi = iv.high.map(\.text) ?? "+∞"
                return (iv.lowClosed ? "[" : "(") + lo + "; " + hi + (iv.highClosed ? "]" : ")")
            }.joined(separator: " ∪ ")
        case .noSolution: return "нет решений"
        case .anyNumber: return "любое число"
        case .remainder(let q, let r): return "\(q.text) ост. \(r.text)"
        }
    }
}

private func prec(_ e: Expr) -> Int {
    switch e {
    case .add, .sub: return 1
    case .mul, .div: return 2
    case .neg: return 3
    case .pow: return 4
    default: return 5
    }
}

private func print(_ e: Expr, parentPrec: Int) -> String {
    let s: String
    switch e {
    case .integer(let n): s = String(n)
    case .decimal(_, let t): s = t
    case .mixed(let w, let a, let b): s = "\(w) \(a)/\(b)"
    case .variable(let v): s = pretty(v)
    case .fraction(let a, let b, let ann):
        let simple: Bool
        if case .integer = a, case .integer = b { simple = true } else { simple = false }
        let core = simple ? "\(a.text)/\(b.text)" : "{\(a.text)}/{\(b.text)}"
        s = core + (ann.map { "[×\($0)]" } ?? "")
    case .add(let a, let b):
        s = print(a, parentPrec: 1) + " + " + print(b, parentPrec: 2)
    case .sub(let a, let b):
        s = print(a, parentPrec: 1) + " − " + print(b, parentPrec: 2)
    case .mul(let a, let b):
        s = mulText(a, b)
    case .div(let a, let b):
        s = print(a, parentPrec: 2) + " : " + print(b, parentPrec: 3)
    case .neg(let a):
        s = "−" + print(a, parentPrec: 3)
    case .pow(let a, let b):
        // Целый показатель пишем надстрочными цифрами: x², 10⁻³.
        if let n = integerValue(b) {
            s = print(a, parentPrec: 5) + superscript(n)
        } else {
            s = print(a, parentPrec: 5) + "^" + print(b, parentPrec: 5)
        }
    case .sqrt(let a):
        s = "√" + print(a, parentPrec: 5)
    case .abs(let a):
        s = "|" + a.text + "|"
    case .percent(let a):
        s = print(a, parentPrec: 5) + "%"
    case .group(let a):
        return "(" + a.text + ")"
    }
    return prec(e) < parentPrec ? "(" + s + ")" : s
}

/// «2x», «3(x + 1)», но «2 · 3».
private func mulText(_ a: Expr, _ b: Expr) -> String {
    let left = print(a, parentPrec: 2)
    let right = print(b, parentPrec: 3)
    let rightStartsWithDigit = right.first.map { $0.isNumber } ?? false
    let leftIsNumberLike: Bool
    switch a {
    case .integer, .decimal: leftIsNumberLike = true
    default: leftIsNumberLike = false
    }
    switch b {
    case .variable, .group, .sqrt, .pow(.variable, _), .pow(.group, _):
        if !rightStartsWithDigit && (leftIsNumberLike || isVariableLike(a)) { return left + right }
    default: break
    }
    return left + " · " + right
}

private func isVariableLike(_ e: Expr) -> Bool {
    switch e {
    case .variable, .pow(.variable, _): return true
    case .mul(let a, let b): return isVariableLike(a) || isVariableLike(b)
    default: return false
    }
}

/// «x1» → «x₁».
private func pretty(_ v: String) -> String {
    let sub: [Character: Character] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
                                       "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"]
    return String(v.map { sub[$0] ?? $0 })
}

private func integerValue(_ e: Expr) -> Int? {
    switch e {
    case .integer(let n): return n
    case .neg(.integer(let n)): return -n
    case .group(let g): return integerValue(g)
    default: return nil
    }
}

private func superscript(_ n: Int) -> String {
    let map: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
                                       "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]
    return String(String(n).map { map[$0] ?? $0 })
}
