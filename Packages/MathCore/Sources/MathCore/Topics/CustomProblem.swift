/// «Свой пример»: ученик вводит пример из домашки, мы определяем тему, считаем ответ и шаги.
public enum CustomProblem {
    public enum Failure: Error, Equatable, Sendable {
        case cannotRead
        case unsupported(String)

        public var message: String {
            switch self {
            case .cannotRead: return "Не понял запись. Проверь скобки и знаки."
            case .unsupported(let why): return "Такой пример я пока не поддерживаю: \(why)."
            }
        }
    }

    public static func make(_ input: String) -> Result<Problem, Failure> {
        // «3/4 − 2/3 = ?» — вопрос в конце отбрасываем.
        var text = String(input.filter { $0 != "?" })
        while let last = text.last, last == " " || last == "=" { text.removeLast() }
        guard !text.isEmpty, let statement = try? Parser.statement(text) else { return .failure(.cannotRead) }
        switch statement {
        case .expression(let e), .continuation(let e):
            return expression(e)
        case .relation(let l, let r, let rr):
            return equation(statement, l, r, rr)
        case .system(let parts):
            return system(statement, parts)
        default:
            return .failure(.unsupported("это уже похоже на ответ, а не на задание"))
        }
    }

    static func expression(_ e: Expr) -> Result<Problem, Failure> {
        guard let nf = try? e.normalForm() else { return .failure(.unsupported("выражение не вычисляется (например, деление на ноль или корень из отрицательного числа)")) }
        let display = e.text
        if !e.hasVariables {
            guard let value = nf.constant else { return .failure(.unsupported("не получилось вычислить")) }
            let topic = numericTopic(e)
            let hasDecimals = e.allNodes.contains { if case .decimal = $0 { return true }; return false }
            guard let r = value.rational else {
                // Число с корнями: ответ — упрощённое выражение.
                return .success(Problem(topicID: topic, prompt: "Вычисли", statement: .expression(e), display: display,
                                        expected: .expression(polyExpr(value)), spec: AnswerSpec(.number),
                                        steps: [SolutionStep("Упрощаем корни и приводим подобные.", "Ответ: \(polyText(value)).",
                                                             line: "= " + polyText(value))]))
            }
            let mixed = topicRequiresMixed(topic)
            let answer = st(show(r, mixed: mixed, decimal: hasDecimals && r.isTerminatingDecimal))
            let spec = AnswerSpec(hasDecimals ? .decimal : .number, requireMixed: mixed)
            var steps = arithmeticSteps(e, decimal: hasDecimals)
            if let last = steps.last, !r.isInteger, mixed, abs(r.num) > r.den {
                let shown = show(r, mixed: true)
                if last.line != "= " + shown {
                    steps += reduceAndWholeSteps(r.num, r.den, requireMixed: true).suffix(1)
                }
            }
            return .success(Problem(topicID: topic, prompt: "Вычисли", statement: .expression(e), display: display,
                                    expected: answer, spec: spec, steps: steps))
        }
        // С переменными: упростить.
        if let p = nf.polynomial {
            let text = polyText(p)
            let topic = e.allNodes.contains { if case .pow(.group, _) = $0 { return true }; return false } ? "g7.formulas" : "g7.polyAdd"
            return .success(Problem(topicID: topic, prompt: "Упрости", statement: .expression(e), display: display,
                                    expected: st(text), spec: AnswerSpec(.polynomial),
                                    steps: [SolutionStep("Раскрываем скобки и приводим подобные.", "Получается \(text).", line: "= " + text)]))
        }
        let text = "{\(polyText(nf.num))}/{\(polyText(nf.den))}"
        return .success(Problem(topicID: "g8.ratOps", prompt: "Упрости", statement: .expression(e), display: display,
                                expected: st(text), spec: AnswerSpec(.rationalFraction),
                                steps: [SolutionStep("Приводим к общему знаменателю и сокращаем.", "Получается \(st(text).text).",
                                                     line: "= " + text)]))
    }

    static func equation(_ s: Statement, _ l: Expr, _ r: Relation, _ rr: Expr) -> Result<Problem, Failure> {
        let vars = l.variables.union(rr.variables)
        guard vars.count == 1, let v = vars.first else {
            return .failure(.unsupported(vars.isEmpty ? "в записи нет неизвестного" : "в одном уравнении несколько неизвестных — нужна система"))
        }
        let solution: SolutionSet
        do { solution = try Solver.solve(s) } catch MathError.unsupported(let why) {
            return .failure(.unsupported(why))
        } catch { return .failure(.unsupported("не получилось решить")) }
        let f = try? l.normalForm().subtracting(rr.normalForm())
        let degree = f?.num.degree ?? 1
        let rational = !(f?.isPolynomial ?? true)
        if r.isInequality {
            guard let answer = intervalStatement(solution) else { return .failure(.unsupported("ответ не записывается промежутком")) }
            return .success(Problem(topicID: "g8.ineq", prompt: "Реши неравенство", statement: s, display: s.text,
                                    expected: answer, spec: AnswerSpec(.interval),
                                    steps: [SolutionStep("Переносим всё с x в одну часть, числа — в другую, делим на коэффициент.",
                                                         "При делении на отрицательное число знак меняется.", line: answer.text)]))
        }
        let topic = rational ? "g8.ratEq" : (degree >= 2 ? "g8.quadratic" : (s.text.contains("(") ? "g7.linear" : "g6.eq"))
        let answer = rootsStatement(solution, v)
        return .success(Problem(topicID: topic, prompt: "Реши уравнение", statement: s, display: s.text,
                                expected: answer, spec: AnswerSpec(.roots),
                                steps: [SolutionStep(degree >= 2 ? "Приводим к виду ax² + bx + c = 0 и считаем дискриминант."
                                                                 : "Переносим x влево, числа вправо, делим на коэффициент.",
                                                     rational ? "Не забываем про ОДЗ: знаменатель не равен нулю." : "Проверяем подстановкой.",
                                                     line: answer.text)]))
    }

    static func system(_ s: Statement, _ parts: [Statement]) -> Result<Problem, Failure> {
        guard let solution = try? Solver.solve(s) else { return .failure(.unsupported("такую систему решать пока не умею")) }
        switch solution {
        case .point(let p):
            let text = p.keys.sorted().map { "\($0) = \(show(p[$0]!))" }.joined(separator: "; ")
            return .success(Problem(topicID: "g7.systems", prompt: "Реши систему", statement: s, display: s.text,
                                    expected: st(text), spec: AnswerSpec(.point),
                                    steps: [SolutionStep("Выражаем одну переменную и подставляем в другое уравнение.",
                                                         "Ответ: \(text).", line: text)]))
        case .intervals, .all, .values, .none:
            guard let answer = intervalStatement(solution) else { return .failure(.unsupported("ответ не записывается промежутком")) }
            return .success(Problem(topicID: "g8.ineqSys", prompt: "Реши систему неравенств", statement: s, display: s.text,
                                    expected: answer, spec: AnswerSpec(.interval),
                                    steps: [SolutionStep("Решаем каждое неравенство и берём пересечение.", "Ответ: \(answer.text).",
                                                         line: answer.text)]))
        case .infinite:
            return .failure(.unsupported("у системы бесконечно много решений — такой ответ я пока не проверяю"))
        }
    }

    static func intervalStatement(_ s: SolutionSet) -> Statement? {
        switch s.normalized {
        case .none: return .noSolution
        case .all(let except) where except.isEmpty: return .anyNumber
        case .intervals(let set):
            return .intervals(set.parts.map {
                IntervalLiteral(low: $0.low.map { Expr.number($0) }, lowClosed: $0.lowClosed,
                                high: $0.high.map { Expr.number($0) }, highClosed: $0.highClosed)
            })
        default: return nil
        }
    }

    static func rootsStatement(_ s: SolutionSet, _ v: String) -> Statement {
        switch s.normalized {
        case .values(let vals):
            let rels = vals.map { Statement.relation(.variable(v), .eq, polyExpr($0)) }
            return rels.count == 1 ? rels[0] : .either(rels)
        case .all: return .anyNumber
        default: return .noSolution
        }
    }

    static func polyExpr(_ p: Poly) -> Expr {
        (try? Parser.expression(polyText(p))) ?? .integer(0)
    }

    /// Тема для числового выражения — по тому, из чего оно состоит.
    static func numericTopic(_ e: Expr) -> String {
        let nodes = e.allNodes
        func has(_ test: (Expr) -> Bool) -> Bool { nodes.contains(where: test) }
        if has({ if case .sqrt = $0 { return true }; return false }) { return "g8.sqrt" }
        if has({ if case .pow(_, .neg) = $0 { return true }; return false }) { return "g8.intPow" }
        if has({ if case .percent = $0 { return true }; return false }) { return "g5.percent" }
        if has({ if case .abs = $0 { return true }; return false }) { return "g6.abs" }
        let fractions = nodes.compactMap(Mutations.intFraction)
        let hasMixed = has({ if case .mixed = $0 { return true }; return false })
        if has({ if case .decimal = $0 { return true }; return false }) {
            return has({ if case .mul = $0 { return true }; if case .div = $0 { return true }; return false }) ? "g5.decMul" : "g5.decAdd"
        }
        if !fractions.isEmpty || hasMixed {
            if has({ if case .neg = $0 { return true }; return false }) { return "g6.rational" }
            if hasMixed { return "g6.mixed" }
            if has({ if case .div = $0 { return true }; return false }) { return "g6.div" }
            if has({ if case .mul = $0 { return true }; return false }) { return "g6.mul" }
            let dens = Set(fractions.map(\.1))
            if fractions.count == 1 { return fractions[0].0 > fractions[0].1 ? "g5.whole" : "g6.reduce" }
            if dens.count == 1 { return has({ if case .sub = $0 { return true }; return false }) ? "g5.sameSub" : "g5.sameAdd" }
            if has({ if case .sub = $0 { return true }; return false }) { return "g6.sub" }
            let sorted = dens.sorted()
            return sorted.last! % sorted.first! == 0 ? "g6.addDiv" : "g6.addGen"
        }
        if has({ if case .neg = $0 { return true }; return false }) { return "g6.negAdd" }
        if has({ if case .pow = $0 { return true }; return false }) { return "g5.powers" }
        if case .mul(.integer(let a), .integer(let b)) = e.unwrapped, a <= 10, b <= 10 { return "g5.table" }
        return "g5.order"
    }

    static func topicRequiresMixed(_ id: String) -> Bool {
        id.hasPrefix("g5.") || ["g6.addDiv", "g6.addGen", "g6.sub", "g6.mul", "g6.div", "g6.mixed"].contains(id)
    }
}
