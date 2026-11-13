/// Ошибки точной арифметики и разбора записи.
public enum MathError: Error, Equatable, Sendable {
    case overflow
    case divisionByZero
    case undefined(String)
    case unsupported(String)
    case syntax(String)
}

/// Точная дробь: пара целых, знаменатель всегда положительный, дробь всегда сокращена.
/// Double не используется: проверка ответа должна быть точной.
public struct Rational: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let num: Int
    public let den: Int

    public static let zero = Rational(0)
    public static let one = Rational(1)

    public init(_ value: Int) {
        num = value
        den = 1
    }

    /// Создаёт и сокращает дробь. Знаменатель 0 — ошибка.
    public init(_ n: Int, _ d: Int) throws {
        guard d != 0 else { throw MathError.divisionByZero }
        guard n != Int.min, d != Int.min else { throw MathError.overflow }
        let g = gcd(n, d)
        let sign = d < 0 ? -1 : 1
        num = sign * n / g
        den = sign * d / g
    }

    /// Только для заведомо корректных литералов (тесты, генераторы).
    public static func of(_ n: Int, _ d: Int = 1) -> Rational {
        // swiftlint:disable:next force_try
        try! Rational(n, d)
    }

    public var isInteger: Bool { den == 1 }
    public var isZero: Bool { num == 0 }
    public var isNegative: Bool { num < 0 }
    public var sign: Int { num == 0 ? 0 : (num > 0 ? 1 : -1) }

    public func adding(_ o: Rational) throws -> Rational {
        let g = gcd(den, o.den)
        let l = try mul(den / g, o.den)
        let a = try mul(num, l / den)
        let b = try mul(o.num, l / o.den)
        return try Rational(add(a, b), l)
    }

    public func subtracting(_ o: Rational) throws -> Rational {
        try adding(o.negated())
    }

    public func multiplying(_ o: Rational) throws -> Rational {
        // Сокращаем крест-накрест до умножения, чтобы реже переполняться.
        let g1 = gcd(num, o.den), g2 = gcd(o.num, den)
        return try Rational(mul(num / g1, o.num / g2), mul(den / g2, o.den / g1))
    }

    public func dividing(_ o: Rational) throws -> Rational {
        guard !o.isZero else { throw MathError.divisionByZero }
        return try multiplying(o.reciprocal())
    }

    public func negated() -> Rational { Rational(raw: -num, den) }

    public func reciprocal() throws -> Rational {
        try Rational(den, num)
    }

    public func power(_ e: Int) throws -> Rational {
        guard abs(e) <= 64 else { throw MathError.overflow }
        if e < 0 { return try reciprocal().power(-e) }
        var result = Rational.one
        for _ in 0..<e { result = try result.multiplying(self) }
        return result
    }

    public var absolute: Rational { Rational(raw: abs(num), den) }

    /// Целая часть вниз (как floor).
    public var floor: Int {
        let q = num / den
        return (num % den != 0 && num < 0) ? q - 1 : q
    }

    /// Смешанное число: целая часть, числитель и знаменатель дробной части (для |x|).
    public var mixedParts: (whole: Int, num: Int, den: Int) {
        let a = abs(num)
        return (a / den, a % den, den)
    }

    /// Конечная десятичная дробь: знаменатель раскладывается только на 2 и 5.
    public var isTerminatingDecimal: Bool {
        var d = den
        while d % 2 == 0 { d /= 2 }
        while d % 5 == 0 { d /= 5 }
        return d == 1
    }

    /// Запись десятичной дробью с запятой, если она конечна.
    public var decimalString: String? {
        guard isTerminatingDecimal else { return nil }
        if isInteger { return String(num) }
        var digits = 0
        var scaled = self
        while !scaled.isInteger && digits < 18 {
            guard let next = try? scaled.multiplying(Rational(10)) else { return nil }
            scaled = next
            digits += 1
        }
        let s = String(abs(scaled.num))
        let padded = String(repeating: "0", count: max(0, digits + 1 - s.count)) + s
        let cut = padded.index(padded.endIndex, offsetBy: -digits)
        return (num < 0 ? "-" : "") + padded[..<cut] + "," + padded[cut...]
    }

    public var description: String {
        den == 1 ? String(num) : "\(num)/\(den)"
    }

    public static func < (a: Rational, b: Rational) -> Bool {
        // Сравнение через вычитание: точное и без переполнения на типичных числах.
        guard let d = try? a.subtracting(b) else {
            return Double(a.num) / Double(a.den) < Double(b.num) / Double(b.den)
        }
        return d.num < 0
    }

    private init(raw n: Int, _ d: Int) {
        num = n
        den = d
    }
}

// MARK: - Целочисленные помощники

public func gcd(_ a: Int, _ b: Int) -> Int {
    var x = abs(a), y = abs(b)
    while y != 0 { (x, y) = (y, x % y) }
    return x == 0 ? 1 : x
}

public func lcm(_ a: Int, _ b: Int) throws -> Int {
    if a == 0 || b == 0 { return 0 }
    return abs(try mul(a / gcd(a, b), b))
}

func mul(_ a: Int, _ b: Int) throws -> Int {
    let (r, o) = a.multipliedReportingOverflow(by: b)
    if o { throw MathError.overflow }
    return r
}

func add(_ a: Int, _ b: Int) throws -> Int {
    let (r, o) = a.addingReportingOverflow(b)
    if o { throw MathError.overflow }
    return r
}

/// Разложение на простые множители (по возрастанию, с повторами).
public func primeFactors(_ n: Int) -> [Int] {
    var n = abs(n)
    var result: [Int] = []
    var p = 2
    while p * p <= n {
        while n % p == 0 {
            result.append(p)
            n /= p
        }
        p += p == 2 ? 1 : 2
    }
    if n > 1 { result.append(n) }
    return result
}

public func isPrime(_ n: Int) -> Bool {
    n >= 2 && primeFactors(n) == [n]
}

/// n = s² · k, где k свободно от квадратов. Нужно для упрощения корней.
public func squareFree(_ n: Int) -> (outside: Int, inside: Int) {
    var outside = 1, inside = 1
    var counts: [Int: Int] = [:]
    for p in primeFactors(n) { counts[p, default: 0] += 1 }
    for (p, c) in counts {
        for _ in 0..<(c / 2) { outside *= p }
        if c % 2 == 1 { inside *= p }
    }
    return (outside, inside)
}
