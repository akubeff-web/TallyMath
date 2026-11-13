/// Ответ на вопрос шага (уровень 3): «Какой общий низ?» → «12», «Разложи 36» → «2 · 2 · 3 · 3», «x = 3».
public enum StepAnswer {
    public static func check(_ input: String, expected: String) -> LineStatus {
        let squeeze = { (s: String) in String(s.filter { !$0.isWhitespace }).replacingMinus }
        if squeeze(input) == squeeze(expected) { return .correct }
        guard let a = try? Parser.statement(input) else { return .unverifiable("не понял запись") }
        guard let b = try? Parser.statement(expected) else { return .unverifiable("не понял ожидаемый ответ") }
        switch (a, b) {
        case (.expression(let x), .expression(let y)):
            guard let eq = equivalent(x, y) else { return .unverifiable("не получилось сравнить") }
            if eq, let issue = Simplest.issue(a, spec: AnswerSpec(.number)), !y.hasVariables { return .correctNotSimplest(issue) }
            return eq ? .correct : .wrong(nil)
        default:
            guard let sa = try? Solver.solve(a), let sb = try? Solver.solve(b) else { return .unverifiable("не получилось сравнить") }
            return sa == sb ? .correct : .wrong(nil)
        }
    }
}
