// Темы 5 класса.

enum Grade5 {
    static let topics: [TopicDef] = [
        multiplication, orderOfOperations, powers, remainder,
        sameDenominatorAdd, sameDenominatorSub, wholePart, toImproper, mixedSame,
        decimalAddSub, decimalMulDiv, simpleEquations, percentOf,
    ]

    static let multiplication = TopicDef(
        "g5.table", .five, section: "Натуральные числа", title: "Таблица умножения",
        rule: ["a × b — это a, взятое b раз.", "Если факт забылся, иди от соседнего: a × b = a × (b − 1) + a.",
               "Деление — обратное умножению: c : a = b, потому что a × b = c."]
    ) { r, ctx in
        let column = r.pick(ctx.columns)
        let other = r.int(ctx.easy ? 2...5 : 2...10)
        // Столбик может стоять и первым, и вторым множителем: 6 × 7 и 7 × 6.
        let (a, b) = r.bool() ? (column, other) : (other, column)
        let product = a * b
        if r.int(0...2) < 2 {
            let known = b > 2 ? a * (b - 1) : a
            return Problem(
                topicID: "g5.table", prompt: "Вычисли", statement: st("\(a) × \(b)"), display: "\(a) × \(b)",
                expected: st("\(product)"), spec: AnswerSpec(.number),
                steps: [
                    SolutionStep("Иди от соседнего факта.",
                                 b > 2 ? "\(a) × \(b - 1) = \(known), и ещё одно \(a)." : "\(a) × 1 = \(a), и ещё одно \(a).",
                                 why: "\(a) × \(b) — это \(b) раз по \(a). На один раз больше, чем \(a) × \(b - 1).",
                                 ask: "Сколько будет \(a) × \(b - 1)?", answer: "\(a * (b - 1))"),
                    SolutionStep("Прибавляем ещё одно \(a).", "\(a * (b - 1)) + \(a) = \(product).", line: "= \(product)",
                                 check: "\(product) : \(a) = \(b).",
                                 ask: "Сколько будет \(a * (b - 1)) + \(a)?", answer: "\(product)"),
                ])
        }
        return Problem(
            topicID: "g5.table", prompt: "Вычисли", statement: st("\(product) : \(a)"), display: "\(product) : \(a)",
            expected: st("\(b)"), spec: AnswerSpec(.number),
            steps: [
                SolutionStep("Деление — обратное умножению.", "Ищем число, которое при умножении на \(a) даёт \(product).",
                             line: "\(a) × ? = \(product)",
                             why: "\(product) : \(a) — это «сколько раз по \(a) помещается в \(product)».",
                             ask: "На что умножить \(a), чтобы получилось \(product)?", answer: "\(b)"),
                SolutionStep("Записываем ответ.", "\(a) × \(b) = \(product), значит \(product) : \(a) = \(b).",
                             line: "= \(b)", check: "\(b) × \(a) = \(product)."),
            ])
    }

    static let orderOfOperations = TopicDef(
        "g5.order", .five, section: "Натуральные числа", title: "Порядок действий",
        rule: ["Сначала действия в скобках.", "Потом умножение и деление — слева направо.",
               "Последними сложение и вычитание — тоже слева направо."]
    ) { r, ctx in
        let a = r.int(2...9), b = r.int(2...9), c = r.int(2...9), d = r.int(2...5)
        let templates = ctx.easy
            ? ["\(a + 10) + \(b) × \(c)", "\(a * b) − \(b) × \(c > a ? a : c)"]
            : ["(\(a) + \(b)) × \(c) − \(d)", "\(a * d + 20) − \(a) × \(d) + \(b)", "\(c) × (\(a + 10) − \(b)) : \(c)",
               "\(a * b) : \(b) + \(c) × \(d)"]
        let text = r.pick(templates)
        let e = ex(text)
        let value = (try? e.rationalValue()) ?? .zero
        return Problem(topicID: "g5.order", prompt: "Вычисли", statement: .expression(e), display: e.text,
                       expected: st(show(value)), spec: AnswerSpec(.number), steps: arithmeticSteps(e))
    }

    static let powers = TopicDef(
        "g5.powers", .five, section: "Натуральные числа", title: "Степень числа",
        rule: ["aⁿ — это a, умноженное само на себя n раз.", "a² — квадрат, a³ — куб.",
               "В выражении степень считают раньше умножения и сложения."]
    ) { r, ctx in
        let a = r.int(2...(ctx.easy ? 5 : 9)), n = ctx.easy ? 2 : r.int(2...3)
        let b = r.int(2...5)
        let e = ctx.easy ? ex("\(a)^\(n)") : ex("\(a)^\(n) + \(b)^2")
        let value = (try? e.rationalValue()) ?? .zero
        var steps = [SolutionStep("Степень — это умножение одинаковых множителей.",
                                  "\(a)\(n == 2 ? "²" : "³") = " + Array(repeating: "\(a)", count: n).joined(separator: " · "),
                                  why: "Показатель \(n) говорит, сколько раз \(a) стоит множителем.",
                                  whyNot: "\(a)\(n == 2 ? "²" : "³") — это не \(a) · \(n) = \(a * n).")]
        steps += arithmeticSteps(e)
        return Problem(topicID: "g5.powers", prompt: "Вычисли", statement: .expression(e), display: e.text,
                       expected: st(show(value)), spec: AnswerSpec(.number), steps: steps)
    }

    static let remainder = TopicDef(
        "g5.remainder", .five, section: "Натуральные числа", title: "Деление с остатком",
        rule: ["a : b = q (ост. r), если a = b · q + r.", "Остаток всегда меньше делителя.",
               "Ищем наибольшее число, кратное делителю и не больше делимого."]
    ) { r, ctx in
        let b = r.int(3...9), q = r.int(ctx.easy ? 2...5 : 3...12), rem = r.int(1...(b - 1))
        let a = b * q + rem
        return Problem(
            topicID: "g5.remainder", prompt: "Раздели с остатком", statement: st("\(a) : \(b)"), display: "\(a) : \(b)",
            expected: st("\(q) ост. \(rem)"), spec: AnswerSpec(.remainder, divisor: b),
            steps: [
                SolutionStep("Ищем, сколько раз \(b) помещается в \(a).", "\(b) · \(q) = \(b * q), а \(b) · \(q + 1) = \(b * (q + 1)) — уже больше \(a).",
                             line: "\(a) = \(b) · \(q) + \(rem)",
                             why: "Частное — наибольшее число q, при котором \(b) · q не больше \(a).",
                             ask: "Какое наибольшее q, чтобы \(b) · q ≤ \(a)?", answer: "\(q)"),
                SolutionStep("Остаток — то, что не поместилось.", "\(a) − \(b * q) = \(rem).", line: "\(q) ост. \(rem)",
                             whyNot: "Остаток не может быть \(b) или больше — тогда поместился бы ещё один раз.",
                             check: "\(b) · \(q) + \(rem) = \(a).", ask: "Сколько будет \(a) − \(b * q)?", answer: "\(rem)"),
            ])
    }

    static let sameDenominatorAdd = TopicDef(
        "g5.sameAdd", .five, section: "Обыкновенные дроби", title: "Сложение дробей с одинаковым низом",
        rule: ["Низы одинаковые — складываем верхи, низ оставляем.", "Если можно — сокращаем.",
               "Если верх больше низа — выделяем целую часть."]
    ) { r, ctx in
        let b = r.int(ctx.easy ? 3...6 : 5...12)
        let a = r.int(1...(b - 1)), c = r.int(1...(b - 1))
        let (steps, result) = fractionSumSteps(a, b, c, b, minus: false, requireMixed: true)
        return Problem(topicID: "g5.sameAdd", prompt: "Вычисли", statement: st("\(a)/\(b) + \(c)/\(b)"),
                       display: "\(a)/\(b) + \(c)/\(b)", expected: numberAnswer(result, mixed: true),
                       spec: AnswerSpec(.number, requireMixed: true), steps: steps)
    }

    static let sameDenominatorSub = TopicDef(
        "g5.sameSub", .five, section: "Обыкновенные дроби", title: "Вычитание дробей с одинаковым низом",
        rule: ["Низы одинаковые — вычитаем верхи, низ оставляем.", "Если можно — сокращаем."]
    ) { r, ctx in
        let b = r.int(ctx.easy ? 3...6 : 5...12)
        let a = r.int(2...(b - 1)), c = r.int(1...(a - 1))
        let (steps, result) = fractionSumSteps(a, b, c, b, minus: true, requireMixed: true)
        return Problem(topicID: "g5.sameSub", prompt: "Вычисли", statement: st("\(a)/\(b) − \(c)/\(b)"),
                       display: "\(a)/\(b) − \(c)/\(b)", expected: numberAnswer(result, mixed: true),
                       spec: AnswerSpec(.number, requireMixed: true), steps: steps)
    }

    static let wholePart = TopicDef(
        "g5.whole", .five, section: "Обыкновенные дроби", title: "Выделение целой части",
        rule: ["Если верх больше низа, в дроби есть целые.", "Делим верх на низ с остатком: частное — целая часть, остаток — новый верх.",
               "Низ не меняется."]
    ) { r, ctx in
        let b = r.int(ctx.easy ? 2...5 : 3...9)
        var a = r.int((b + 1)...(b * (ctx.easy ? 3 : 5)))
        if a % b == 0 { a += 1 }
        let g = gcd(a % b, b)
        let result = Rational.of(a, b)
        var steps = [SolutionStep(
            "Делим верх на низ с остатком.", "\(a) : \(b) = \(a / b) (ост. \(a % b)).",
            why: "Каждые \(b) частей из \(b) — это одна целая.",
            ask: "Сколько целых раз \(b) помещается в \(a)?", answer: "\(a / b)")]
        steps.append(SolutionStep(
            "Частное — целая часть, остаток — верх, низ тот же.", "\(a)/\(b) = \(a / b) \(a % b)/\(b).",
            line: "= \(a / b) \(a % b)/\(b)",
            whyNot: "Не теряй целую часть: \(a % b)/\(b) без \(a / b) — это меньше единицы.",
            check: "\(a / b) · \(b) + \(a % b) = \(a).", ask: "Какой остаток при делении \(a) на \(b)?", answer: "\(a % b)"))
        if g > 1 { steps += reduceAndWholeSteps(a % b, b, requireMixed: false).map { s in
            var s = s
            s.line = "= \(a / b) \(a % b / g)/\(b / g)"
            return s
        } }
        return Problem(topicID: "g5.whole", prompt: "Выдели целую часть", statement: st("\(a)/\(b)"), display: "\(a)/\(b)",
                       expected: numberAnswer(result, mixed: true), spec: AnswerSpec(.number, requireMixed: true), steps: steps)
    }

    static let toImproper = TopicDef(
        "g5.improper", .five, section: "Обыкновенные дроби", title: "Смешанное число в неправильную дробь",
        rule: ["Целую часть умножаем на низ и прибавляем верх.", "Низ не меняется."]
    ) { r, ctx in
        let b = r.int(ctx.easy ? 2...5 : 3...9), w = r.int(1...(ctx.easy ? 3 : 6))
        var a = r.int(1...(b - 1))
        while gcd(a, b) != 1 { a -= 1 }
        let top = w * b + a
        return Problem(
            topicID: "g5.improper", prompt: "Запиши неправильной дробью", statement: st("\(w) \(a)/\(b)"),
            display: "\(w) \(a)/\(b)", expected: st("\(top)/\(b)"), spec: AnswerSpec(.improperFraction),
            steps: [
                SolutionStep("Целую часть переводим в части.", "\(w) = \(w * b)/\(b).",
                             why: "В одной целой \(b) частей, в \(w) целых — \(w) · \(b) = \(w * b).",
                             ask: "Сколько будет \(w) · \(b)?", answer: "\(w * b)"),
                SolutionStep("Прибавляем верх, низ оставляем.", "\(w * b) + \(a) = \(top).", line: "= \(top)/\(b)",
                             check: "\(top) : \(b) = \(w) (ост. \(a)).", ask: "Сколько будет \(w * b) + \(a)?", answer: "\(top)"),
            ])
    }

    static let mixedSame = TopicDef(
        "g5.mixedSame", .five, section: "Обыкновенные дроби", title: "Смешанные числа с одинаковым низом",
        rule: ["Целые складываем с целыми, дроби — с дробями.", "Если дробь стала больше единицы, переносим целое.",
               "При вычитании, если верх меньше, занимаем одну целую."]
    ) { r, ctx in
        let b = r.int(ctx.easy ? 3...5 : 4...9)
        let w1 = r.int(2...6), w2 = r.int(1...(w1 - 1)), a = r.int(1...(b - 1)), c = r.int(1...(b - 1))
        let minus = !ctx.easy && r.bool()
        let x = try! Rational(w1 * b + a, b), y = try! Rational(w2 * b + c, b)
        let result = minus ? try! x.subtracting(y) : try! x.adding(y)
        let op = minus ? "−" : "+"
        let display = "\(w1) \(a)/\(b) \(op) \(w2) \(c)/\(b)"
        var steps: [SolutionStep] = []
        if minus && a < c {
            steps.append(SolutionStep("Верх меньше — занимаем одну целую.", "\(w1) \(a)/\(b) = \(w1 - 1) \(a + b)/\(b).",
                                      line: "= \(w1 - 1) \(a + b)/\(b) − \(w2) \(c)/\(b)",
                                      why: "Одна целая — это \(b)/\(b). Добавляем её к дроби.",
                                      ask: "Сколько будет \(a) + \(b)?", answer: "\(a + b)"))
            let top = a + b - c, whole = w1 - 1 - w2
            steps.append(SolutionStep("Вычитаем целые и дроби отдельно.", "\(w1 - 1) − \(w2) = \(whole), \(a + b)/\(b) − \(c)/\(b) = \(top)/\(b).",
                                      line: whole == 0 ? "= \(top)/\(b)" : "= \(whole) \(top)/\(b)"))
        } else {
            let whole = minus ? w1 - w2 : w1 + w2
            let top = minus ? a - c : a + c
            steps.append(SolutionStep(minus ? "Вычитаем целые и дроби отдельно." : "Складываем целые и дроби отдельно.",
                                      "\(w1) \(op) \(w2) = \(whole), \(a)/\(b) \(op) \(c)/\(b) = \(top)/\(b).",
                                      line: top == 0 ? "= \(whole)" : (whole == 0 ? "= \(top)/\(b)" : "= \(whole) \(top)/\(b)"),
                                      ask: "Сколько будет \(w1) \(op) \(w2)?", answer: "\(whole)"))
            if top >= b {
                steps.append(SolutionStep("Дробь больше единицы — переносим целое.", "\(top)/\(b) = 1 \(top - b)/\(b).",
                                          line: top == b ? "= \(whole + 1)" : "= \(whole + 1) \(top - b)/\(b)"))
            }
        }
        if !result.isInteger, gcd(result.mixedParts.num, b) > 1 {
            let (w, n, d) = result.mixedParts
            steps.append(SolutionStep("Сокращаем дробную часть.", "Делим верх и низ дробной части на их общий делитель: \(n)/\(d).",
                                      line: w == 0 ? "= \(n)/\(d)" : "= \(w) \(n)/\(d)"))
        }
        return Problem(topicID: "g5.mixedSame", prompt: "Вычисли", statement: st(display), display: display,
                       expected: numberAnswer(result, mixed: true), spec: AnswerSpec(.number, requireMixed: true), steps: steps)
    }

    static let decimalAddSub = TopicDef(
        "g5.decAdd", .five, section: "Десятичные дроби", title: "Сложение и вычитание десятичных",
        rule: ["Пишем запятую под запятой.", "Недостающие знаки после запятой дописываем нулями.",
               "Складываем как целые, запятую ставим под запятыми."]
    ) { r, ctx in
        let a = Rational.of(r.int(11...(ctx.easy ? 99 : 999)), r.pick([10, 100]))
        let b = Rational.of(r.int(1...(ctx.easy ? 99 : 999)), r.pick([10, 100]))
        let minus = r.bool() && a > b
        let result = minus ? try! a.subtracting(b) : try! a.adding(b)
        let op = minus ? "−" : "+"
        let text = "\(show(a, decimal: true)) \(op) \(show(b, decimal: true))"
        return Problem(
            topicID: "g5.decAdd", prompt: "Вычисли", statement: st(text), display: text,
            expected: st(show(result, decimal: true)), spec: AnswerSpec(.decimal),
            steps: [
                SolutionStep("Выравниваем запятые.", "Дописываем нули, чтобы знаков после запятой было поровну.",
                             why: "Складывать можно только одинаковые разряды: десятые с десятыми, сотые с сотыми.",
                             whyNot: "Если выровнять по правому краю, сложатся разные разряды."),
                SolutionStep(minus ? "Вычитаем как целые, запятую ставим под запятыми." : "Складываем как целые, запятую ставим под запятыми.",
                             "\(text) = \(show(result, decimal: true)).", line: "= \(show(result, decimal: true))",
                             check: minus ? "\(show(result, decimal: true)) + \(show(b, decimal: true)) = \(show(a, decimal: true))." : nil,
                             ask: "Сколько будет \(text)?", answer: show(result, decimal: true)),
            ])
    }

    static let decimalMulDiv = TopicDef(
        "g5.decMul", .five, section: "Десятичные дроби", title: "Умножение и деление десятичных",
        rule: ["Умножаем как целые, потом отделяем запятой столько знаков, сколько их у обоих множителей вместе.",
               "Делим на десятичную: переносим запятую в делителе и делимом на одно число знаков вправо."]
    ) { r, ctx in
        if r.bool() {
            let a = Rational.of(r.int(2...(ctx.easy ? 9 : 99)), 10), b = Rational(r.int(2...9))
            let bb = ctx.easy ? b : Rational.of(r.int(2...9), 10)
            let result = try! a.multiplying(bb)
            let text = "\(show(a, decimal: true)) · \(show(bb, decimal: true))"
            let digits = (a.den == 10 ? 1 : 0) + (bb.den == 10 ? 1 : 0)
            let intA = a.num, intB = bb.num
            return Problem(
                topicID: "g5.decMul", prompt: "Вычисли", statement: st(text), display: text,
                expected: st(show(result, decimal: true)), spec: AnswerSpec(.decimal),
                steps: [
                    SolutionStep("Умножаем как целые.", "\(intA) · \(intB) = \(intA * intB).",
                                 ask: "Сколько будет \(intA) · \(intB)?", answer: "\(intA * intB)"),
                    SolutionStep("Отделяем запятой знаки.", "У множителей вместе знаков после запятой: \(digits).",
                                 line: "= \(show(result, decimal: true))",
                                 why: "Каждая десятая — это деление на 10; две десятые — на 100.",
                                 check: "Оценка: \(show(a, decimal: true)) ≈ \(a.floor), ответ должен быть того же порядка."),
                ])
        }
        let b = r.int(2...9), q = Rational.of(r.int(2...(ctx.easy ? 9 : 99)), 10)
        let a = try! q.multiplying(Rational(b))
        let text = "\(show(a, decimal: true)) : \(b)"
        return Problem(
            topicID: "g5.decMul", prompt: "Вычисли", statement: st(text), display: text,
            expected: st(show(q, decimal: true)), spec: AnswerSpec(.decimal),
            steps: [
                SolutionStep("Делим как целые, запятую ставим, когда дошли до неё в делимом.",
                             "\(show(a, decimal: true)) : \(b) = \(show(q, decimal: true)).", line: "= \(show(q, decimal: true))",
                             check: "\(show(q, decimal: true)) · \(b) = \(show(a, decimal: true)).",
                             ask: "Сколько будет \(text)?", answer: show(q, decimal: true)),
            ])
    }

    static let simpleEquations = TopicDef(
        "g5.eq", .five, section: "Уравнения", title: "Простые уравнения",
        rule: ["Неизвестное слагаемое = сумма − известное слагаемое.", "Неизвестное уменьшаемое = разность + вычитаемое.",
               "Неизвестный множитель = произведение : известный множитель.", "Проверка: подставь ответ в уравнение."]
    ) { r, ctx in
        let kind = r.int(0...3)
        let k = r.int(2...9)
        // x — всегда корень уравнения; числа в условии подбираются под него.
        let x = kind == 3 ? k * r.int(2...(ctx.easy ? 5 : 12)) : r.int(5...(ctx.easy ? 15 : 40))
        let a = r.int(2...min(x - 1, ctx.easy ? 9 : 20))
        let (eqText, rule, detail, expr): (String, String, String, String)
        switch kind {
        case 0:
            (eqText, rule, detail, expr) = ("x + \(a) = \(x + a)", "Неизвестное слагаемое: из суммы вычитаем известное.",
                                            "x = \(x + a) − \(a)", "\(x + a) − \(a)")
        case 1:
            (eqText, rule, detail, expr) = ("x − \(a) = \(x - a)", "Неизвестное уменьшаемое: к разности прибавляем вычитаемое.",
                                            "x = \(x - a) + \(a)", "\(x - a) + \(a)")
        case 2:
            (eqText, rule, detail, expr) = ("\(k)x = \(k * x)", "Неизвестный множитель: произведение делим на известный множитель.",
                                            "x = \(k * x) : \(k)", "\(k * x) : \(k)")
        default:
            (eqText, rule, detail, expr) = ("x : \(k) = \(x / k)", "Неизвестное делимое: частное умножаем на делитель.",
                                            "x = \(x / k) · \(k)", "\(x / k) · \(k)")
        }
        return Problem(
            topicID: "g5.eq", prompt: "Реши уравнение", statement: st(eqText), display: eqText,
            expected: st("x = \(x)"), spec: AnswerSpec(.roots),
            steps: [
                SolutionStep(rule, detail + ".", line: detail, why: "Действие, обратное тому, что сделали с x.",
                             ask: "Сколько будет \(expr)?", answer: "\(x)"),
                SolutionStep("Считаем.", "x = \(x).", line: "x = \(x)", check: "Подставим: \(eqText.replacingX(with: x))."),
            ])
    }

    static let percentOf = TopicDef(
        "g5.percent", .five, section: "Проценты", title: "Процент от числа",
        rule: ["1% — это одна сотая часть числа.", "p% от N = N : 100 · p."]
    ) { r, ctx in
        let p = r.pick(ctx.easy ? [10, 20, 25, 50] : [5, 10, 15, 20, 25, 30, 40, 60, 75, 80])
        let n = 20 * r.int(ctx.easy ? 1...10 : 1...50)
        let result = Rational.of(n * p, 100)
        return Problem(
            topicID: "g5.percent", prompt: "Найди \(p)% от \(n)", statement: st("\(p)% · \(n)"), display: "\(p)% от \(n)",
            expected: st(show(result, decimal: true)), spec: AnswerSpec(.number),
            steps: [
                SolutionStep("Находим 1%.", "\(n) : 100 = \(show(Rational.of(n, 100), decimal: true)).",
                             why: "Процент — сотая часть, поэтому делим на 100.",
                             ask: "Сколько будет \(n) : 100?", answer: show(Rational.of(n, 100), decimal: true)),
                SolutionStep("Умножаем на число процентов.", "\(show(Rational.of(n, 100), decimal: true)) · \(p) = \(show(result, decimal: true)).",
                             line: "= \(show(result, decimal: true))",
                             check: "\(p)% — это \(show(Rational.of(p, 100))) числа: \(n) · \(show(Rational.of(p, 100))) = \(show(result, decimal: true)).",
                             ask: "Сколько будет \(show(Rational.of(n, 100), decimal: true)) · \(p)?", answer: show(result, decimal: true)),
            ])
    }
}

extension String {
    /// «x + 3 = 10» → «7 + 3 = 10» — для строки проверки.
    func replacingX(with v: Int) -> String {
        var out = ""
        let chars = Array(self)
        for (i, ch) in chars.enumerated() {
            if ch == "x" {
                let prevIsDigit = i > 0 && chars[i - 1].isNumber
                out += prevIsDigit ? " · \(v)" : "\(v)"
            } else {
                out.append(ch)
            }
        }
        return out
    }
}
