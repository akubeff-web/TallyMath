// Темы 7 класса.

enum Grade7 {
    static let topics: [TopicDef] = [
        linear, powerProps, monomials, polyAddSub, polyMul, shortFormulas, factoring, linearFunction, systems,
    ]

    /// «3x + −2» → «3x − 2», «1x» → «x» — аккуратная запись многочлена через разбор и печать.
    static func poly(_ text: String) -> String {
        guard let nf = try? ex(text).normalForm().polynomial else { return text }
        return polyText(nf)
    }

    static let linear = TopicDef(
        "g7.linear", .seven, section: "Линейные уравнения", title: "Линейные уравнения",
        rule: ["Раскрываем скобки.", "Иксы переносим влево, числа вправо — со сменой знака.",
               "Делим на коэффициент при x. Если он 0 — корней нет или их бесконечно много."]
    ) { r, ctx in
        let x = r.signed(1...(ctx.easy ? 5 : 9)), a = r.int(2...5), b = r.signed(1...6), c = r.int(1...(a + 3))
        let cc = c == a ? c + 1 : c
        let d = a * (x + b) - cc * x
        let left = "\(a)(x \(b < 0 ? "−" : "+") \(abs(b)))"
        let right = "\(cc)x \(d < 0 ? "−" : "+") \(abs(d))"
        let text = "\(left) = \(right)"
        let coef = a - cc, rhs = d - a * b
        return Problem(
            topicID: "g7.linear", prompt: "Реши уравнение", statement: st(text), display: text,
            expected: st("x = \(x)"), spec: AnswerSpec(.roots),
            steps: [
                SolutionStep("Раскрываем скобки.", "\(a)(x \(b < 0 ? "−" : "+") \(abs(b))) = \(poly("\(a)x + \(a * b)")).",
                             line: "\(poly("\(a)x + \(a * b)")) = \(right)", ask: "Сколько будет \(a) · \(b)?".replacingMinus,
                             answer: "\(a * b)".replacingMinus),
                SolutionStep("Иксы влево, числа вправо.", "Переносим со сменой знака.",
                             line: "\(poly("\(a)x - \(cc)x")) = \(poly("\(d) - \(a * b)"))",
                             whyNot: "Без смены знака при переносе получится другое уравнение."),
                SolutionStep("Делим на коэффициент.", "x = \(rhs) : \(coef)".replacingMinus + " = \(x)".replacingMinus + ".",
                             line: "x = \(x)".replacingMinus, check: "Подставь x = \(x) в обе части — значения совпадут.".replacingMinus,
                             ask: "Сколько будет \(rhs) : \(coef)?".replacingMinus, answer: "\(x)".replacingMinus),
            ])
    }

    static let powerProps = TopicDef(
        "g7.powers", .seven, section: "Степени", title: "Свойства степени",
        rule: ["aᵐ · aⁿ = aᵐ⁺ⁿ — показатели складываем.", "aᵐ : aⁿ = aᵐ⁻ⁿ — вычитаем.", "(aᵐ)ⁿ = aᵐⁿ — умножаем.",
               "(ab)ⁿ = aⁿbⁿ."]
    ) { r, ctx in
        let m = r.int(2...6), n = r.int(2...4)
        let kind = r.int(0...2)
        let (text, result, rule, detail): (String, String, String, String)
        switch kind {
        case 0: (text, result, rule, detail) = ("a^\(m) · a^\(n)", "a^\(m + n)", "Основания одинаковые — показатели складываем.", "\(m) + \(n) = \(m + n)")
        case 1: (text, result, rule, detail) = ("a^\(m + n) : a^\(n)", "a^\(m)", "При делении показатели вычитаем.", "\(m + n) − \(n) = \(m)")
        default: (text, result, rule, detail) = ("(a^\(m))^\(n)", "a^\(m * n)", "Степень в степени — показатели умножаем.", "\(m) · \(n) = \(m * n)")
        }
        let shown = ex(text).text, res = ex(result).text
        return Problem(
            topicID: "g7.powers", prompt: "Упрости", statement: st(shown), display: shown,
            expected: st(res), spec: AnswerSpec(.polynomial),
            steps: [SolutionStep(rule, detail + ".", line: "= " + res,
                                 why: kind == 0 ? "aᵐ — это m множителей a, aⁿ — ещё n. Всего m + n." : nil,
                                 whyNot: kind == 2 ? "Сложить показатели — частая ошибка: (aᵐ)ⁿ — это n раз по m множителей." : nil,
                                 ask: "Какой будет показатель?", answer: res)])
    }

    static let monomials = TopicDef(
        "g7.monomials", .seven, section: "Одночлены и многочлены", title: "Одночлены",
        rule: ["Коэффициенты перемножаем.", "Степени с одинаковыми буквами — по свойствам степени.",
               "Одночлен в стандартном виде: число впереди, каждая буква один раз."]
    ) { r, ctx in
        let a = r.signed(2...5), b = r.signed(2...5), p = r.int(1...3), q = r.int(1...3), s = r.int(1...2), t = r.int(1...3)
        let text = "(\(a)x^\(p)y^\(s)) · (\(b)x^\(q)y^\(t))".replacingMinus
        let e = ex(text)
        let res = poly("\(a * b)x^\(p + q)y^\(s + t)")
        return Problem(
            topicID: "g7.monomials", prompt: "Упрости", statement: .expression(e), display: e.text,
            expected: st(res), spec: AnswerSpec(.polynomial),
            steps: [
                SolutionStep("Перемножаем коэффициенты.", "\(a) · \(b) = \(a * b)".replacingMinus + ".",
                             ask: "Сколько будет \(a) · \(b)?".replacingMinus, answer: "\(a * b)".replacingMinus),
                SolutionStep("Складываем показатели одинаковых букв.", "x: \(p) + \(q) = \(p + q); y: \(s) + \(t) = \(s + t).",
                             line: "= " + res),
            ])
    }

    static let polyAddSub = TopicDef(
        "g7.polyAdd", .seven, section: "Одночлены и многочлены", title: "Сложение и вычитание многочленов",
        rule: ["Раскрываем скобки (минус перед скобкой меняет знаки).", "Приводим подобные слагаемые."]
    ) { r, ctx in
        let a = r.int(1...5), b = r.signed(1...7), c = r.signed(1...9), d = r.int(1...5), e1 = r.signed(1...7), f = r.signed(1...9)
        let first = poly("\(a)x^2 + \(b)x + \(c)"), second = poly("\(d)x^2 + \(e1)x + \(f)")
        let text = "(\(first)) − (\(second))"
        let res = poly("\(a - d)x^2 + \(b - e1)x + \(c - f)")
        return Problem(
            topicID: "g7.polyAdd", prompt: "Упрости", statement: st(text), display: text,
            expected: st(res), spec: AnswerSpec(.polynomial),
            steps: [
                SolutionStep("Раскрываем скобки: минус меняет все знаки во второй скобке.", "−(\(second)) = \(poly("-(\(second))")).",
                             line: "= \(poly("\(a)x^2 + \(b)x + \(c)")) + \(poly("-(\(second))"))".replacingOccurrencesOfPlusMinus,
                             whyNot: "Сменить знак только у первого слагаемого — частая ошибка."),
                SolutionStep("Приводим подобные.", "x²: \(a) − \(d); x: \(b) − (\(e1)); числа: \(c) − (\(f)).".replacingMinus,
                             line: "= " + res),
            ])
    }

    static let polyMul = TopicDef(
        "g7.polyMul", .seven, section: "Одночлены и многочлены", title: "Умножение многочленов",
        rule: ["Каждое слагаемое первой скобки умножаем на каждое слагаемое второй.", "Потом приводим подобные."]
    ) { r, ctx in
        let a = r.signed(1...7), b = r.signed(1...7)
        let text = "(x \(a < 0 ? "−" : "+") \(abs(a)))(x \(b < 0 ? "−" : "+") \(abs(b)))"
        let full = "x² \(b < 0 ? "−" : "+") \(abs(b))x \(a < 0 ? "−" : "+") \(abs(a))x \(a * b < 0 ? "−" : "+") \(abs(a * b))"
        let res = poly("x^2 + \(a + b)x + \(a * b)")
        return Problem(
            topicID: "g7.polyMul", prompt: "Раскрой скобки", statement: st(text), display: text,
            expected: st(res), spec: AnswerSpec(.polynomial),
            steps: [
                SolutionStep("Каждое на каждое.", "x · x, x · (\(b)), \(a) · x, \(a) · (\(b)).".replacingMinus, line: "= " + full,
                             why: "Получается 2 · 2 = 4 произведения.",
                             ask: "Сколько будет \(a) · \(b)?".replacingMinus, answer: "\(a * b)".replacingMinus),
                SolutionStep("Приводим подобные.", "\(b)x + \(a)x = \(a + b)x".replacingMinus + ".", line: "= " + res),
            ])
    }

    static let shortFormulas = TopicDef(
        "g7.formulas", .seven, section: "Формулы сокращённого умножения", title: "Формулы сокращённого умножения",
        rule: ["(a + b)² = a² + 2ab + b².", "(a − b)² = a² − 2ab + b².", "(a − b)(a + b) = a² − b²."]
    ) { r, ctx in
        let k = r.int(1...(ctx.easy ? 1 : 3)), b = r.int(1...9)
        let a = k == 1 ? "x" : "\(k)x"
        switch r.int(0...2) {
        case 0:
            let text = "(\(a) + \(b))²", res = poly("\(k * k)x^2 + \(2 * k * b)x + \(b * b)")
            return Problem(topicID: "g7.formulas", prompt: "Раскрой скобки", statement: st(text), display: text,
                           expected: st(res), spec: AnswerSpec(.polynomial),
                           steps: [SolutionStep("Квадрат суммы: a² + 2ab + b².", "a = \(a), b = \(b): \(a)² + 2 · \(a) · \(b) + \(b)².",
                                                line: "= " + res, whyNot: "Без удвоенного произведения 2ab ответ неверный: (a + b)² ≠ a² + b².",
                                                check: "Проверь при x = 1: (\(k) + \(b))² = \((k + b) * (k + b)).",
                                                ask: "Чему равно удвоенное произведение 2 · \(a) · \(b)?", answer: poly("\(2 * k * b)x"))])
        case 1:
            let text = "(\(a) − \(b))²", res = poly("\(k * k)x^2 - \(2 * k * b)x + \(b * b)")
            return Problem(topicID: "g7.formulas", prompt: "Раскрой скобки", statement: st(text), display: text,
                           expected: st(res), spec: AnswerSpec(.polynomial),
                           steps: [SolutionStep("Квадрат разности: a² − 2ab + b².", "a = \(a), b = \(b).", line: "= " + res,
                                                whyNot: "Последнее слагаемое b² всегда с плюсом.",
                                                ask: "Чему равно 2 · \(a) · \(b)?", answer: poly("\(2 * k * b)x"))])
        default:
            let text = "(\(a) − \(b))(\(a) + \(b))", res = poly("\(k * k)x^2 - \(b * b)")
            return Problem(topicID: "g7.formulas", prompt: "Раскрой скобки", statement: st(text), display: text,
                           expected: st(res), spec: AnswerSpec(.polynomial),
                           steps: [SolutionStep("Разность квадратов: a² − b².", "\(a)² − \(b)².", line: "= " + res,
                                                why: "Средние слагаемые +ab и −ab взаимно уничтожаются.",
                                                ask: "Чему равно \(b)²?", answer: "\(b * b)")])
        }
    }

    static let factoring = TopicDef(
        "g7.factor", .seven, section: "Разложение на множители", title: "Разложение на множители",
        rule: ["Сначала выносим общий множитель за скобки.", "Потом ищем формулу: a² − b² = (a − b)(a + b), a² ± 2ab + b² = (a ± b)².",
               "Проверка: раскрой скобки обратно — должно получиться исходное выражение."]
    ) { r, ctx in
        switch r.int(0...2) {
        case 0:
            let k = r.int(2...6), a = r.int(1...5)
            var b = r.int(1...9)
            while gcd(a, b) != 1 { b += 1 }
            let text = poly("\(k * a)x^2 + \(k * b)x")
            let res = "\(k)x(\(poly("\(a)x + \(b)")))"
            return Problem(topicID: "g7.factor", prompt: "Разложи на множители", statement: st(text), display: text,
                           expected: st(res), spec: AnswerSpec(.factored),
                           steps: [SolutionStep("Выносим общий множитель.", "У обоих слагаемых есть \(k) и x.", line: "= " + res,
                                                check: "Раскрой: \(k)x · \(poly("\(a)x")) + \(k)x · \(b) = \(text).",
                                                ask: "Какой общий множитель у \(text)?", answer: "\(k)x")])
        case 1:
            let b = r.int(1...9)
            let text = poly("x^2 - \(b * b)"), res = "(x − \(b))(x + \(b))"
            return Problem(topicID: "g7.factor", prompt: "Разложи на множители", statement: st(text), display: text,
                           expected: st(res), spec: AnswerSpec(.factored),
                           steps: [SolutionStep("Разность квадратов.", "\(b * b) = \(b)², значит x² − \(b)² = (x − \(b))(x + \(b)).",
                                                line: "= " + res, check: "(x − \(b))(x + \(b)) = x² − \(b * b).",
                                                ask: "Квадратом какого числа является \(b * b)?", answer: "\(b)")])
        default:
            let b = r.int(1...9)
            let text = poly("x^2 + \(2 * b)x + \(b * b)"), res = "(x + \(b))²"
            return Problem(topicID: "g7.factor", prompt: "Разложи на множители", statement: st(text), display: text,
                           expected: st(res), spec: AnswerSpec(.factored),
                           steps: [SolutionStep("Полный квадрат.", "\(b * b) = \(b)², \(2 * b)x = 2 · x · \(b).", line: "= " + res,
                                                why: "Это a² + 2ab + b² при a = x, b = \(b).",
                                                ask: "Какое число в скобке: (x + ?)²", answer: "\(b)")])
        }
    }

    static let linearFunction = TopicDef(
        "g7.linfunc", .seven, section: "Линейная функция", title: "Линейная функция",
        rule: ["y = kx + b: чтобы найти y, подставляем x.", "Прямая через две точки: k = (y₂ − y₁) : (x₂ − x₁), потом b = y₁ − k·x₁."]
    ) { r, ctx in
        let k = r.signed(1...5), b = r.signed(0...9)
        if ctx.easy || r.bool() {
            let x0 = r.signed(1...6)
            let y = k * x0 + b
            let f = poly("\(k)x + \(b)")
            return Problem(topicID: "g7.linfunc", prompt: "Найди y при x = \(x0)".replacingMinus, statement: st(f.replacingX(with: x0)), display: "y = \(f), x = \(x0)".replacingMinus,
                           expected: st("\(y)"), spec: AnswerSpec(.number),
                           steps: [SolutionStep("Подставляем x в формулу.", "y = \(k) · \(x0) + \(b)".replacingMinus + ".",
                                                line: "y = \(y)".replacingMinus, ask: "Сколько будет \(k) · \(x0)?".replacingMinus,
                                                answer: "\(k * x0)".replacingMinus)])
        }
        let x1 = r.int(0...3), x2 = x1 + r.int(1...3)
        let y1 = k * x1 + b, y2 = k * x2 + b
        let res = poly("\(k)x + \(b)")
        return Problem(
            topicID: "g7.linfunc", prompt: "Задай прямую y = kx + b через точки (\(x1); \(y1)) и (\(x2); \(y2))".replacingMinus,
            statement: nil, display: "(\(x1); \(y1)), (\(x2); \(y2))".replacingMinus,
            expected: st("y = \(res)"), spec: AnswerSpec(.polynomial),
            steps: [
                SolutionStep("Находим k.", "k = (\(y2) − \(y1)) : (\(x2) − \(x1)) = \(k)".replacingMinus + ".",
                             why: "k — на сколько меняется y, когда x увеличивается на 1.",
                             ask: "Чему равно k?", answer: "\(k)".replacingMinus),
                SolutionStep("Находим b.", "b = \(y1) − \(k) · \(x1) = \(b)".replacingMinus + ".", line: "y = " + res,
                             check: "Подставь вторую точку: \(k) · \(x2) + \(b) = \(y2).".replacingMinus),
            ])
    }

    static let systems = TopicDef(
        "g7.systems", .seven, section: "Системы уравнений", title: "Системы линейных уравнений",
        rule: ["Способ подстановки: из одного уравнения выражаем переменную и подставляем в другое.",
               "Способ сложения: уравниваем коэффициенты и складываем уравнения, чтобы одна переменная исчезла.",
               "Ответ — пара чисел (x; y). Проверка: подставь в оба уравнения."]
    ) { r, ctx in
        let x = r.signed(1...6), y = r.signed(1...6), a = r.int(1...4), b = r.int(1...3)
        let c1 = a * x + y, c2 = x - b * y
        let e1 = poly("\(a)x + y") + " = \(c1)".replacingMinus, e2 = poly("x - \(b)y") + " = \(c2)".replacingMinus
        let text = "\(e1); \(e2)"
        return Problem(
            topicID: "g7.systems", prompt: "Реши систему", statement: st(text), display: text,
            expected: st("x = \(x); y = \(y)".replacingMinus), spec: AnswerSpec(.point),
            steps: [
                SolutionStep("Выражаем y из первого уравнения.", "y = \(c1) − \(a)x".replacingMinus + ".",
                             line: "y = " + poly("\(c1) - \(a)x")),
                SolutionStep("Подставляем во второе.", "x − \(b)(\(poly("\(c1) - \(a)x"))) = \(c2)".replacingMinus + ".",
                             line: "x − \(b)(\(poly("\(c1) - \(a)x"))) = \(c2)".replacingMinus,
                             whyNot: "Минус перед скобкой меняет знаки внутри — не забудь."),
                SolutionStep("Решаем уравнение с одной переменной.", "x = \(x)".replacingMinus + ".", line: "x = \(x)".replacingMinus,
                             ask: "Чему равен x?", answer: "\(x)".replacingMinus),
                SolutionStep("Находим y.", "y = \(c1) − \(a) · \(x) = \(y)".replacingMinus + ".",
                             line: "x = \(x); y = \(y)".replacingMinus,
                             check: "Подставь (\(x); \(y)) в оба уравнения.".replacingMinus, ask: "Чему равен y?", answer: "\(y)".replacingMinus),
            ])
    }
}

/// Запись многочлена из нормальной формы: по убыванию степени, «x» вместо «1x», «−» вместо «+ −».
func polyText(_ p: Poly) -> String {
    if p.isZero { return "0" }
    var out = ""
    for (i, (m, c)) in p.terms.sorted(by: { $0.key < $1.key }).enumerated() {
        let neg = c.isNegative
        let absC = c.absolute
        var body = ""
        let vars = m.powers.keys.sorted().map { v -> String in
            let e = m.powers[v]!
            return e == 1 ? v : Expr.pow(.variable(v), .integer(e)).text
        }.joined()
        let radical = m.radicand == 1 ? "" : "√\(m.radicand)"
        if vars.isEmpty && radical.isEmpty {
            body = show(absC)
        } else if absC == .one {
            body = radical + vars
        } else {
            body = show(absC) + radical + vars
        }
        if i == 0 {
            out = (neg ? "−" : "") + body
        } else {
            out += (neg ? " − " : " + ") + body
        }
    }
    return out
}

extension String {
    var replacingOccurrencesOfPlusMinus: String { replacingOccurrences("+ −", "−") }

    func replacingOccurrences(_ a: String, _ b: String) -> String {
        guard !a.isEmpty else { return self }
        var result = ""
        var rest = Substring(self)
        while let range = rest.range(of: a) {
            result += rest[..<range.lowerBound] + b
            rest = rest[range.upperBound...]
        }
        return result + rest
    }
}

extension Substring {
    func range(of needle: String) -> Range<Substring.Index>? {
        guard !needle.isEmpty, count >= needle.count else { return nil }
        var i = startIndex
        while i < endIndex {
            if self[i...].hasPrefix(needle) { return i..<index(i, offsetBy: needle.count) }
            i = index(after: i)
        }
        return nil
    }
}
