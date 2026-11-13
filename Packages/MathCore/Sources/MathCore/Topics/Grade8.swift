// Темы 8 класса.

enum Grade8 {
    static let topics: [TopicDef] = [
        rationalReduce, rationalOps, rationalEquations, integerPowers, standardForm, roots,
        quadratic, vieta, inequalities, inequalitySystems, functions, statistics, probability,
    ]

    static func poly(_ text: String) -> String { Grade7.poly(text) }

    static let rationalReduce = TopicDef(
        "g8.ratReduce", .eight, section: "Рациональные дроби", title: "Сокращение рациональных дробей",
        rule: ["Раскладываем верх и низ на множители.", "Сокращаем одинаковые множители — только множители, не слагаемые.",
               "Помним про ОДЗ: знаменатель не равен нулю."]
    ) { r, ctx in
        let a = r.int(1...9)
        if r.bool() {
            let text = "{\(poly("x^2 - \(a * a)"))}/{\(poly("x^2 + \(a)x"))}"
            let res = "{x − \(a)}/{x}"
            return Problem(
                topicID: "g8.ratReduce", prompt: "Сократи дробь", statement: st(text), display: st(text).text,
                expected: st(res), spec: AnswerSpec(.rationalFraction),
                steps: [
                    SolutionStep("Раскладываем на множители.", "Верх: (x − \(a))(x + \(a)), низ: x(x + \(a)).",
                                 line: "= {(x − \(a))(x + \(a))}/{x(x + \(a))}",
                                 ask: "Разложи x² − \(a * a) на множители.", answer: "(x − \(a))(x + \(a))"),
                    SolutionStep("Сокращаем общий множитель (x + \(a)).", "Остаётся (x − \(a))/x.", line: "= " + res,
                                 why: "Делим верх и низ на одно и то же выражение — дробь не меняется (при x ≠ −\(a), x ≠ 0).",
                                 whyNot: "Нельзя сокращать x² и x — это слагаемые, а не множители."),
                ])
        }
        let k = r.int(2...6)
        let text = "{\(poly("\(k)x + \(k * a)"))}/{\(poly("x^2 + \(a)x"))}"
        let res = "{\(k)}/{x}"
        return Problem(
            topicID: "g8.ratReduce", prompt: "Сократи дробь", statement: st(text), display: st(text).text,
            expected: st(res), spec: AnswerSpec(.rationalFraction),
            steps: [
                SolutionStep("Выносим общий множитель в числителе и знаменателе.", "Верх: \(k)(x + \(a)), низ: x(x + \(a)).",
                             line: "= {\(k)(x + \(a))}/{x(x + \(a))}",
                             ask: "Вынеси общий множитель: \(poly("\(k)x + \(k * a)")) = ?", answer: "\(k)(x + \(a))"),
                SolutionStep("Сокращаем (x + \(a)).", "Остаётся \(k)/x.", line: "= " + res,
                             whyNot: "Сокращать можно только множители: x в \(k)x и x² сокращать нельзя, пока не вынесли скобку."),
            ])
    }

    static let rationalOps = TopicDef(
        "g8.ratOps", .eight, section: "Рациональные дроби", title: "Сложение рациональных дробей",
        rule: ["Как с обычными дробями: общий знаменатель, дополнительные множители, складываем числители.",
               "Общий знаменатель — произведение разных множителей знаменателей."]
    ) { r, ctx in
        let a = r.int(1...9), p = r.int(1...(ctx.easy ? 1 : 4)), q = r.int(1...(ctx.easy ? 1 : 4))
        let text = "{\(p)}/{x} + {\(q)}/{x + \(a)}"
        let top = poly("\(p + q)x + \(p * a)")
        let res = "{\(top)}/{x(x + \(a))}"
        return Problem(
            topicID: "g8.ratOps", prompt: "Сложи дроби", statement: st(text), display: st(text).text,
            expected: st(res), spec: AnswerSpec(.rationalFraction),
            steps: [
                SolutionStep("Общий знаменатель x(x + \(a)).", "Дополнительные множители: x + \(a) и x.",
                             line: "= {\(p)(x + \(a))}/{x(x + \(a))} + {\(q)x}/{x(x + \(a))}",
                             whyNot: "Складывать знаменатели нельзя — как и у обычных дробей.",
                             arrows: [Arrow("\(p)/x", "\(p)(x + \(a))/(x(x + \(a)))", "×(x + \(a))"),
                                      Arrow("\(q)/(x + \(a))", "\(q)x/(x(x + \(a)))", "×x")]),
                SolutionStep("Складываем числители.", "\(p)(x + \(a)) + \(q)x = \(top).", line: "= " + res,
                             ask: "Чему равен числитель?", answer: top),
            ])
    }

    static let rationalEquations = TopicDef(
        "g8.ratEq", .eight, section: "Рациональные уравнения", title: "Рациональные уравнения",
        rule: ["Находим ОДЗ: знаменатели не равны нулю.", "Умножаем обе части на общий знаменатель.",
               "Решаем получившееся уравнение и выбрасываем корни, которые не входят в ОДЗ."]
    ) { r, ctx in
        let a = r.int(1...5), x = r.pick([2, 3, 4, 5, 6].filter { $0 != a })
        // x² − (a + x0)x + a·x0 = 0 после умножения, корень a — посторонний.
        let text = "{x²}/{x − \(a)} = {\(poly("\(a + x)x - \(a * x)"))}/{x − \(a)}"
        return Problem(
            topicID: "g8.ratEq", prompt: "Реши уравнение", statement: st(text), display: st(text).text,
            expected: st("x = \(x)"), spec: AnswerSpec(.roots),
            steps: [
                SolutionStep("ОДЗ: x − \(a) ≠ 0.", "x ≠ \(a).", why: "На ноль делить нельзя."),
                SolutionStep("Умножаем обе части на x − \(a).", "Знаменатели исчезают.",
                             line: "x² = \(poly("\(a + x)x - \(a * x)"))"),
                SolutionStep("Решаем квадратное уравнение.", "Корни: \(a) и \(x).", line: "x = \(a) или x = \(x)",
                             ask: "Какие корни у x² − \(a + x)x + \(a * x) = 0?", answer: "x = \(a) или x = \(x)"),
                SolutionStep("Проверяем ОДЗ.", "x = \(a) не подходит: знаменатель равен нулю.", line: "x = \(x)",
                             whyNot: "Если оставить x = \(a), это посторонний корень."),
            ])
    }

    static let integerPowers = TopicDef(
        "g8.intPow", .eight, section: "Степени", title: "Степень с целым показателем",
        rule: ["a⁻ⁿ = 1/aⁿ.", "a⁰ = 1 при a ≠ 0.", "Свойства степеней работают и для отрицательных показателей."]
    ) { r, ctx in
        let a = r.int(2...5), n = r.int(1...3)
        if ctx.easy || r.bool() {
            let text = "\(a)⁻" + ["", "¹", "²", "³"][n]
            let value = Rational.of(1, Int(pow(Double(a), Double(n))))
            return Problem(topicID: "g8.intPow", prompt: "Вычисли", statement: st(text), display: text,
                           expected: st(show(value)), spec: AnswerSpec(.number),
                           steps: [SolutionStep("Отрицательный показатель — это дробь.", "\(text) = 1/\(a)\(["", "", "²", "³"][n]).",
                                                line: "= " + show(value), whyNot: "\(text) — не отрицательное число, а дробь.",
                                                ask: "Сколько будет \(a)\(["", "", "²", "³"][n])?", answer: "\(Int(pow(Double(a), Double(n))))")])
        }
        let m = r.int(3...6)
        let text = "\(a)^\(m) · \(a)^(-\(n + m - 1))"
        let shown = ex(text).text
        return Problem(topicID: "g8.intPow", prompt: "Вычисли", statement: st(shown), display: shown,
                       expected: st("\(a)"), spec: AnswerSpec(.number),
                       steps: [SolutionStep("Показатели складываем.", "\(m) + (−\(n + m - 1)) = \(1 - n)".replacingMinus + ".",
                                            line: "= \(a)^(\(1 - n))".replacingMinus),
                               SolutionStep("Считаем.", "Результат: \(show((try? Rational(a).power(1 - n)) ?? .one)).",
                                            line: "= " + show((try? Rational(a).power(1 - n)) ?? .one))])
    }

    static let standardForm = TopicDef(
        "g8.stdForm", .eight, section: "Степени", title: "Стандартный вид числа",
        rule: ["Стандартный вид: a · 10ⁿ, где 1 ≤ a < 10.", "Запятую переносим, пока перед ней не останется одна ненулевая цифра.",
               "Перенесли влево — показатель положительный, вправо — отрицательный."]
    ) { r, ctx in
        let digits = r.int(12...98)
        let a = Rational.of(digits, 10)
        let n = r.pick(ctx.easy ? [2, 3, 4] : [-4, -3, -2, 3, 4, 5])
        let value = (try? a.multiplying(Rational(10).power(n))) ?? a
        let shown = show(value, decimal: true)
        let res = "\(show(a, decimal: true)) · 10" + superscriptNumber(n)
        return Problem(
            topicID: "g8.stdForm", prompt: "Запиши в стандартном виде", statement: st(shown), display: shown,
            expected: st(res), spec: AnswerSpec(.standardForm),
            steps: [SolutionStep("Переносим запятую после первой ненулевой цифры.", "Получаем \(show(a, decimal: true)).",
                                 why: "Так 1 ≤ a < 10.", ask: "Каким будет a?", answer: show(a, decimal: true)),
                    SolutionStep("Считаем, на сколько разрядов перенесли.", "n = \(n)".replacingMinus + ".", line: "= " + res,
                                 check: "\(show(a, decimal: true)) · 10\(superscriptNumber(n)) = \(shown).")])
    }

    static let roots = TopicDef(
        "g8.sqrt", .eight, section: "Квадратные корни", title: "Квадратные корни",
        rule: ["√a — неотрицательное число, квадрат которого равен a.", "√(ab) = √a · √b: выносим квадрат из-под корня.",
               "Складывать можно только одинаковые корни: 2√3 + 5√3 = 7√3."]
    ) { r, ctx in
        let k = r.pick([2, 3, 5]), p = r.int(2...4), q = r.int(1...3)
        if ctx.easy || r.bool() {
            let n = p * p * k
            return Problem(topicID: "g8.sqrt", prompt: "Упрости", statement: st("√\(n)"), display: "√\(n)",
                           expected: st("\(p)√\(k)"), spec: AnswerSpec(.number),
                           steps: [SolutionStep("Ищем квадрат среди множителей.", "\(n) = \(p * p) · \(k).",
                                                ask: "Какой наибольший квадрат делит \(n)?", answer: "\(p * p)"),
                                   SolutionStep("Выносим корень из квадрата.", "√\(n) = √\(p * p) · √\(k) = \(p)√\(k).",
                                                line: "= \(p)√\(k)", check: "(\(p)√\(k))² = \(p * p) · \(k) = \(n).")])
        }
        let n1 = p * p * k, n2 = q * q * k
        let text = "√\(n1) + √\(n2)"
        return Problem(topicID: "g8.sqrt", prompt: "Упрости", statement: st(text), display: text,
                       expected: st("\(p + q)√\(k)"), spec: AnswerSpec(.number),
                       steps: [SolutionStep("Упрощаем каждый корень.", "√\(n1) = \(p)√\(k), √\(n2) = \(q)√\(k).",
                                            line: "= \(p)√\(k) + \(q)√\(k)", whyNot: "√\(n1) + √\(n2) ≠ √\(n1 + n2)."),
                               SolutionStep("Складываем одинаковые корни.", "\(p) + \(q) = \(p + q).", line: "= \(p + q)√\(k)",
                                            ask: "Сколько будет \(p) + \(q)?", answer: "\(p + q)")])
    }

    static let quadratic = TopicDef(
        "g8.quadratic", .eight, section: "Квадратные уравнения", title: "Квадратные уравнения",
        rule: ["ax² + bx + c = 0: считаем D = b² − 4ac.", "D > 0 — два корня x = (−b ± √D) : 2a; D = 0 — один; D < 0 — корней нет.",
               "Проверка: подставь корни или сверь по Виета."]
    ) { r, ctx in
        let x1 = r.signed(1...(ctx.easy ? 4 : 7)), x2 = r.signed(1...(ctx.easy ? 4 : 7))
        let b = -(x1 + x2), c = x1 * x2
        let text = poly("x^2 + \(b)x + \(c)") + " = 0"
        let d = b * b - 4 * c
        let roots = Set([x1, x2]).sorted()
        let ans = roots.count == 1 ? "x = \(roots[0])" : "x = \(roots[0]) или x = \(roots[1])"
        var steps = [SolutionStep("Считаем дискриминант.", "a = 1, b = \(b), c = \(c)".replacingMinus + ".",
                                  line: "D = \(b * b) − \(4 * c) = \(d)".replacingOccurrences("− -", "+ ").replacingMinus,
                                  why: "D показывает, сколько корней: больше нуля — два.",
                                  whyNot: "Частая ошибка — знак: D = b² − 4ac, а не b² + 4ac.",
                                  ask: "Чему равен D?", answer: "\(d)".replacingMinus)]
        if d > 0 {
            steps.append(SolutionStep("Находим корни.", "√D = \(Int(Double(d).squareRoot())).",
                                      line: "x = (\(-b) ± \(Int(Double(d).squareRoot()))) : 2".replacingMinus,
                                      check: "Виета: x₁ + x₂ = \(-b), x₁ · x₂ = \(c).".replacingMinus))
        }
        steps.append(SolutionStep("Записываем ответ.", ans.replacingMinus + ".", line: ans.replacingMinus))
        return Problem(topicID: "g8.quadratic", prompt: "Реши уравнение", statement: st(text), display: text,
                       expected: st(ans), spec: AnswerSpec(.roots), steps: steps)
    }

    static let vieta = TopicDef(
        "g8.vieta", .eight, section: "Квадратные уравнения", title: "Теорема Виета",
        rule: ["Для x² + px + q = 0: x₁ + x₂ = −p, x₁ · x₂ = q.", "Подбираем два числа с нужными суммой и произведением.",
               "Знак суммы — противоположный p."]
    ) { r, ctx in
        let x1 = r.int(1...9), x2 = r.int(1...9) * (r.bool() ? 1 : -1)
        let p = -(x1 + x2), q = x1 * x2
        let text = poly("x^2 + \(p)x + \(q)") + " = 0"
        let ans = x1 == x2 ? "x = \(x1)" : "x = \(min(x1, x2)) или x = \(max(x1, x2))"
        return Problem(
            topicID: "g8.vieta", prompt: "Найди корни по теореме Виета", statement: st(text), display: text,
            expected: st(ans), spec: AnswerSpec(.roots),
            steps: [
                SolutionStep("Записываем сумму и произведение.", "x₁ + x₂ = \(-p), x₁ · x₂ = \(q)".replacingMinus + ".",
                             whyNot: "Сумма корней — это −p, а не p.", ask: "Чему равна сумма корней?", answer: "\(-p)".replacingMinus),
                SolutionStep("Подбираем числа.", "\(x1) и \(x2): сумма \(x1 + x2), произведение \(q).".replacingMinus,
                             line: ans.replacingMinus, check: "Подставь каждое число в уравнение."),
            ])
    }

    static let inequalities = TopicDef(
        "g8.ineq", .eight, section: "Неравенства", title: "Линейные неравенства",
        rule: ["Решаем как уравнение: переносим и делим.", "Делим на отрицательное — знак неравенства меняется.",
               "Ответ записываем промежутком: [ ] — точка входит, ( ) — нет."]
    ) { r, ctx in
        let a = r.signed(2...5), x0 = r.signed(1...6), b = r.signed(1...9)
        let rel = r.pick(["<", ">", "≤", "≥"])
        let rhs = a * x0 + b
        let text = poly("\(a)x + \(b)") + " \(rel) \(rhs)".replacingMinus
        let flipped = a < 0
        let finalRel: String = {
            guard flipped else { return rel }
            return ["<": ">", ">": "<", "≤": "≥", "≥": "≤"][rel]!
        }()
        let closed = finalRel == "≤" || finalRel == "≥"
        let interval = (finalRel == "<" || finalRel == "≤")
            ? "(−∞; \(x0)\(closed ? "]" : ")")".replacingMinus
            : "\(closed ? "[" : "(")\(x0); +∞)".replacingMinus
        return Problem(
            topicID: "g8.ineq", prompt: "Реши неравенство", statement: st(text), display: text,
            expected: st(interval), spec: AnswerSpec(.interval),
            steps: [
                SolutionStep("Переносим число вправо.", "\(a)x \(rel) \(rhs - b)".replacingMinus + ".",
                             line: "\(poly("\(a)x")) \(rel) \(rhs - b)".replacingMinus),
                SolutionStep(flipped ? "Делим на отрицательное число — знак меняется." : "Делим на положительное число — знак тот же.",
                             "x \(finalRel) \(x0)".replacingMinus + ".", line: "x \(finalRel) \(x0)".replacingMinus,
                             whyNot: flipped ? "Если оставить знак «\(rel)», ответ будет с другой стороны от \(x0)." : nil,
                             ask: "Какой знак будет после деления на \(a)?".replacingMinus, answer: "x \(finalRel) \(x0)".replacingMinus),
                SolutionStep("Записываем промежутком.", closed ? "Знак нестрогий — скобка квадратная." : "Знак строгий — скобка круглая.",
                             line: interval),
            ])
    }

    static let inequalitySystems = TopicDef(
        "g8.ineqSys", .eight, section: "Неравенства", title: "Системы неравенств",
        rule: ["Решаем каждое неравенство отдельно.", "Ответ — пересечение промежутков: там, где выполняются оба.",
               "Если пересечения нет — решений нет."]
    ) { r, ctx in
        let lo = r.int(-5...2), hi = lo + r.int(2...6)
        let shift = r.int(1...5)
        let t = "x + \(shift) > \(lo + shift); 2x ≤ \(2 * hi)".replacingMinus
        let interval = "(\(lo); \(hi)]".replacingMinus
        return Problem(
            topicID: "g8.ineqSys", prompt: "Реши систему неравенств", statement: st(t), display: t,
            expected: st(interval), spec: AnswerSpec(.interval),
            steps: [
                SolutionStep("Решаем первое.", "x > \(lo)".replacingMinus + ".", line: "x > \(lo)".replacingMinus),
                SolutionStep("Решаем второе.", "x ≤ \(hi)".replacingMinus + ".", line: "x ≤ \(hi)".replacingMinus),
                SolutionStep("Берём пересечение.", "Обе части выполняются при \(lo) < x ≤ \(hi).".replacingMinus, line: interval,
                             whyNot: "Объединение здесь не подходит — нужно, чтобы выполнялись оба неравенства."),
            ])
    }

    static let functions = TopicDef(
        "g8.functions", .eight, section: "Функции", title: "Функции y = k/x, y = √x, y = x²",
        rule: ["Чтобы найти значение функции, подставь x.", "y = k/x не определена при x = 0.", "y = √x определена при x ≥ 0."]
    ) { r, ctx in
        switch r.int(0...2) {
        case 0:
            let k = r.pick([6, 12, 24, 36]), x = r.pick([-6, -3, -2, 2, 3, 4, 6].filter { k % $0 == 0 })
            let f = "{\(k)}/{\(x < 0 ? "(\(x))" : "\(x)")}".replacingMinus
            return Problem(topicID: "g8.functions", prompt: "Найди y = \(k)/x при x = \(x)".replacingMinus, statement: st(f),
                           display: "y = \(k)/x, x = \(x)".replacingMinus, expected: st("\(k / x)".replacingMinus),
                           spec: AnswerSpec(.number),
                           steps: [SolutionStep("Подставляем.", "y = \(k) : \(x) = \(k / x)".replacingMinus + ".",
                                                line: "y = \(k / x)".replacingMinus)])
        case 1:
            let a = r.int(1...12)
            return Problem(topicID: "g8.functions", prompt: "Найди y = √x при x = \(a * a)", statement: st("√\(a * a)"),
                           display: "y = √x, x = \(a * a)", expected: st("\(a)"), spec: AnswerSpec(.number),
                           steps: [SolutionStep("Ищем неотрицательное число, квадрат которого \(a * a).", "\(a)² = \(a * a).",
                                                line: "y = \(a)", whyNot: "−\(a) тоже в квадрате даёт \(a * a), но √ — всегда неотрицательный.")])
        default:
            let x = r.signed(1...9)
            return Problem(topicID: "g8.functions", prompt: "Найди y = x² при x = \(x)".replacingMinus, statement: st("(\(x))²".replacingMinus),
                           display: "y = x², x = \(x)".replacingMinus, expected: st("\(x * x)"), spec: AnswerSpec(.number),
                           steps: [SolutionStep("Возводим в квадрат.", "(\(x))² = \(x * x)".replacingMinus + ".", line: "y = \(x * x)",
                                                whyNot: "Квадрат отрицательного числа — положительный.")])
        }
    }

    static let statistics = TopicDef(
        "g8.stats", .eight, section: "Статистика и вероятность", title: "Среднее, медиана, мода",
        rule: ["Среднее: сумма чисел : их количество.", "Медиана: середина упорядоченного ряда (при чётном количестве — среднее двух средних).",
               "Мода: число, которое встречается чаще всего."]
    ) { r, ctx in
        var data = (0..<(ctx.easy ? 5 : r.pick([5, 6, 7]))).map { _ in r.int(1...12) }
        let kind = r.int(0...2)
        if kind == 2 { data.append(data[0]); data.append(data[0]) }
        let sorted = data.sorted()
        let list = data.map(String.init).joined(separator: ", ")
        switch kind {
        case 0:
            let sum = data.reduce(0, +)
            let mean = Rational.of(sum, data.count)
            return Problem(topicID: "g8.stats", prompt: "Найди среднее", statement: nil, display: list,
                           story: "Найди среднее арифметическое: \(list).", expected: st(show(mean, decimal: mean.isTerminatingDecimal)),
                           spec: AnswerSpec(.number),
                           steps: [SolutionStep("Складываем все числа.", "Сумма = \(sum).", ask: "Чему равна сумма?", answer: "\(sum)"),
                                   SolutionStep("Делим на количество.", "\(sum) : \(data.count) = \(show(mean, decimal: mean.isTerminatingDecimal)).",
                                                line: "= " + show(mean, decimal: mean.isTerminatingDecimal))])
        case 1:
            let n = sorted.count
            let med = n % 2 == 1 ? Rational(sorted[n / 2]) : Rational.of(sorted[n / 2 - 1] + sorted[n / 2], 2)
            return Problem(topicID: "g8.stats", prompt: "Найди медиану", statement: nil, display: list,
                           story: "Найди медиану ряда: \(list).", expected: st(show(med, decimal: true)), spec: AnswerSpec(.number),
                           steps: [SolutionStep("Упорядочиваем ряд.", sorted.map(String.init).joined(separator: ", ") + ".",
                                                whyNot: "Без упорядочивания «середина» ничего не значит."),
                                   SolutionStep(n % 2 == 1 ? "Берём число в середине." : "Берём среднее двух средних.",
                                                "Медиана = \(show(med, decimal: true)).", line: "= " + show(med, decimal: true))])
        default:
            let counts = Dictionary(grouping: data, by: { $0 }).mapValues(\.count)
            let mode = counts.max { a, b in a.value < b.value || (a.value == b.value && a.key > b.key) }!.key
            return Problem(topicID: "g8.stats", prompt: "Найди моду", statement: nil, display: list,
                           story: "Найди моду ряда: \(list).", expected: st("\(mode)"), spec: AnswerSpec(.number),
                           steps: [SolutionStep("Считаем, сколько раз встречается каждое число.", "\(mode) — \(counts[mode]!) раза.",
                                                line: "= \(mode)")])
        }
    }

    static let probability = TopicDef(
        "g8.prob", .eight, section: "Статистика и вероятность", title: "Вероятность",
        rule: ["Вероятность = число благоприятных исходов : число всех исходов.", "Она от 0 до 1, записываем дробью."]
    ) { r, ctx in
        let red = r.int(1...9), blue = r.int(1...9), green = ctx.easy ? 0 : r.int(0...6)
        let total = red + blue + green
        let p = Rational.of(red, total)
        let story = green > 0
            ? "В коробке \(red) красных, \(blue) синих и \(green) зелёных шаров. Какова вероятность вынуть красный?"
            : "В коробке \(red) красных и \(blue) синих шаров. Какова вероятность вынуть красный?"
        var steps = [SolutionStep("Считаем все исходы.", "Всего шаров: \(total).", ask: "Сколько всего шаров?", answer: "\(total)"),
                     SolutionStep("Благоприятные — красные.", "P = \(red)/\(total).", line: "= \(red)/\(total)",
                                  whyNot: "Делить на число синих неверно — делим на все шары.")]
        steps += reduceAndWholeSteps(red, total, requireMixed: false)
        return Problem(topicID: "g8.prob", prompt: "Найди вероятность", statement: nil, display: "P(красный)", story: story,
                       expected: st(show(p)), spec: AnswerSpec(.number), steps: steps)
    }
}

func superscriptNumber(_ n: Int) -> String {
    let map: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
                                       "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]
    return String(String(n).map { map[$0] ?? $0 })
}

/// Без Foundation: целая степень.
func pow(_ a: Double, _ b: Double) -> Double {
    var r = 1.0
    for _ in 0..<Int(b) { r *= a }
    return r
}
