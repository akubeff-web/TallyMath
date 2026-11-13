/// Разбор записи в дерево. Понимает то, что пишет редактор и что удобно набирать в тестах:
/// «1/3 + 1/6», «{x+1}/{x−1}», «2 1/3», «0,25», «x² − 5x + 6 = 0», «√12», «|−3|», «15%»,
/// «x₁ = 2 или x₂ = 3», «(−∞; 2]», «нет решений», «любое число», «7 ост. 2», «2x + y = 5; x − y = 1».
public enum Parser {
    public static func statement(_ text: String) throws -> Statement {
        // «x = (5 ± 1)/2» — это два корня сразу.
        if text.contains("±") {
            let plus = try statement(String(text.map { $0 == "±" ? "+" : $0 }))
            let minus = try statement(String(text.map { $0 == "±" ? "−" : $0 }))
            return .either([plus, minus])
        }
        var p = try State(tokens: Tokenizer.tokenize(text))
        let s = try p.parseTop()
        guard p.atEnd else { throw MathError.syntax("лишние символы: \(p.peek.text)") }
        return s
    }

    public static func expression(_ text: String) throws -> Expr {
        var p = try State(tokens: Tokenizer.tokenize(text))
        let e = try p.parseExpr()
        guard p.atEnd else { throw MathError.syntax("лишние символы: \(p.peek.text)") }
        return e
    }
}

// MARK: - Токены

struct Token: Equatable {
    enum Kind: Equatable {
        case number      // «12», «0,25»
        case variable    // одна латинская буква, возможно с индексом: «x», «x1»
        case word        // русское слово: «или», «ост», «нет», «решений», «любое», «число»
        case symbol      // операторы и скобки
        case end
    }

    var kind: Kind
    var text: String
    /// Перед токеном был пробел — нужно, чтобы отличить «2 1/3» от «21/3».
    var spaceBefore = false
}

enum Tokenizer {
    static let superscripts: [Character: Character] = [
        "⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5",
        "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9", "⁻": "-",
    ]
    static let subscripts: [Character: Character] = [
        "₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5",
        "₆": "6", "₇": "7", "₈": "8", "₉": "9",
    ]

    static func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(input)
        var i = 0
        var space = false
        func push(_ k: Token.Kind, _ t: String) {
            tokens.append(Token(kind: k, text: t, spaceBefore: space))
            space = false
        }
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "\u{00A0}" || c == "\t" || c == "\n" {
                space = true
                i += 1
                continue
            }
            if c.isNumber && c.isASCII {
                var s = String(c)
                i += 1
                while i < chars.count {
                    let d = chars[i]
                    if d.isASCII && d.isNumber {
                        s.append(d)
                        i += 1
                    } else if (d == "," || d == "."), i + 1 < chars.count, chars[i + 1].isASCII, chars[i + 1].isNumber,
                              !s.contains(",") {
                        s.append(",")
                        i += 1
                    } else { break }
                }
                push(.number, s)
                continue
            }
            if let _ = superscripts[c] {
                // «x²» → x ^ (2), «10⁻³» → 10 ^ (−3)
                var s = ""
                while i < chars.count, let d = superscripts[chars[i]] {
                    s.append(d)
                    i += 1
                }
                push(.symbol, "^")
                push(.symbol, "(")
                if s.hasPrefix("-") {
                    push(.symbol, "-")
                    s.removeFirst()
                }
                push(.number, s)
                push(.symbol, ")")
                continue
            }
            if c.isLetter && c.isASCII {
                var name = String(c)
                i += 1
                // Индекс: x₁ или x_1.
                while i < chars.count, let d = subscripts[chars[i]] {
                    name.append(d)
                    i += 1
                }
                push(.variable, name)
                continue
            }
            if c.isLetter {
                var w = ""
                while i < chars.count, chars[i].isLetter, !chars[i].isASCII {
                    w.append(chars[i])
                    i += 1
                }
                if i < chars.count, chars[i] == "." { i += 1 }  // «ост.»
                push(.word, w.lowercased())
                continue
            }
            // Двухсимвольные знаки.
            if i + 1 < chars.count {
                let two = String([c, chars[i + 1]])
                let map = ["<=": "≤", ">=": "≥", "!=": "≠", "+∞": "∞"]
                if let m = map[two] {
                    push(.symbol, m)
                    i += 2
                    continue
                }
            }
            let normalized: [Character: String] = [
                "−": "-", "–": "-", "*": "×", "·": "×", "⋅": "×", "÷": ":",
            ]
            if let n = normalized[c] {
                push(.symbol, n)
            } else if "+-×:/^()[]{}|%=<>≤≥≠;√∪∞∈".contains(c) {
                push(.symbol, String(c))
            } else {
                throw MathError.syntax("непонятный символ «\(c)»")
            }
            i += 1
        }
        tokens.append(Token(kind: .end, text: ""))
        return tokens
    }
}

// MARK: - Разбор

private struct State {
    var tokens: [Token]
    var pos = 0
    /// Глубина «|…|»: внутри модуля «|» закрывает, а не открывает.
    var absDepth = 0

    init(tokens: [Token]) throws { self.tokens = tokens }

    var peek: Token { tokens[pos] }
    var atEnd: Bool { peek.kind == .end }

    func peek(_ k: Int) -> Token { tokens[min(pos + k, tokens.count - 1)] }

    mutating func next() -> Token {
        let t = tokens[pos]
        if pos < tokens.count - 1 { pos += 1 }
        return t
    }

    func isSymbol(_ s: String) -> Bool { peek.kind == .symbol && peek.text == s }
    func isWord(_ s: String) -> Bool { peek.kind == .word && peek.text == s }

    mutating func expect(_ s: String) throws {
        guard isSymbol(s) else { throw MathError.syntax("ожидался «\(s)»") }
        _ = next()
    }

    // statement := part (';' part)*
    mutating func parseTop() throws -> Statement {
        var parts = [try parseEither()]
        while isSymbol(";") {
            _ = next()
            if atEnd { break }
            parts.append(try parseEither())
        }
        return parts.count == 1 ? parts[0] : .system(parts)
    }

    mutating func parseEither() throws -> Statement {
        var parts = [try parseSingle()]
        while isWord("или") {
            _ = next()
            parts.append(try parseSingle())
        }
        return parts.count == 1 ? parts[0] : .either(parts)
    }

    mutating func parseSingle() throws -> Statement {
        if isWord("нет") {
            _ = next()
            if isWord("решений") || isWord("корней") { _ = next() }
            return .noSolution
        }
        if isWord("любое") {
            _ = next()
            if isWord("число") { _ = next() }
            return .anyNumber
        }
        // «x ∈ (…)» — переменную перед ∈ пропускаем.
        if peek.kind == .variable, peek(1).text == "∈" {
            _ = next()
            _ = next()
            return try parseIntervals()
        }
        if looksLikeInterval() { return try parseIntervals() }
        if isSymbol("=") {
            _ = next()
            return .continuation(try parseExpr())
        }
        let first = try parseExpr()
        if isWord("ост") {
            _ = next()
            return .remainder(first, try parseExpr())
        }
        var parts = [first]
        var rels: [Relation] = []
        while peek.kind == .symbol, let r = Relation(rawValue: peek.text) {
            _ = next()
            rels.append(r)
            parts.append(try parseExpr())
        }
        if rels.isEmpty { return .expression(first) }
        if rels.count == 1 { return .relation(parts[0], rels[0], parts[1]) }
        // Цепочка равенств без переменных — это шаги вычисления.
        if rels.allSatisfy({ $0 == .eq }) { return .chain(parts) }
        // Двойное неравенство «1 < x ≤ 5» → система двух неравенств.
        var sys: [Statement] = []
        for (i, r) in rels.enumerated() { sys.append(.relation(parts[i], r, parts[i + 1])) }
        return .system(sys)
    }

    /// «(» или «[» с «;» на первом уровне — это промежуток или точка.
    func looksLikeInterval() -> Bool {
        guard isSymbol("(") || isSymbol("[") else { return false }
        var depth = 0
        var k = pos
        while k < tokens.count {
            let t = tokens[k]
            if t.kind == .symbol {
                if t.text == "(" || t.text == "[" || t.text == "{" { depth += 1 }
                if t.text == ")" || t.text == "]" || t.text == "}" {
                    depth -= 1
                    if depth == 0 { return false }
                }
                if t.text == ";" && depth == 1 { return true }
            }
            if t.kind == .end { return false }
            k += 1
        }
        return false
    }

    mutating func parseIntervals() throws -> Statement {
        var list = [try parseInterval()]
        while isSymbol("∪") {
            _ = next()
            list.append(try parseInterval())
        }
        return .intervals(list)
    }

    mutating func parseInterval() throws -> IntervalLiteral {
        let open = next()
        guard open.text == "(" || open.text == "[" else { throw MathError.syntax("ожидалась скобка промежутка") }
        let low = try parseEndpoint()
        try expect(";")
        let high = try parseEndpoint()
        let close = next()
        guard close.text == ")" || close.text == "]" else { throw MathError.syntax("ожидалась скобка промежутка") }
        return IntervalLiteral(low: low, lowClosed: open.text == "[", high: high, highClosed: close.text == "]")
    }

    /// Конец промежутка: число или ±∞ (nil).
    mutating func parseEndpoint() throws -> Expr? {
        if isSymbol("∞") { _ = next(); return nil }
        if (isSymbol("-") || isSymbol("+")), peek(1).text == "∞" {
            _ = next(); _ = next()
            return nil
        }
        return try parseExpr()
    }

    // expr := term (('+'|'-') term)*
    mutating func parseExpr() throws -> Expr {
        var left = try parseTerm()
        while isSymbol("+") || isSymbol("-") {
            let op = next().text
            let right = try parseTerm()
            left = op == "+" ? .add(left, right) : .sub(left, right)
        }
        return left
    }

    // term := unary (op unary | неявное умножение)*
    mutating func parseTerm() throws -> Expr {
        var left = try parseUnary()
        while true {
            if isSymbol("×") {
                _ = next()
                left = .mul(left, try parseUnary())
            } else if isSymbol(":") {
                _ = next()
                left = .div(left, try parseUnary())
            } else if isSymbol("/") {
                _ = next()
                let right = try parseUnary()
                // «1/3» из двух целых — это дробь, остальное — деление.
                if case .integer = left, case .integer = right {
                    left = .fraction(left, right, annotation: try parseAnnotation())
                } else {
                    left = .div(left, right)
                }
            } else if startsImplicitFactor() {
                left = .mul(left, try parsePower())
            } else {
                return left
            }
        }
    }

    func startsImplicitFactor() -> Bool {
        if peek.kind == .variable { return true }
        if peek.kind == .symbol {
            return ["(", "√", "{"].contains(peek.text) || (peek.text == "|" && absDepth == 0)
        }
        return false
    }

    mutating func parseUnary() throws -> Expr {
        if isSymbol("-") {
            _ = next()
            return .neg(try parseUnary())
        }
        if isSymbol("+") {
            _ = next()
            return try parseUnary()
        }
        return try parsePower()
    }

    mutating func parsePower() throws -> Expr {
        let base = try parsePostfix()
        if isSymbol("^") {
            _ = next()
            var exponent = try parseUnaryPowerOperand()
            // «x²» приходит как x^(2): скобки вокруг числа не нужны.
            if case .group(let inner) = exponent {
                switch inner {
                case .integer, .neg(.integer): exponent = inner
                default: break
                }
            }
            return .pow(base, exponent)
        }
        return base
    }

    /// Показатель: «2», «-3», «(n+1)».
    mutating func parseUnaryPowerOperand() throws -> Expr {
        if isSymbol("-") {
            _ = next()
            return .neg(try parsePostfix())
        }
        return try parsePostfix()
    }

    mutating func parsePostfix() throws -> Expr {
        var e = try parsePrimary()
        while isSymbol("%") {
            _ = next()
            e = .percent(e)
        }
        return e
    }

    mutating func parsePrimary() throws -> Expr {
        let t = peek
        switch t.kind {
        case .number:
            _ = next()
            let n = try number(t.text)
            // «2 1/3» — смешанное число.
            if case .integer(let whole) = n, peek.kind == .number, peek.spaceBefore,
               peek(1).text == "/", peek(2).kind == .number,
               let a = Int(peek.text), let b = Int(peek(2).text) {
                _ = next(); _ = next(); _ = next()
                return .mixed(whole, a, b)
            }
            // «2{1}/{3}» — смешанное число из редактора.
            if case .integer(let whole) = n, isSymbol("{") {
                let save = pos
                if case .fraction(.integer(let a), .integer(let b), _) = try parseBraced() {
                    return .mixed(whole, a, b)
                }
                pos = save
            }
            return n
        case .variable:
            _ = next()
            return .variable(t.text)
        case .symbol:
            switch t.text {
            case "(":
                _ = next()
                let e = try parseExpr()
                try expect(")")
                return .group(e)
            case "[":
                _ = next()
                let e = try parseExpr()
                try expect("]")
                return .group(e)
            case "{":
                return try parseBraced()
            case "√":
                _ = next()
                return .sqrt(try parsePostfix())
            case "|":
                _ = next()
                absDepth += 1
                let e = try parseExpr()
                absDepth -= 1
                try expect("|")
                return .abs(e)
            default:
                throw MathError.syntax("неожиданный знак «\(t.text)»")
            }
        case .word:
            throw MathError.syntax("неожиданное слово «\(t.text)»")
        case .end:
            throw MathError.syntax("запись оборвалась")
        }
    }

    /// «{a}/{b}» — дробь из редактора, «{a}» — просто группа.
    mutating func parseBraced() throws -> Expr {
        try expect("{")
        let top = try parseExpr()
        try expect("}")
        guard isSymbol("/"), peek(1).text == "{" else { return .group(top) }
        _ = next()
        try expect("{")
        let bottom = try parseExpr()
        try expect("}")
        return .fraction(top, bottom, annotation: try parseAnnotation())
    }

    /// «[×2]» сразу после дроби — дополнительный множитель.
    mutating func parseAnnotation() throws -> Int? {
        guard isSymbol("["), peek(1).text == "×", peek(2).kind == .number, peek(3).text == "]",
              let k = Int(peek(2).text) else { return nil }
        _ = next(); _ = next(); _ = next(); _ = next()
        return k
    }

    func number(_ text: String) throws -> Expr {
        if text.contains(",") {
            let parts = text.split(separator: ",")
            let digits = parts.count > 1 ? parts[1].count : 0
            guard digits <= 12, let all = Int(String(text.filter { $0 != "," })) else {
                throw MathError.overflow
            }
            var d = 1
            for _ in 0..<digits { d *= 10 }
            return .decimal(try Rational(all, d), text)
        }
        guard text.count <= 15, let v = Int(text) else { throw MathError.overflow }
        return .integer(v)
    }
}
