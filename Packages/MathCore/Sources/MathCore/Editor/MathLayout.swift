/// Разметка записи для отрисовки: текст, дроби «столбиком», показатели и корни.
/// Работает прямо по тексту, поэтому показывает запись ровно так, как её написали.
public indirect enum MathBox: Hashable, Sendable {
    case text(String)
    case fraction([MathBox], [MathBox], annotation: String?)
    case sup([MathBox])
    case sqrt([MathBox])
}

public enum MathLayout {
    public static func layout(_ text: String) -> [MathBox] {
        var p = Scanner(chars: Array(text))
        return p.parse(until: nil)
    }

    private struct Scanner {
        let chars: [Character]
        var i = 0

        mutating func parse(until end: Character?) -> [MathBox] {
            var out: [MathBox] = []
            var buffer = ""
            func flush() {
                if !buffer.isEmpty { out.append(.text(buffer)); buffer = "" }
            }
            while i < chars.count {
                let c = chars[i]
                if let end, c == end { break }
                if c == "{" {
                    let top = readGroup(open: "{", close: "}")
                    if i + 1 < chars.count, chars[i] == "/", chars[i + 1] == "{" {
                        i += 1
                        let bottom = readGroup(open: "{", close: "}")
                        flush()
                        out.append(.fraction(MathLayout.layout(top), MathLayout.layout(bottom), annotation: readAnnotation()))
                    } else {
                        buffer += top
                    }
                    continue
                }
                if c.isNumber, !(buffer.last.map { $0.isNumber || $0 == "," } ?? false),
                   let (a, b, len) = plainFraction(at: i) {
                    i += len
                    flush()
                    out.append(.fraction([.text(a)], [.text(b)], annotation: readAnnotation()))
                    continue
                }
                if c == "^" {
                    i += 1
                    flush()
                    if i < chars.count, chars[i] == "(" {
                        out.append(.sup(MathLayout.layout(readGroup(open: "(", close: ")"))))
                    } else {
                        var s = ""
                        if i < chars.count, chars[i] == "-" || chars[i] == "−" { s.append("−"); i += 1 }
                        while i < chars.count, chars[i].isNumber || chars[i].isLetter { s.append(chars[i]); i += 1 }
                        out.append(.sup([.text(s)]))
                    }
                    continue
                }
                if c == "√" {
                    i += 1
                    flush()
                    if i < chars.count, chars[i] == "(" {
                        out.append(.sqrt(MathLayout.layout(readGroup(open: "(", close: ")"))))
                    } else if i < chars.count, chars[i] == "{" {
                        out.append(.sqrt(MathLayout.layout(readGroup(open: "{", close: "}"))))
                    } else {
                        var s = ""
                        while i < chars.count, chars[i].isNumber || chars[i].isLetter || chars[i] == "," { s.append(chars[i]); i += 1 }
                        out.append(.sqrt([.text(s)]))
                    }
                    continue
                }
                buffer.append(c == "-" ? "−" : c)
                i += 1
            }
            flush()
            return out
        }

        /// Содержимое скобок с учётом вложенности; курсор встаёт после закрывающей.
        mutating func readGroup(open: Character, close: Character) -> String {
            guard i < chars.count, chars[i] == open else { return "" }
            var depth = 0
            var s = ""
            while i < chars.count {
                let c = chars[i]
                i += 1
                if c == open {
                    depth += 1
                    if depth == 1 { continue }
                } else if c == close {
                    depth -= 1
                    if depth == 0 { break }
                }
                s.append(c)
            }
            return s
        }

        /// «12/35» из цифр — дробь. Возвращает верх, низ и длину записи.
        func plainFraction(at start: Int) -> (String, String, Int)? {
            var j = start
            var a = ""
            while j < chars.count, chars[j].isNumber { a.append(chars[j]); j += 1 }
            guard j < chars.count, chars[j] == "/" else { return nil }
            j += 1
            var b = ""
            while j < chars.count, chars[j].isNumber { b.append(chars[j]); j += 1 }
            guard !b.isEmpty else { return nil }
            return (a, b, j - start)
        }

        /// «[×2]» после дроби.
        mutating func readAnnotation() -> String? {
            guard i < chars.count, chars[i] == "[", i + 1 < chars.count, chars[i + 1] == "×" else { return nil }
            var j = i + 2
            var s = ""
            while j < chars.count, chars[j] != "]" { s.append(chars[j]); j += 1 }
            guard j < chars.count else { return nil }
            i = j + 1
            return "×" + s
        }
    }
}
