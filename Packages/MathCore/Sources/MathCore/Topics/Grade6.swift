// Темы 6 класса.

enum Grade6 {
    static let topics: [TopicDef] = [
        gcdTopic, lcmTopic, primeFactorsTopic, reduce, fractionsDivisible, fractionsGeneral, fractionsSub,
        fractionsMul, fractionsDiv, mixedOps, proportion, percentProblems,
        negativesAdd, negativesMul, absolute, rationalNumbers, brackets, likeTerms, equations,
    ]

    static func factorText(_ n: Int) -> String {
        primeFactors(n).map(String.init).joined(separator: " · ")
    }

    static let gcdTopic = TopicDef(
        "g6.gcd", .six, section: "Делимость", title: "НОД",
        rule: ["НОД — наибольшее число, на которое делятся оба числа.", "Раскладываем оба числа на простые множители.",
               "Перемножаем общие множители."]
    ) { r, ctx in
        let g = r.int(ctx.easy ? 2...6 : 3...18)
        var p = r.int(2...(ctx.easy ? 5 : 9)), q = r.int(2...(ctx.easy ? 7 : 11))
        while gcd(p, q) != 1 || p == q { q = r.int(2...11) }
        let a = g * p, b = g * q
        let fa = primeFactors(a), fb = primeFactors(b)
        var rest = fb
        var common: [Int] = []
        for f in fa { if let i = rest.firstIndex(of: f) { common.append(f); rest.remove(at: i) } }
        return Problem(
            topicID: "g6.gcd", prompt: "Найди НОД(\(a); \(b))", statement: nil, display: "НОД(\(a); \(b))",
            expected: st("\(g)"), spec: AnswerSpec(.number),
            steps: [
                SolutionStep("Раскладываем на простые множители.", "\(a) = \(factorText(a)), \(b) = \(factorText(b)).",
                             why: "Простые множители — «кирпичи» числа, у НОД они общие.",
                             ask: "Разложи \(a) на простые множители.", answer: factorText(a)),
                SolutionStep("Берём общие множители и перемножаем.",
                             "Общие: \(common.map(String.init).joined(separator: " · ")). НОД = \(g).", line: "= \(g)",
                             check: "\(a) : \(g) = \(a / g), \(b) : \(g) = \(b / g), а у \(a / g) и \(b / g) общих делителей нет.",
                             ask: "Какое произведение общих множителей?", answer: "\(g)"),
            ])
    }

    static let lcmTopic = TopicDef(
        "g6.lcm", .six, section: "Делимость", title: "НОК",
        rule: ["НОК — наименьшее число, которое делится на оба числа.", "Берём разложение большего числа и добавляем недостающие множители меньшего.",
               "Быстрая проверка: НОК · НОД = a · b."]
    ) { r, ctx in
        var a = 4, b = 6
        for _ in 0..<50 {
            a = r.int(ctx.easy ? 3...12 : 4...30)
            b = r.int(ctx.easy ? 3...12 : 4...30)
            if a != b, gcd(a, b) > 1, a % b != 0, b % a != 0, (try? lcm(a, b)) ?? 999 <= (ctx.easy ? 60 : 180) { break }
        }
        let l = (try? lcm(a, b)) ?? a * b
        let big = max(a, b), small = min(a, b)
        return Problem(
            topicID: "g6.lcm", prompt: "Найди НОК(\(a); \(b))", statement: nil, display: "НОК(\(a); \(b))",
            expected: st("\(l)"), spec: AnswerSpec(.number),
            steps: [
                SolutionStep("Раскладываем на простые множители.", "\(big) = \(factorText(big)), \(small) = \(factorText(small))."),
                SolutionStep("К разложению большего добавляем недостающие множители меньшего.",
                             "\(big) · \(l / big) = \(l).", line: "= \(l)",
                             why: "НОК должен содержать все множители и \(a), и \(b).",
                             whyNot: "\(a) · \(b) = \(a * b) тоже делится на оба, но это не наименьшее.",
                             check: "\(l) : \(a) = \(l / a), \(l) : \(b) = \(l / b).",
                             ask: "На что умножить \(big), чтобы получилось число, делящееся на \(small)?", answer: "\(l / big)"),
            ])
    }

    static let primeFactorsTopic = TopicDef(
        "g6.primes", .six, section: "Делимость", title: "Разложение на простые множители",
        rule: ["Делим на самое маленькое простое число, пока делится: 2, потом 3, 5, 7…", "Записываем все делители через точку.",
               "Одинаковые множители можно записать степенью: 2 · 2 · 2 = 2³."]
    ) { r, ctx in
        var n = 12
        for _ in 0..<50 {
            n = r.int(ctx.easy ? 12...40 : 30...240)
            let fs = primeFactors(n)
            if fs.count >= 3 && fs.allSatisfy({ $0 <= 13 }) { break }
        }
        let fs = primeFactors(n)
        var lines: [SolutionStep] = []
        var m = n
        for p in fs {
            lines.append(SolutionStep("Делим на простое \(p).", "\(m) : \(p) = \(m / p).",
                                      ask: "Сколько будет \(m) : \(p)?", answer: "\(m / p)"))
            m /= p
        }
        lines.append(SolutionStep("Собираем множители.", "\(n) = \(factorText(n)).", line: "= " + factorText(n),
                                  check: "Перемножь — должно получиться \(n)."))
        return Problem(topicID: "g6.primes", prompt: "Разложи на простые множители", statement: st("\(n)"), display: "\(n)",
                       expected: st(factorText(n)), spec: AnswerSpec(.primeFactorization), steps: lines)
    }

    static let reduce = TopicDef(
        "g6.reduce", .six, section: "Обыкновенные дроби", title: "Сокращение дробей",
        rule: ["Делим верх и низ на одно и то же число.", "Лучше сразу на НОД — тогда хватит одного шага.",
               "Дробь сокращена, когда у верха и низа нет общих делителей, кроме 1."]
    ) { r, ctx in
        let g = r.int(2...(ctx.easy ? 5 : 12))
        var a = r.int(1...7), b = r.int((a + 1)...12)
        while gcd(a, b) != 1 { b += 1 }
        let top = a * g, bottom = b * g
        (a, b) = (top / g, bottom / g)
        return Problem(topicID: "g6.reduce", prompt: "Сократи дробь", statement: st("\(top)/\(bottom)"), display: "\(top)/\(bottom)",
                       expected: st("\(a)/\(b)"), spec: AnswerSpec(.number),
                       steps: reduceAndWholeSteps(top, bottom, requireMixed: false))
    }

    static func fractionProblem(_ id: String, _ a: Int, _ b: Int, _ c: Int, _ d: Int, minus: Bool) -> Problem {
        let (steps, result) = fractionSumSteps(a, b, c, d, minus: minus, requireMixed: true)
        let text = "\(a)/\(b) \(minus ? "−" : "+") \(c)/\(d)"
        return Problem(topicID: id, prompt: "Вычисли", statement: st(text), display: text,
                       expected: numberAnswer(result, mixed: true), spec: AnswerSpec(.number, requireMixed: true), steps: steps)
    }

    static let fractionsDivisible = TopicDef(
        "g6.addDiv", .six, section: "Обыкновенные дроби", title: "Разный низ: один делится на другой",
        rule: ["Если больший низ делится на меньший, он и есть общий низ.", "Дробь с меньшим низом умножаем — верх и низ — на частное низов.",
               "Складываем верхи, низ оставляем, сокращаем."]
    ) { r, ctx in
        let b = r.int(2...(ctx.easy ? 3 : 6)), k = r.int(2...(ctx.easy ? 2 : 4))
        let d = b * k
        let a = r.int(1...(b - 1)), c = r.int(1...(d - 1))
        return fractionProblem("g6.addDiv", a, b, c, d, minus: false)
    }

    static let fractionsGeneral = TopicDef(
        "g6.addGen", .six, section: "Обыкновенные дроби", title: "Разный низ: общий случай",
        rule: ["Общий низ — наименьшее общее кратное низов.", "Каждую дробь умножаем — верх и низ — на свой дополнительный множитель.",
               "Складываем верхи, сокращаем, выделяем целую часть."]
    ) { r, ctx in
        var b = 3, d = 4
        for _ in 0..<50 {
            b = r.int(2...(ctx.easy ? 6 : 12))
            d = r.int(2...(ctx.easy ? 6 : 12))
            if b != d, b % d != 0, d % b != 0, (try? lcm(b, d)) ?? 999 <= (ctx.easy ? 30 : 72) { break }
        }
        return fractionProblem("g6.addGen", r.int(1...(b - 1)), b, r.int(1...(d - 1)), d, minus: false)
    }

    static let fractionsSub = TopicDef(
        "g6.sub", .six, section: "Обыкновенные дроби", title: "Вычитание дробей с разным низом",
        rule: ["Приводим к общему низу — как при сложении.", "Вычитаем верхи, низ оставляем.", "Сокращаем, если можно."]
    ) { r, ctx in
        var b = 3, d = 4
        for _ in 0..<50 {
            b = r.int(2...(ctx.easy ? 6 : 12))
            d = r.int(2...(ctx.easy ? 6 : 12))
            if b != d, (try? lcm(b, d)) ?? 999 <= (ctx.easy ? 24 : 60) { break }
        }
        var a = r.int(1...(b - 1)), c = r.int(1...(d - 1))
        if a * d <= c * b { (a, c) = (b - 1, 1) }
        if a * d <= c * b { return fractionProblem("g6.sub", c, d, a, b, minus: false) }
        return fractionProblem("g6.sub", a, b, c, d, minus: true)
    }

    static let fractionsMul = TopicDef(
        "g6.mul", .six, section: "Обыкновенные дроби", title: "Умножение дробей",
        rule: ["Верх умножаем на верх, низ — на низ.", "Сокращать удобно до умножения — крест-накрест.",
               "Смешанные числа сначала переводим в неправильные дроби."]
    ) { r, ctx in
        let a = r.int(1...5), b = r.int((a + 1)...9), c = r.int(1...5), d = r.int((c + 1)...9)
        let result = Rational.of(a * c, b * d)
        let text = "\(a)/\(b) · \(c)/\(d)"
        var steps = [SolutionStep("Верх на верх, низ на низ.", "\(a) · \(c) = \(a * c), \(b) · \(d) = \(b * d).",
                                  line: "= \(a * c)/\(b * d)",
                                  whyNot: "Общий низ при умножении не нужен — это правило для сложения.",
                                  ask: "Сколько будет \(a) · \(c)?", answer: "\(a * c)")]
        steps += reduceAndWholeSteps(a * c, b * d, requireMixed: false)
        return Problem(topicID: "g6.mul", prompt: "Вычисли", statement: st(text), display: text,
                       expected: numberAnswer(result, mixed: true), spec: AnswerSpec(.number, requireMixed: true), steps: steps)
    }

    static let fractionsDiv = TopicDef(
        "g6.div", .six, section: "Обыкновенные дроби", title: "Деление дробей",
        rule: ["Делить на дробь — значит умножать на перевёрнутую дробь.", "a/b : c/d = a/b · d/c.", "Потом как при умножении."]
    ) { r, ctx in
        let a = r.int(1...5), b = r.int((a + 1)...9), c = r.int(1...5), d = r.int((c + 1)...9)
        let result = Rational.of(a * d, b * c)
        let text = "\(a)/\(b) : \(c)/\(d)"
        var steps = [
            SolutionStep("Переворачиваем вторую дробь и умножаем.", "\(c)/\(d) → \(d)/\(c).", line: "= \(a)/\(b) · \(d)/\(c)",
                         why: "Деление на \(c)/\(d) — это умножение на обратное число \(d)/\(c).",
                         whyNot: "Если просто умножить на \(c)/\(d), получится \(show(Rational.of(a * c, b * d))) — это неверно.",
                         ask: "Какая дробь обратна \(c)/\(d)?", answer: "\(d)/\(c)"),
            SolutionStep("Верх на верх, низ на низ.", "\(a) · \(d) = \(a * d), \(b) · \(c) = \(b * c).", line: "= \(a * d)/\(b * c)"),
        ]
        steps += reduceAndWholeSteps(a * d, b * c, requireMixed: true)
        return Problem(topicID: "g6.div", prompt: "Вычисли", statement: st(text), display: text,
                       expected: numberAnswer(result, mixed: true), spec: AnswerSpec(.number, requireMixed: true), steps: steps)
    }

    static let mixedOps = TopicDef(
        "g6.mixed", .six, section: "Обыкновенные дроби", title: "Действия со смешанными числами",
        rule: ["Переводим смешанные числа в неправильные дроби.", "Делаем действие по правилам для дробей.",
               "В ответе выделяем целую часть."]
    ) { r, ctx in
        let b = r.pick([2, 3, 4]), d = r.pick([3, 4, 6])
        let w1 = r.int(1...3), w2 = r.int(1...2), a = r.int(1...(b - 1)), c = r.int(1...(d - 1))
        let t1 = w1 * b + a, t2 = w2 * d + c
        let (steps0, result) = fractionSumSteps(t1, b, t2, d, minus: false, requireMixed: true)
        let text = "\(w1) \(a)/\(b) + \(w2) \(c)/\(d)"
        let steps = [SolutionStep("Переводим в неправильные дроби.", "\(w1) \(a)/\(b) = \(t1)/\(b), \(w2) \(c)/\(d) = \(t2)/\(d).",
                                  line: "= \(t1)/\(b) + \(t2)/\(d)",
                                  why: "Целую часть умножаем на низ и прибавляем верх.",
                                  ask: "Сколько будет \(w1) · \(b) + \(a)?", answer: "\(t1)")] + steps0
        return Problem(topicID: "g6.mixed", prompt: "Вычисли", statement: st(text), display: text,
                       expected: numberAnswer(result, mixed: true), spec: AnswerSpec(.number, requireMixed: true), steps: steps)
    }

    static let proportion = TopicDef(
        "g6.proportion", .six, section: "Отношения и пропорции", title: "Пропорции",
        rule: ["В пропорции a : b = c : d произведение крайних равно произведению средних: a · d = b · c.",
               "Неизвестный член = произведение двух известных «накрест» : третье."]
    ) { r, ctx in
        let a = r.int(2...9), k = r.int(2...(ctx.easy ? 4 : 9)), b = r.int(2...9)
        let c = a * k, x = b * k
        let text = "\(a) : \(b) = \(c) : x"
        return Problem(
            topicID: "g6.proportion", prompt: "Найди x", statement: st("\(a)/\(b) = \(c)/x"), display: text,
            expected: st("x = \(x)"), spec: AnswerSpec(.roots),
            steps: [
                SolutionStep("Произведение крайних равно произведению средних.", "\(a) · x = \(b) · \(c).", line: "\(a)x = \(b * c)",
                             why: "Это основное свойство пропорции: \(a)/\(b) = \(c)/x ⇔ \(a) · x = \(b) · \(c).",
                             ask: "Сколько будет \(b) · \(c)?", answer: "\(b * c)"),
                SolutionStep("Находим неизвестный множитель.", "x = \(b * c) : \(a) = \(x).", line: "x = \(x)",
                             check: "\(a) : \(b) и \(c) : \(x) — одно и то же отношение (\(show(Rational.of(a, b))))."),
            ])
    }

    static let percentProblems = TopicDef(
        "g6.percentTasks", .six, section: "Проценты", title: "Задачи на проценты",
        rule: ["Число по его проценту: если p% — это a, то всё число = a : p · 100.",
               "Сколько процентов a от b: a : b · 100%."]
    ) { r, ctx in
        let p = r.pick([5, 10, 15, 20, 25, 30, 40, 50, 60, 75]), n = 20 * r.int(1...30)
        let part = n * p / 100
        if r.bool() {
            return Problem(
                topicID: "g6.percentTasks", prompt: "Найди число, \(p)% которого равны \(part)",
                statement: st("\(p)% · x = \(part)"), display: "\(p)% числа = \(part)",
                expected: st("x = \(n)"), spec: AnswerSpec(.roots),
                steps: [
                    SolutionStep("Находим 1%.", "\(part) : \(p) = \(show(Rational.of(part, p), decimal: true)).",
                                 ask: "Сколько будет \(part) : \(p)?", answer: show(Rational.of(part, p), decimal: true)),
                    SolutionStep("Всё число — это 100%.", "\(show(Rational.of(part, p), decimal: true)) · 100 = \(n).", line: "x = \(n)",
                                 check: "\(p)% от \(n) = \(part)."),
                ])
        }
        return Problem(
            topicID: "g6.percentTasks", prompt: "Сколько процентов \(part) составляет от \(n)?",
            statement: st("x% · \(n) = \(part)"), display: "\(part) от \(n) — ?%",
            expected: st("x = \(p)"), spec: AnswerSpec(.roots),
            steps: [
                SolutionStep("Делим часть на целое.", "\(part) : \(n) = \(show(Rational.of(part, n), decimal: true)).",
                             ask: "Сколько будет \(part) : \(n)?", answer: show(Rational.of(part, n), decimal: true)),
                SolutionStep("Умножаем на 100%.", "\(show(Rational.of(part, n), decimal: true)) · 100 = \(p)%.", line: "x = \(p)",
                             check: "\(p)% от \(n) = \(part)."),
            ])
    }

    static func arithmeticTopic(_ id: String, _ text: String, prompt: String = "Вычисли", decimal: Bool = false) -> Problem {
        let e = ex(text)
        let value = (try? e.rationalValue()) ?? .zero
        return Problem(topicID: id, prompt: prompt, statement: .expression(e), display: e.text,
                       expected: st(show(value, decimal: decimal)), spec: AnswerSpec(.number),
                       steps: arithmeticSteps(e, decimal: decimal))
    }

    static let negativesAdd = TopicDef(
        "g6.negAdd", .six, section: "Положительные и отрицательные числа", title: "Сложение и вычитание отрицательных",
        rule: ["Знаки одинаковые — складываем модули, знак общий.", "Знаки разные — из большего модуля вычитаем меньший, знак у большего.",
               "Вычесть число — значит прибавить противоположное: a − (−b) = a + b."]
    ) { r, ctx in
        let a = r.signed(1...(ctx.easy ? 9 : 30)), b = r.signed(1...(ctx.easy ? 9 : 30))
        let op = r.bool() ? "+" : "−"
        let bt = b < 0 ? "(−\(-b))" : "\(b)"
        let at = a < 0 ? "−\(-a)" : "\(a)"
        return arithmeticTopic("g6.negAdd", "\(at) \(op) \(bt)")
    }

    static let negativesMul = TopicDef(
        "g6.negMul", .six, section: "Положительные и отрицательные числа", title: "Умножение и деление отрицательных",
        rule: ["Знаки одинаковые — результат положительный.", "Знаки разные — результат отрицательный.", "Модули умножаем или делим как обычно."]
    ) { r, ctx in
        let a = r.signed(2...9), b = r.signed(2...9)
        let at = a < 0 ? "−\(-a)" : "\(a)", bt = b < 0 ? "(−\(-b))" : "\(b)"
        if r.bool() { return arithmeticTopic("g6.negMul", "\(at) · \(bt)") }
        let p = a * b
        let pt = p < 0 ? "−\(-p)" : "\(p)"
        return arithmeticTopic("g6.negMul", "\(pt) : \(bt)")
    }

    static let absolute = TopicDef(
        "g6.abs", .six, section: "Положительные и отрицательные числа", title: "Модуль числа",
        rule: ["Модуль — расстояние от нуля, он не бывает отрицательным.", "|a| = a, если a ≥ 0; |a| = −a, если a < 0.",
               "Сначала считаем внутри модуля, потом берём модуль."]
    ) { r, ctx in
        let a = r.int(2...15), b = r.int(2...9), c = r.int(10...20)
        return arithmeticTopic("g6.abs", ctx.easy ? "|−\(a)| + |\(b)|" : "|−\(a)| + |\(b) − \(c)|")
    }

    static let rationalNumbers = TopicDef(
        "g6.rational", .six, section: "Положительные и отрицательные числа", title: "Действия с рациональными числами",
        rule: ["Знак определяем по правилам для отрицательных чисел.", "Модули считаем по правилам для дробей.",
               "Порядок действий обычный."]
    ) { r, ctx in
        let b = r.pick([2, 3, 4, 6]), d = r.pick([3, 4, 6, 8])
        let a = r.int(1...(b - 1)), c = r.int(1...(d - 1))
        let e = ex("−\(a)/\(b) + \(c)/\(d)")
        let value = (try? e.rationalValue()) ?? .zero
        let l = (try? lcm(b, d)) ?? b * d
        var steps = [SolutionStep("Приводим к общему низу.", "Общий низ \(l): −\(a * l / b)/\(l) + \(c * l / d)/\(l).",
                                  line: "= −\(a * l / b)/\(l) + \(c * l / d)/\(l)",
                                  ask: "Какой общий низ у \(b) и \(d)?", answer: "\(l)")]
        let top = -a * l / b + c * l / d
        steps.append(SolutionStep("Складываем верхи с учётом знака.", "−\(a * l / b) + \(c * l / d) = \(top)".replacingMinus + ".",
                                  line: "= \(show(Rational.of(top, l)))",
                                  why: "Знаки разные: из большего модуля вычитаем меньший, знак — у большего."))
        return Problem(topicID: "g6.rational", prompt: "Вычисли", statement: .expression(e), display: e.text,
                       expected: st(show(value)), spec: AnswerSpec(.number), steps: steps)
    }

    static let brackets = TopicDef(
        "g6.brackets", .six, section: "Выражения", title: "Раскрытие скобок",
        rule: ["Плюс перед скобкой — знаки внутри не меняются.", "Минус перед скобкой — меняем знак каждого слагаемого внутри.",
               "Число перед скобкой умножаем на каждое слагаемое."]
    ) { r, ctx in
        let a = r.int(2...9), b = r.int(1...9), c = r.int(2...6), k = r.int(2...5)
        if r.bool() || ctx.easy {
            let text = "\(a)x − (\(c)x + \(b))"
            let result = Grade7.poly("\(a - c)x - \(b)")
            return Problem(
                topicID: "g6.brackets", prompt: "Раскрой скобки и упрости", statement: st(text), display: text,
                expected: st(result), spec: AnswerSpec(.polynomial),
                steps: [
                    SolutionStep("Минус перед скобкой — меняем знаки внутри.", "−(\(c)x + \(b)) = −\(c)x − \(b).",
                                 line: "= \(a)x − \(c)x − \(b)",
                                 whyNot: "Частая ошибка: −\(c)x + \(b). Знак меняется у каждого слагаемого.",
                                 ask: "Какой знак будет у \(b) после раскрытия?", answer: "−\(b)"),
                    SolutionStep("Приводим подобные.", "\(a)x − \(c)x = \(a - c)x.", line: "= " + result),
                ])
        }
        let text = "\(k)(\(a)x − \(b)) + \(c)"
        let fixed = Grade7.poly("\(k * a)x - \(k * b - c)")
        return Problem(
            topicID: "g6.brackets", prompt: "Раскрой скобки и упрости", statement: st(text), display: text,
            expected: st(fixed), spec: AnswerSpec(.polynomial),
            steps: [
                SolutionStep("Умножаем число на каждое слагаемое в скобке.", "\(k) · \(a)x = \(k * a)x, \(k) · \(b) = \(k * b).",
                             line: "= \(k * a)x − \(k * b) + \(c)", whyNot: "Умножить нужно и \(a)x, и \(b), а не только первое.",
                             ask: "Сколько будет \(k) · \(b)?", answer: "\(k * b)"),
                SolutionStep("Считаем числа.", "−\(k * b) + \(c) = \(c - k * b)".replacingMinus + ".", line: "= " + fixed),
            ])
    }

    static let likeTerms = TopicDef(
        "g6.like", .six, section: "Выражения", title: "Подобные слагаемые",
        rule: ["Подобные — с одинаковой буквенной частью: 3x и −5x.", "Складываем их коэффициенты, буквенную часть оставляем.",
               "Числа без букв — тоже подобные между собой."]
    ) { r, ctx in
        let a = r.int(2...9), b = r.int(1...9), c = r.int(1...(a - 1 > 0 ? a - 1 : 1)), d = r.int(1...9)
        let text = "\(a)x + \(b) − \(c)x + \(d)"
        let result = Grade7.poly("\(a - c)x + \(b + d)")
        return Problem(
            topicID: "g6.like", prompt: "Приведи подобные", statement: st(text), display: text,
            expected: st(result), spec: AnswerSpec(.polynomial),
            steps: [
                SolutionStep("Группируем подобные.", "x: \(a)x и −\(c)x; числа: \(b) и \(d).",
                             line: "= \(a)x − \(c)x + \(b) + \(d)", why: "Складывать можно только одинаковые «единицы»: иксы с иксами."),
                SolutionStep("Складываем коэффициенты.", "\(a) − \(c) = \(a - c), \(b) + \(d) = \(b + d).", line: "= " + result,
                             ask: "Сколько будет \(a) − \(c)?", answer: "\(a - c)"),
            ])
    }

    static let equations = TopicDef(
        "g6.eq", .six, section: "Уравнения", title: "Уравнения с переносом",
        rule: ["Слагаемые с x переносим влево, числа — вправо.", "При переносе через «=» знак меняется на противоположный.",
               "Обе части делим на коэффициент при x."]
    ) { r, ctx in
        let x = r.signed(1...9), a = r.int(3...9), c = r.int(1...(a - 1)), b = r.int(1...15)
        let d = (a - c) * x + b
        let text = "\(a)x + \(b) = \(c)x + \(d)".replacingMinus
        return Problem(
            topicID: "g6.eq", prompt: "Реши уравнение", statement: st(text), display: st(text).text,
            expected: st("x = \(x)"), spec: AnswerSpec(.roots),
            steps: [
                SolutionStep("Переносим: иксы влево, числа вправо, меняя знак.", "\(a)x − \(c)x = \(d) − \(b)".replacingMinus + ".",
                             line: "\(a)x − \(c)x = \(d) − \(b)".replacingMinus,
                             whyNot: "Если перенести \(b) без смены знака, получится \(a)x − \(c)x = \(d) + \(b) — это неверно.",
                             ask: "Каким станет +\(b) после переноса вправо?", answer: "−\(b)"),
                SolutionStep("Приводим подобные.", "\(a - c)x = \(d - b)".replacingMinus + ".", line: "\(a - c)x = \(d - b)".replacingMinus),
                SolutionStep("Делим обе части на \(a - c).", "x = \(x)".replacingMinus + ".", line: "x = \(x)".replacingMinus,
                             check: "Подставь x = \(x) в обе части — получится одно и то же.".replacingMinus,
                             ask: "Сколько будет \(d - b) : \(a - c)?".replacingMinus, answer: "\(x)".replacingMinus),
            ])
    }
}
