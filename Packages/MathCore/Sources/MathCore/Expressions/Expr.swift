/// Дерево выражения. Сохраняет форму записи (дробь, смешанное число, десятичная),
/// потому что проверка «простейшего вида» и распознавание ошибок смотрят на форму, а не только на значение.
public indirect enum Expr: Hashable, Sendable {
    case integer(Int)
    /// Десятичная дробь: точное значение и как её написали («0,25»).
    case decimal(Rational, String)
    /// Дробь «столбиком». annotation — дополнительный множитель, написанный над дробью («×2»).
    case fraction(Expr, Expr, annotation: Int?)
    /// Смешанное число: целая часть, числитель, знаменатель.
    case mixed(Int, Int, Int)
    case variable(String)
    case add(Expr, Expr)
    case sub(Expr, Expr)
    case mul(Expr, Expr)
    /// Деление знаком «:» или «÷».
    case div(Expr, Expr)
    case neg(Expr)
    case pow(Expr, Expr)
    case sqrt(Expr)
    case abs(Expr)
    /// a% = a/100.
    case percent(Expr)
    /// Скобки. Значение не меняют, но нужны для распознавания ошибок вида «−(a + b) = −a + b».
    case group(Expr)

    public static func frac(_ a: Int, _ b: Int) -> Expr {
        .fraction(.integer(a), .integer(b), annotation: nil)
    }

    public static func int(_ a: Int) -> Expr {
        a < 0 ? .neg(.integer(-a)) : .integer(a)
    }

    /// Число в «школьной» записи: целое, дробь или минус перед дробью.
    public static func number(_ r: Rational) -> Expr {
        if r.isInteger { return .int(r.num) }
        let f = Expr.frac(Swift.abs(r.num), r.den)
        return r.num < 0 ? .neg(f) : f
    }

    /// Без внешних скобок.
    public var unwrapped: Expr {
        if case .group(let e) = self { return e.unwrapped }
        return self
    }

    public var children: [Expr] {
        switch self {
        case .integer, .decimal, .mixed, .variable: return []
        case .fraction(let a, let b, _), .add(let a, let b), .sub(let a, let b),
             .mul(let a, let b), .div(let a, let b), .pow(let a, let b):
            return [a, b]
        case .neg(let a), .sqrt(let a), .abs(let a), .percent(let a), .group(let a):
            return [a]
        }
    }

    /// Все узлы дерева (сам узел первым).
    public var allNodes: [Expr] {
        [self] + children.flatMap(\.allNodes)
    }

    public var variables: Set<String> {
        if case .variable(let v) = self { return [v] }
        return children.reduce(into: Set<String>()) { $0.formUnion($1.variables) }
    }

    public var hasVariables: Bool { !variables.isEmpty }

    /// Слагаемые суммы с учётом знака: a − b + c → [a, −b, c].
    public var terms: [Expr] {
        switch self {
        case .add(let a, let b): return a.terms + b.terms
        case .sub(let a, let b): return a.terms + b.terms.map { $0.negatedTerm }
        case .group(let e): return e.terms
        default: return [self]
        }
    }

    var negatedTerm: Expr {
        if case .neg(let e) = self { return e }
        return .neg(self)
    }

    /// Множители произведения: 2·x·(x + 1) → [2, x, (x + 1)].
    public var factors: [Expr] {
        switch self {
        case .mul(let a, let b): return a.factors + b.factors
        default: return [self]
        }
    }

    /// Заменяет узел по пути (индексы детей от корня).
    public func replacing(at path: [Int], with new: Expr) -> Expr {
        guard let first = path.first else { return new }
        let rest = Array(path.dropFirst())
        func r(_ e: Expr) -> Expr { e.replacing(at: rest, with: new) }
        switch self {
        case .fraction(let a, let b, let ann):
            return first == 0 ? .fraction(r(a), b, annotation: ann) : .fraction(a, r(b), annotation: ann)
        case .add(let a, let b): return first == 0 ? .add(r(a), b) : .add(a, r(b))
        case .sub(let a, let b): return first == 0 ? .sub(r(a), b) : .sub(a, r(b))
        case .mul(let a, let b): return first == 0 ? .mul(r(a), b) : .mul(a, r(b))
        case .div(let a, let b): return first == 0 ? .div(r(a), b) : .div(a, r(b))
        case .pow(let a, let b): return first == 0 ? .pow(r(a), b) : .pow(a, r(b))
        case .neg(let a): return .neg(r(a))
        case .sqrt(let a): return .sqrt(r(a))
        case .abs(let a): return .abs(r(a))
        case .percent(let a): return .percent(r(a))
        case .group(let a): return .group(r(a))
        default: return self
        }
    }

    /// Пути ко всем узлам — для перебора «неправильных» преобразований.
    public var allPaths: [[Int]] {
        [[]] + children.enumerated().flatMap { i, c in c.allPaths.map { [i] + $0 } }
    }

    public func node(at path: [Int]) -> Expr {
        guard let first = path.first, first < children.count else { return self }
        return children[first].node(at: Array(path.dropFirst()))
    }
}

/// Знак отношения.
public enum Relation: String, Hashable, Sendable, CaseIterable {
    case eq = "="
    case lt = "<"
    case gt = ">"
    case le = "≤"
    case ge = "≥"
    case ne = "≠"

    /// Знак после умножения обеих частей на отрицательное число.
    public var flipped: Relation {
        switch self {
        case .lt: return .gt
        case .gt: return .lt
        case .le: return .ge
        case .ge: return .le
        default: return self
        }
    }

    public var isInequality: Bool { self != .eq && self != .ne }
}

/// Промежуток в записи ответа: (a; b], [a; +∞). nil — бесконечность.
public struct IntervalLiteral: Hashable, Sendable {
    public var low: Expr?
    public var lowClosed: Bool
    public var high: Expr?
    public var highClosed: Bool

    public init(low: Expr?, lowClosed: Bool, high: Expr?, highClosed: Bool) {
        self.low = low
        self.lowClosed = lowClosed
        self.high = high
        self.highClosed = highClosed
    }
}

/// Строка записи целиком.
public indirect enum Statement: Hashable, Sendable {
    /// Выражение: «1/3 + 1/6».
    case expression(Expr)
    /// Продолжение цепочки: «= 2/6 + 1/6».
    case continuation(Expr)
    /// Цепочка равенств без переменных: «1/3 + 1/6 = 2/6 + 1/6 = 1/2».
    case chain([Expr])
    /// Уравнение или неравенство: «2x + 1 = 7», «x ≤ 3».
    case relation(Expr, Relation, Expr)
    /// «x₁ = 2 или x₂ = 3».
    case either([Statement])
    /// Система: строки через «;» или фигурная скобка.
    case system([Statement])
    /// Промежутки через ∪, или точка (x; y) для систем.
    case intervals([IntervalLiteral])
    case noSolution
    case anyNumber
    /// Деление с остатком: «7 ост. 2».
    case remainder(Expr, Expr)

    public var expressions: [Expr] {
        switch self {
        case .expression(let e), .continuation(let e): return [e]
        case .chain(let es): return es
        case .relation(let a, _, let b): return [a, b]
        case .either(let ss), .system(let ss): return ss.flatMap(\.expressions)
        case .intervals(let ivs): return ivs.flatMap { [$0.low, $0.high].compactMap { $0 } }
        case .remainder(let a, let b): return [a, b]
        case .noSolution, .anyNumber: return []
        }
    }

    public var variables: Set<String> {
        expressions.reduce(into: Set<String>()) { $0.formUnion($1.variables) }
    }
}
