/// Модель редактора записи: дерево полей с шаблонами (дробь, степень, корень, модуль, система).
/// Редактор сам превращает запись в текст, понятный Parser, поэтому проверка одна для всех экранов.
public indirect enum EditorNode: Hashable, Sendable, Codable {
    case char(String)
    /// Дробь: верх, низ и необязательная пометка множителя «×n».
    case fraction(EditorField, EditorField, EditorField?)
    /// Показатель степени к тому, что стоит слева.
    case power(EditorField)
    case sqrt(EditorField)
    case abs(EditorField)
    /// Система из двух строк.
    case system(EditorField, EditorField)

    var slots: [EditorField] {
        switch self {
        case .char: return []
        case .fraction(let a, let b, let c): return [a, b] + (c.map { [$0] } ?? [])
        case .power(let a), .sqrt(let a), .abs(let a): return [a]
        case .system(let a, let b): return [a, b]
        }
    }

    func withSlot(_ i: Int, _ f: EditorField) -> EditorNode {
        switch self {
        case .char: return self
        case .fraction(let a, let b, let c):
            return i == 0 ? .fraction(f, b, c) : (i == 1 ? .fraction(a, f, c) : .fraction(a, b, f))
        case .power: return .power(f)
        case .sqrt: return .sqrt(f)
        case .abs: return .abs(f)
        case .system(let a, let b): return i == 0 ? .system(f, b) : .system(a, f)
        }
    }
}

public struct EditorField: Hashable, Sendable, Codable {
    public var nodes: [EditorNode] = []
    public init(_ nodes: [EditorNode] = []) { self.nodes = nodes }
    public var isEmpty: Bool { nodes.isEmpty }
}

/// Курсор: путь по шаблонам (индекс узла, номер поля) и позиция в последнем поле.
public struct EditorCursor: Hashable, Sendable, Codable {
    public var path: [Step]
    public var position: Int

    public struct Step: Hashable, Sendable, Codable {
        public var node: Int
        public var slot: Int

        public init(node: Int, slot: Int) {
            self.node = node
            self.slot = slot
        }
    }
}

public struct MathEditor: Hashable, Sendable, Codable {
    public private(set) var root = EditorField()
    public private(set) var cursor = EditorCursor(path: [], position: 0)

    public init() {}

    public init(text: String) {
        for ch in text { insert(String(ch)) }
    }

    public var isEmpty: Bool { root.isEmpty }

    // MARK: Ввод

    public mutating func insert(_ s: String) { put(.char(s), enter: nil) }

    /// Пустая дробь. Курсор встаёт в верх. Если левее стоит число — получится смешанное число «2 1/3».
    public mutating func insertFraction() { put(.fraction(EditorField(), EditorField(), nil), enter: 0) }

    public mutating func insertPower() { put(.power(EditorField()), enter: 0) }
    public mutating func insertSqrt() { put(.sqrt(EditorField()), enter: 0) }
    public mutating func insertAbs() { put(.abs(EditorField()), enter: 0) }
    public mutating func insertSystem() { put(.system(EditorField(), EditorField()), enter: 0) }

    /// Пометка множителя у ближайшей дроби слева (или у дроби, внутри которой курсор).
    public mutating func annotateFraction() {
        if let last = cursor.path.last, case .fraction(let a, let b, nil) = node(at: Array(cursor.path.dropLast()), last.node) {
            let parent = Array(cursor.path.dropLast())
            setNode(at: parent, last.node, .fraction(a, b, EditorField()))
            cursor = EditorCursor(path: parent + [.init(node: last.node, slot: 2)], position: 0)
            return
        }
        let f = field(at: cursor.path)
        guard cursor.position > 0, case .fraction(let a, let b, let c) = f.nodes[cursor.position - 1] else { return }
        let i = cursor.position - 1
        setNode(at: cursor.path, i, .fraction(a, b, c ?? EditorField()))
        cursor = EditorCursor(path: cursor.path + [.init(node: i, slot: 2)], position: c?.nodes.count ?? 0)
    }

    // MARK: Перемещение

    /// Курсор в конец поля по нажатию на него.
    public mutating func moveCursor(to path: [EditorCursor.Step]) {
        cursor = EditorCursor(path: path, position: field(at: path).nodes.count)
    }

    /// Следующее поле шаблона (верх → низ → выход), иначе — на символ вправо.
    public mutating func moveNext() {
        if let last = cursor.path.last {
            let parentPath = Array(cursor.path.dropLast())
            let n = node(at: parentPath, last.node)
            let here = field(at: cursor.path)
            if cursor.position < here.nodes.count {
                stepInto(right: true)
                return
            }
            if last.slot + 1 < n.slots.count {
                cursor = EditorCursor(path: parentPath + [.init(node: last.node, slot: last.slot + 1)], position: 0)
            } else {
                cursor = EditorCursor(path: parentPath, position: last.node + 1)
            }
            return
        }
        stepInto(right: true)
    }

    public mutating func movePrev() {
        if cursor.position > 0 {
            stepInto(right: false)
            return
        }
        guard let last = cursor.path.last else { return }
        let parentPath = Array(cursor.path.dropLast())
        if last.slot > 0 {
            let f = node(at: parentPath, last.node).slots[last.slot - 1]
            cursor = EditorCursor(path: parentPath + [.init(node: last.node, slot: last.slot - 1)], position: f.nodes.count)
        } else {
            cursor = EditorCursor(path: parentPath, position: last.node)
        }
    }

    /// Вправо/влево на один узел; в шаблон входим.
    private mutating func stepInto(right: Bool) {
        let f = field(at: cursor.path)
        if right {
            guard cursor.position < f.nodes.count else { return }
            let n = f.nodes[cursor.position]
            if !n.slots.isEmpty {
                cursor = EditorCursor(path: cursor.path + [.init(node: cursor.position, slot: 0)], position: 0)
            } else {
                cursor.position += 1
            }
        } else {
            let n = f.nodes[cursor.position - 1]
            if !n.slots.isEmpty {
                let slot = n.slots.count - 1
                cursor = EditorCursor(path: cursor.path + [.init(node: cursor.position - 1, slot: slot)],
                                      position: n.slots[slot].nodes.count)
            } else {
                cursor.position -= 1
            }
        }
    }

    // MARK: Удаление

    public mutating func backspace() {
        if cursor.position > 0 {
            var f = field(at: cursor.path)
            let removed = f.nodes[cursor.position - 1]
            if removed.slots.contains(where: { !$0.isEmpty }) {
                // Непустой шаблон: сначала входим в него, а не стираем целиком.
                movePrev()
                return
            }
            f.nodes.remove(at: cursor.position - 1)
            setField(at: cursor.path, f)
            cursor.position -= 1
            return
        }
        // В начале поля: пустой шаблон удаляем, иначе выходим из него.
        guard let last = cursor.path.last else { return }
        let parentPath = Array(cursor.path.dropLast())
        let n = node(at: parentPath, last.node)
        if n.slots.allSatisfy(\.isEmpty) {
            var parent = field(at: parentPath)
            parent.nodes.remove(at: last.node)
            setField(at: parentPath, parent)
            cursor = EditorCursor(path: parentPath, position: last.node)
        } else {
            movePrev()
        }
    }

    public mutating func clear() {
        root = EditorField()
        cursor = EditorCursor(path: [], position: 0)
    }

    // MARK: Текст для Parser

    public var text: String { Self.serialize(root) }

    static func serialize(_ f: EditorField) -> String {
        var out = ""
        for n in f.nodes {
            switch n {
            case .char(let c): out += c
            case .fraction(let a, let b, let c):
                out += "{\(serialize(a))}/{\(serialize(b))}"
                if let c, !c.isEmpty { out += "[×\(serialize(c))]" }
            case .power(let e): out += "^(\(serialize(e)))"
            case .sqrt(let e): out += "√(\(serialize(e)))"
            case .abs(let e): out += "|\(serialize(e))|"
            case .system(let a, let b): out += "\(serialize(a)); \(serialize(b))"
            }
        }
        return out
    }

    /// Путь курсора внутри поля (для отрисовки): совпадает ли поле с полем курсора.
    public func isCursorField(_ path: [EditorCursor.Step]) -> Bool { cursor.path == path }

    // MARK: Доступ по пути

    public func field(at path: [EditorCursor.Step]) -> EditorField {
        var f = root
        for s in path { f = f.nodes[s.node].slots[s.slot] }
        return f
    }

    func node(at path: [EditorCursor.Step], _ i: Int) -> EditorNode { field(at: path).nodes[i] }

    private mutating func setField(at path: [EditorCursor.Step], _ f: EditorField) {
        root = Self.replacing(root, path[...], f)
    }

    private mutating func setNode(at path: [EditorCursor.Step], _ i: Int, _ n: EditorNode) {
        var f = field(at: path)
        f.nodes[i] = n
        setField(at: path, f)
    }

    private static func replacing(_ f: EditorField, _ path: ArraySlice<EditorCursor.Step>, _ new: EditorField) -> EditorField {
        guard let s = path.first else { return new }
        var copy = f
        let n = copy.nodes[s.node]
        copy.nodes[s.node] = n.withSlot(s.slot, replacing(n.slots[s.slot], path.dropFirst(), new))
        return copy
    }

    private mutating func put(_ n: EditorNode, enter slot: Int?) {
        var f = field(at: cursor.path)
        let i = cursor.position
        f.nodes.insert(n, at: i)
        setField(at: cursor.path, f)
        if let slot {
            cursor = EditorCursor(path: cursor.path + [.init(node: i, slot: slot)], position: 0)
        } else {
            cursor.position += 1
        }
    }
}
