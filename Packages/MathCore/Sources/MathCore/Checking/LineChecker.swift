/// Проверка тетради «Решаю сам»: каждая строка сравнивается с предыдущей (по шагам)
/// или с условием (быстрый режим). Если строку нельзя проверить надёжно — так и говорим.
public enum LineChecker {
    public enum Mode: Sendable { case steps, quick }

    public static func check(problem: Statement, lines: [String], spec: AnswerSpec, mode: Mode = .steps) -> [LineStatus] {
        switch problem {
        case .relation, .system:
            return checkEquation(problem: problem, lines: lines, spec: spec)
        default:
            return checkComputation(problem: problem, lines: lines, spec: spec, mode: mode)
        }
    }

    // MARK: Вычисления и упрощения

    static func checkComputation(problem: Statement, lines: [String], spec: AnswerSpec, mode: Mode) -> [LineStatus] {
        guard let start = problem.expressions.first else {
            return lines.map { _ in .unverifiable("непонятное условие") }
        }
        var previous = start
        var result: [LineStatus] = []
        for (index, text) in lines.enumerated() {
            guard let st = try? Parser.statement(text) else {
                result.append(.unverifiable("не понял запись строки"))
                continue
            }
            let parts: [Expr]
            switch st {
            case .continuation(let e), .expression(let e): parts = [e]
            case .chain(let es): parts = es
            case .relation(.variable(let v), .eq, let b) where !problem.variables.contains(v):
                // «y = 81» — просто подпись результата.
                parts = [b]
            case .relation(let a, .eq, let b): parts = [a, b]
            default:
                result.append(.unverifiable("здесь ожидается выражение"))
                continue
            }
            var status = LineStatus.correct
            for e in parts {
                let base = mode == .quick ? start : previous
                switch equivalent(base, e) {
                case true?:
                    previous = e
                case false?:
                    if status.isCorrect { status = .wrong(lineMistake(from: base, to: e)) }
                    previous = e
                case nil:
                    if status.isCorrect { status = .unverifiable("не получилось сравнить с предыдущей строкой") }
                }
            }
            if case .correct = status, index == lines.count - 1, let issue = Simplest.issue(.expression(previous), spec: spec) {
                status = .correctNotSimplest(issue)
            }
            result.append(status)
        }
        return result
    }

    /// Какая ошибка превращает prev в e.
    static func lineMistake(from prev: Expr, to e: Expr) -> MistakeReport? {
        if let m = mutationMatch(from: prev, to: e) { return m }
        if let m = commonDenominatorMistake(from: prev, to: e) { return m }
        if let v = try? prev.rationalValue(), let u = try? e.rationalValue(),
           let m = ValueMistakes.detect(correct: v, answer: u, problem: prev) {
            return m
        }
        return nil
    }

    /// Ищем «неправильное» преобразование, которое даёт именно e. Общие ошибки (знак) — в последнюю очередь.
    static func mutationMatch(from prev: Expr, to e: Expr) -> MistakeReport? {
        let target = try? e.normalForm()
        var generic: MistakeReport?
        for (report, candidate) in Mutations.candidates(of: prev) {
            guard let c = try? candidate.normalForm(), let t = target, c.equals(t) else { continue }
            // Неправильное преобразование, которое случайно даёт верный ответ, — не ошибка.
            if let p = try? prev.normalForm(), p.equals(c) { continue }
            if report.kind == .signError {
                generic = generic ?? report
                continue
            }
            return report
        }
        return generic
    }

    /// Взял общий низ, который не делится на оба низа.
    static func commonDenominatorMistake(from prev: Expr, to e: Expr) -> MistakeReport? {
        let before = Set(prev.allNodes.compactMap(Mutations.intFraction).map(\.1))
        let after = Set(e.allNodes.compactMap(Mutations.intFraction).map(\.1))
        guard before.count >= 2, !after.isEmpty, after != before else { return nil }
        for d in after where before.contains(where: { d % $0 != 0 }) && !before.contains(d) {
            let list = before.sorted().map(String.init).joined(separator: " и ")
            return MistakeReport(.wrongCommonDenominator, detail: "\(d) не делится на \(list).")
        }
        return nil
    }

    // MARK: Уравнения, неравенства, системы

    static func checkEquation(problem: Statement, lines: [String], spec: AnswerSpec) -> [LineStatus] {
        guard let target = try? Solver.solve(problem) else {
            return lines.map { _ in .unverifiable("это уравнение я пока проверить не могу") }
        }
        let exclusions = (try? Solver.domainExclusions(problem.expressions, problem.variables.first.map(baseName) ?? "x")) ?? []
        var previous = problem
        var result: [LineStatus] = []
        for (index, text) in lines.enumerated() {
            guard let st = try? Parser.statement(text) else {
                result.append(.unverifiable("не понял запись строки"))
                continue
            }
            if let aux = auxiliary(st, problem: problem) {
                result.append(aux)
                continue
            }
            var status: LineStatus
            if case .point(let p) = target, let s = pointStatus(st, point: p) {
                status = s
            } else if case .system(let parts) = problem, case .relation = st, let got = try? Solver.solve(st),
                      parts.contains(where: { (try? Solver.solve($0)) == got }) {
                // В системе неравенств строка может решать одно из неравенств.
                status = .correct
            } else if let got = try? Solver.solve(st) {
                if got == target {
                    status = .correct
                } else if consequenceWithExtraneous(got, target, exclusions) {
                    // Умножили на знаменатель — появились лишние корни, это ещё не ошибка, их отсеют.
                    status = .correct
                } else {
                    status = .wrong(equationMistake(previous: previous, line: st, got: got, target: target, problem: problem))
                }
            } else {
                status = .unverifiable("такую строку проверить не могу")
            }
            if case .correct = status, index == lines.count - 1, let issue = Simplest.issue(st, spec: spec) {
                status = .correctNotSimplest(issue)
            }
            if status.isCorrect { previous = st }
            result.append(status)
        }
        return result
    }

    /// Вспомогательные вычисления: «D = 25 − 24 = 1». Дискриминант сверяем, прочее — честно не проверяем.
    static func auxiliary(_ st: Statement, problem: Statement) -> LineStatus? {
        var name: String?
        var values: [Expr] = []
        switch st {
        case .chain(let es):
            if case .variable(let v) = es[0].unwrapped { name = v; values = Array(es.dropFirst()) }
        case .relation(.variable(let v), .eq, let e):
            name = v
            values = [e]
        default: return nil
        }
        guard let v = name, !problem.variables.map(baseName).contains(baseName(v)) else { return nil }
        guard values.allSatisfy({ !$0.hasVariables }) else { return .unverifiable("вспомогательная запись") }
        for (a, b) in zip(values, values.dropFirst()) where equivalent(a, b) != true {
            return .wrong(lineMistake(from: a, to: b))
        }
        if v == "D", case .relation(let l, .eq, let r) = problem, let last = values.last,
           let f = try? l.normalForm().subtracting(r.normalForm()), let p = f.polynomial,
           let x = p.variables.first, let c = p.coefficients(in: x), c.count == 3,
           let d = try? c[1].multiplying(c[1]).subtracting(Rational(4).multiplying(c[2]).multiplying(c[0])),
           let got = try? last.rationalValue() {
            if got == d { return .correct }
            return .wrong(MistakeReport(.arithmetic, detail: "D = b² − 4ac. Пересчитай."))
        }
        return .correct
    }

    /// Строки в системе: уравнение с двумя переменными должно выполняться в точке решения.
    static func pointStatus(_ st: Statement, point: [String: Rational]) -> LineStatus? {
        guard case .relation(let l, .eq, let r) = st else { return nil }
        let vars = l.variables.union(r.variables).map(baseName)
        // Уравнение с одной переменной после подстановки: его корень — координата решения.
        if vars.count == 1, let v = vars.first, let x = point[v] {
            guard let s = try? Solver.solve(st) else { return .unverifiable("не получилось решить строку") }
            return s == .values([Poly(constant: x)]) ? .correct : .wrong(nil)
        }
        guard vars.count == 2 else { return nil }
        let values = point.reduce(into: [String: Rational]()) { $0[$1.key] = $1.value }
        guard let a = try? l.renamingVariables(baseName).substituting(values).rationalValue(),
              let b = try? r.renamingVariables(baseName).substituting(values).rationalValue() else {
            return .unverifiable("не получилось подставить решение")
        }
        return a == b ? .correct : .wrong(nil)
    }

    static func consequenceWithExtraneous(_ got: SolutionSet, _ target: SolutionSet, _ exclusions: [Poly]) -> Bool {
        guard let g = got.values, let t = target.values ?? (target == .none ? [] : nil) else { return false }
        let extra = Set(g).subtracting(t)
        return Set(t).isSubset(of: Set(g)) && !extra.isEmpty && extra.isSubset(of: Set(exclusions))
    }

    static func equationMistake(previous: Statement, line: Statement, got: SolutionSet, target: SolutionSet,
                                problem: Statement) -> MistakeReport? {
        if let m = setMistake(got: got, target: target, problem: problem), m.kind != .arithmetic { return m }
        guard case .relation(let l, let rel, let r) = previous else { return nil }
        // Перенос без смены знака.
        for (side, other, onLeft) in [(l, r, true), (r, l, false)] {
            let terms = side.unwrapped.terms
            guard terms.count >= 2 else { continue }
            for (i, t) in terms.enumerated() {
                let rest = Mutations.sum(terms.enumerated().filter { $0.offset != i }.map(\.element))
                let moved = Expr.add(.group(other), t)
                let candidate: Statement = onLeft ? .relation(rest, rel, moved) : .relation(moved, rel, rest)
                if let s = try? Solver.solve(candidate), s == got {
                    return MistakeReport(.transferWithoutSignChange,
                                         detail: "Перенёс «\(t.text)» без смены знака.")
                }
            }
        }
        // Не сменил знак неравенства.
        if rel.isInequality, let s = try? Solver.solve(.relation(l, rel.flipped, r)), s == got {
            return MistakeReport(.inequalityNotFlipped)
        }
        // Ошибки внутри частей.
        for (candidate, isLeft) in Mutations.candidates(of: l).map({ ($0, true) }) + Mutations.candidates(of: r).map({ ($0, false) }) {
            let (report, e) = candidate
            let st: Statement = isLeft ? .relation(e, rel, r) : .relation(l, rel, e)
            if let s = try? Solver.solve(st), s == got, s != target { return report }
        }
        return nil
    }

    /// Ошибки в итоговом наборе корней или промежутке.
    static func setMistake(got: SolutionSet, target: SolutionSet, problem: Statement) -> MistakeReport? {
        if let g = got.values, let t = target.values {
            let neg = t.map { $0.negated() }
            if !t.isEmpty, sameSet(g, neg), !sameSet(g, t) { return MistakeReport(.rootsSignSwapped) }
            let gs = Set(g), ts = Set(t)
            if ts.isSubset(of: gs), gs != ts {
                let exclusions = (try? Solver.domainExclusions(problem.expressions,
                                                               problem.variables.first.map(baseName) ?? "x")) ?? []
                if gs.subtracting(ts).isSubset(of: Set(exclusions)) {
                    return MistakeReport(.extraneousRoot, detail: "При этом значении знаменатель равен нулю.")
                }
            }
            if !gs.isEmpty, gs.isSubset(of: ts), gs != ts { return MistakeReport(.lostRoot) }
        }
        if target.values != nil, got == .none { return MistakeReport(.lostRoot) }
        if case .intervals(let a) = got.normalized, case .intervals(let b) = target.normalized,
           a.parts.count == b.parts.count,
           zip(a.parts, b.parts).allSatisfy({ $0.low == $1.low && $0.high == $1.high }) {
            return MistakeReport(.intervalBracket)
        }
        // Знак неравенства: ответ с другой стороны от той же точки.
        if case .intervals(let a) = got.normalized, case .intervals(let b) = target.normalized,
           a.parts.count == 1, b.parts.count == 1 {
            let x = a.parts[0], y = b.parts[0]
            let pointsA = [x.low, x.high].compactMap { $0 }, pointsB = [y.low, y.high].compactMap { $0 }
            if pointsA == pointsB, pointsA.count == 1 { return MistakeReport(.inequalityNotFlipped) }
        }
        return MistakeReport(.arithmetic)
    }
}
