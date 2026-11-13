// Общие помощники для шагов решения: запись чисел, пошаговое вычисление и шаги с дробями.

/// Число в школьной записи: «−3», «2/5», «1 2/3» (если mixed), «0,25» (если decimal).
func show(_ r: Rational, mixed: Bool = false, decimal: Bool = false) -> String {
    if decimal, let d = r.decimalString { return d.replacingMinus }
    if r.isInteger { return String(r.num).replacingMinus }
    let sign = r.num < 0 ? "−" : ""
    if mixed, abs(r.num) > r.den {
        let (w, a, b) = r.mixedParts
        return "\(sign)\(w) \(a)/\(b)"
    }
    return "\(sign)\(abs(r.num))/\(r.den)"
}

extension String {
    var replacingMinus: String { String(map { $0 == "-" ? "−" : $0 }) }
}

/// Число как узел дерева: целое, десятичная или дробь.
func leaf(_ r: Rational, decimal: Bool) -> Expr {
    if decimal, !r.isInteger, let d = r.decimalString {
        let body = d.hasPrefix("-") ? String(d.dropFirst()) : d
        let node = Expr.decimal(r.absolute, body)
        return r.isNegative ? .neg(node) : node
    }
    return .number(r)
}

func isLeaf(_ e: Expr) -> Bool {
    switch e.unwrapped {
    case .integer, .decimal, .mixed: return true
    case .fraction(.integer, .integer, _): return true
    case .neg(let i): return isLeaf(i)
    default: return false
    }
}

// MARK: - Порядок действий

/// Пошаговое вычисление числового выражения по школьному порядку действий:
/// скобки → степени → умножение и деление слева направо → сложение и вычитание слева направо.
func arithmeticSteps(_ start: Expr, decimal: Bool = false) -> [SolutionStep] {
    var e = start
    var steps: [SolutionStep] = []
    for _ in 0..<20 {
        guard let (path, reason) = nextOperation(e) else { break }
        let node = e.node(at: path)
        guard let value = try? node.rationalValue() else { break }
        var replacement = leaf(value, decimal: decimal)
        // Отрицательное число внутри действия берём в скобки: 5 − (−3).
        if value.isNegative && !path.isEmpty { replacement = .group(replacement) }
        e = simplifyGroups(e.replacing(at: path, with: replacement))
        let shown = node.unwrapped.text
        let rules = [
            "group": "Сначала действие в скобках.",
            "pow": "Степень считаем раньше умножения.",
            "mul": "Умножение и деление — раньше сложения, слева направо.",
            "add": "Сложение и вычитание — по порядку слева направо.",
        ]
        steps.append(SolutionStep(rules[reason] ?? "Считаем.", "\(shown) = \(show(value, decimal: decimal))",
                                  line: "= " + e.text,
                                  ask: "Сколько будет \(shown)?", answer: show(value, decimal: decimal)))
        if isLeaf(e) { break }
    }
    return steps
}

/// Следующее действие: путь к узлу и причина (для подписи правила).
func nextOperation(_ e: Expr) -> ([Int], String)? {
    var candidates: [(path: [Int], depth: Int, rank: Int)] = []
    func visit(_ node: Expr, _ path: [Int], _ depth: Int) {
        var d = depth
        if case .group = node { d += 1 }
        let kids = node.children
        let ready = !kids.isEmpty && kids.allSatisfy(isLeaf) && !isLeaf(node)
        if ready {
            let rank: Int
            switch node {
            case .pow: rank = 3
            case .mul, .div: rank = 2
            case .add, .sub: rank = 1
            case .abs, .percent, .sqrt: rank = 3
            default: rank = 0
            }
            if rank > 0 { candidates.append((path, d, rank)) }
        }
        for (i, k) in kids.enumerated() { visit(k, path + [i], d) }
    }
    visit(e, [], 0)
    // Порядок: глубже в скобках, выше приоритет действия, левее.
    guard let best = candidates.sorted(by: { a, b in
        if a.depth != b.depth { return a.depth > b.depth }
        if a.rank != b.rank { return a.rank > b.rank }
        return a.path.lexicographicallyPrecedes(b.path)
    }).first else { return nil }
    // Умножение не может идти раньше, чем стоящее слева незавершённое умножение того же уровня — порядок слева направо
    // обеспечивается сортировкой путей. Сложение не может идти, пока в той же скобке есть умножение — его ранг выше.
    if best.depth > 0 { return (best.path, "group") }
    return (best.path, best.rank == 3 ? "pow" : (best.rank == 2 ? "mul" : "add"))
}

/// Скобки вокруг одного неотрицательного числа больше не нужны.
func simplifyGroups(_ e: Expr) -> Expr {
    switch e {
    case .group(let inner):
        let s = simplifyGroups(inner)
        if isLeaf(s), !isNegativeLeaf(s) { return s }
        return .group(s)
    case .add(let a, let b): return .add(simplifyGroups(a), simplifyGroups(b))
    case .sub(let a, let b): return .sub(simplifyGroups(a), simplifyGroups(b))
    case .mul(let a, let b): return .mul(simplifyGroups(a), simplifyGroups(b))
    case .div(let a, let b): return .div(simplifyGroups(a), simplifyGroups(b))
    case .pow(let a, let b): return .pow(simplifyGroups(a), simplifyGroups(b))
    case .neg(let a): return .neg(simplifyGroups(a))
    case .abs(let a): return .abs(simplifyGroups(a))
    default: return e
    }
}

func isNegativeLeaf(_ e: Expr) -> Bool {
    if case .neg = e.unwrapped { return true }
    return false
}

// MARK: - Дроби

/// Шаги для a/b ± c/d с положительными дробями. Возвращает шаги и результат.
func fractionSumSteps(_ a: Int, _ b: Int, _ c: Int, _ d: Int, minus: Bool, requireMixed: Bool) -> ([SolutionStep], Rational) {
    let op = minus ? "−" : "+"
    var steps: [SolutionStep] = []
    let l = (try? lcm(b, d)) ?? b * d
    let k1 = l / b, k2 = l / d
    let ta = a * k1, tc = c * k2
    if b == d {
        steps.append(SolutionStep(
            minus ? "Низы одинаковые: вычитаем верхи, низ оставляем." : "Низы одинаковые: складываем верхи, низ оставляем.",
            "\(a) \(op) \(c) = \(minus ? a - c : a + c), низ \(b).",
            line: "= \(minus ? a - c : a + c)/\(b)",
            why: "Низ показывает, на сколько частей делили. Части одинаковые — считаем, сколько их всего.",
            whyNot: "Если сложить и низы, получится \(a + c)/\(2 * b) — это другое число, меньше правильного.",
            ask: "Сколько будет \(a) \(op) \(c)?", answer: "\(minus ? a - c : a + c)"))
    } else {
        let divisible = l == max(b, d)
        let detail = divisible
            ? "\(max(b, d)) делится на \(min(b, d)): общий низ — \(l)."
            : "Наименьшее число, которое делится и на \(b), и на \(d), — \(l)."
        var whyNot = "Низ \(b + d) (сумма низов) не делится на \(b) и \(d) — так нельзя."
        if (b + d) % b == 0 && (b + d) % d == 0 { whyNot = "Можно взять \(b * d), но с наименьшим общим низом числа меньше." }
        steps.append(SolutionStep(
            "Делаем низы одинаковыми.", detail,
            why: "Общий низ должен делиться на каждый низ: \(l) : \(b) = \(k1), \(l) : \(d) = \(k2).",
            whyNot: whyNot,
            ask: "Какое наименьшее число делится и на \(b), и на \(d)?", answer: "\(l)"))
        var parts: [String] = []
        var arrows: [Arrow] = []
        if k1 != 1 {
            parts.append("\(a)/\(b) = \(ta)/\(l)")
            arrows.append(Arrow("\(a)/\(b)", "\(ta)/\(l)", "×\(k1)"))
        }
        if k2 != 1 {
            parts.append("\(c)/\(d) = \(tc)/\(l)")
            arrows.append(Arrow("\(c)/\(d)", "\(tc)/\(l)", "×\(k2)"))
        }
        let kWhy = [k1 != 1 ? "\(l) : \(b) = \(k1), значит ×\(k1)" : nil,
                    k2 != 1 ? "\(l) : \(d) = \(k2), значит ×\(k2)" : nil].compactMap { $0 }.joined(separator: "; ")
        let first = k1 != 1 ? (a, b, k1, ta) : (c, d, k2, tc)
        steps.append(SolutionStep(
            "Умножаем верх и низ на одно число.", parts.joined(separator: ", ") + ".",
            line: "= \(ta)/\(l) \(op) \(tc)/\(l)",
            why: kWhy + ".",
            whyNot: "Если умножить только низ, получится \(first.0)/\(l) — это уже другая дробь.",
            check: "\(first.3)/\(l) сокращается обратно в \(first.0)/\(first.1) — дробь та же.",
            arrows: arrows,
            ask: "\(first.0)/\(first.1) = ?/\(l). Какой будет верх?", answer: "\(first.3)"))
        steps.append(SolutionStep(
            minus ? "Вычитаем верхи, низ оставляем." : "Складываем верхи, низ оставляем.",
            "\(ta) \(op) \(tc) = \(minus ? ta - tc : ta + tc).",
            line: "= \(minus ? ta - tc : ta + tc)/\(l)",
            why: "Теперь части одинаковые, их можно считать вместе.",
            ask: "Сколько будет \(ta) \(op) \(tc)?", answer: "\(minus ? ta - tc : ta + tc)"))
    }
    let top = minus ? a * k1 - c * k2 : a * k1 + c * k2
    let result = Rational.of(top, l)
    steps += reduceAndWholeSteps(top, l, requireMixed: requireMixed)
    return (steps, result)
}

/// Сокращение и выделение целой части в конце.
func reduceAndWholeSteps(_ top: Int, _ bottom: Int, requireMixed: Bool) -> [SolutionStep] {
    var steps: [SolutionStep] = []
    let g = gcd(top, bottom)
    var t = top, b = bottom
    if g > 1 && top != 0 {
        t /= g
        b /= g
        steps.append(SolutionStep(
            "Сокращаем: делим верх и низ на одно число.",
            "\(top) и \(bottom) делятся на \(g): \(top)/\(bottom) = \(t)/\(b).",
            line: "= " + (b == 1 ? "\(t)" : "\(t)/\(b)"),
            why: "Сокращение не меняет дробь: верх и низ уменьшились в одно и то же число раз.",
            check: "\(t) · \(g) = \(top), \(b) · \(g) = \(bottom).",
            arrows: [Arrow("\(top)/\(bottom)", "\(t)/\(b)", "÷\(g)")],
            ask: "На какое наибольшее число делятся \(top) и \(bottom)?", answer: "\(g)"))
    }
    if requireMixed && abs(t) > b && b != 1 {
        let w = abs(t) / b, r = abs(t) % b
        steps.append(SolutionStep(
            "Верх больше низа — выделяем целую часть.",
            "\(abs(t)) : \(b) = \(w) (ост. \(r)), значит \(abs(t))/\(b) = \(w) \(r)/\(b).",
            line: "= \(t < 0 ? "−" : "")\(w) \(r)/\(b)",
            why: "Каждые \(b) частей из \(b) — это одна целая. Отнимаем низ, пока верх больше низа.",
            check: "\(w) · \(b) + \(r) = \(abs(t)).",
            ask: "Сколько целых в \(abs(t))/\(b)?", answer: "\(w)"))
    }
    return steps
}

/// Ответ-число в нужной форме.
func numberAnswer(_ r: Rational, mixed: Bool, decimal: Bool = false) -> Statement {
    st(show(r, mixed: mixed, decimal: decimal))
}
