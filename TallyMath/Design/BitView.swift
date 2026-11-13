import SwiftUI

/// Состояния Bit.
enum BitMood: String, CaseIterable, Identifiable {
    case idle, waiting, correct, wrong, hint, streak

    var id: String { rawValue }

    var spoken: String {
        switch self {
        case .idle: return "спокоен"
        case .waiting: return "ждёт ответ"
        case .correct: return "радуется"
        case .wrong: return "задумался"
        case .hint: return "показывает подсказку"
        case .streak: return "празднует серию"
        }
    }
}

/// Bit рисуется в Canvas, без картинок: масштабируется и анимируется по состояниям.
/// Координаты сняты с образца: центр тела в нуле, тело ±105.
struct BitView: View {
    var mood: BitMood
    var size: CGFloat = 120
    /// Зеркально — когда Bit показывает влево.
    var mirrored = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let painter = BitPainter(mood: mood, dark: scheme == .dark, time: t, mirrored: mirrored)
                painter.draw(in: &context, size: canvasSize)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Bit \(mood.spoken)")
    }
}

private struct BitPainter {
    let mood: BitMood
    let dark: Bool
    let time: Double
    let mirrored: Bool

    var ink: Color { dark ? Color(white: 0.95) : Color(white: 0.08) }
    var outline: Color { dark ? Color(white: 0.85) : Color(white: 0.12) }
    var bodyTop: Color { dark ? Color(white: 0.36) : Color(white: 0.985) }
    var bodyBottom: Color { dark ? Color(white: 0.15) : Color(white: 0.89) }
    var pop: Color { dark ? Color(white: 0.93) : .white }
    var popInk: Color { dark ? Color(white: 0.08) : Color(white: 0.08) }
    var background: Color { dark ? .black : .white }

    func draw(in ctx: inout GraphicsContext, size: CGSize) {
        // Персонаж с руками и значками занимает примерно 440 × 440 единиц.
        let scale = min(size.width, size.height) / 440
        ctx.translateBy(x: size.width / 2, y: size.height * 0.6)
        ctx.scaleBy(x: mirrored ? -scale : scale, y: scale)
        // Короткие спокойные движения.
        switch mood {
        case .idle, .waiting:
            ctx.rotate(by: .degrees(sin(time * 1.2) * 2))
        case .correct:
            ctx.translateBy(x: 0, y: -abs(sin(time * 3)) * 6)
        case .streak:
            ctx.translateBy(x: 0, y: -abs(sin(time * 4)) * 10)
        default:
            break
        }

        let blink = (mood == .idle || mood == .waiting) && time.truncatingRemainder(dividingBy: 4.3) < 0.14

        var back: [(inout GraphicsContext) -> Void] = []
        var front: [(inout GraphicsContext) -> Void] = []
        let armLeftDown = arm("M -104 5 C -135 22 -147 55 -147 92", hand: CGPoint(x: -147, y: 92))
        let armRightDown = arm("M 104 5 C 135 22 147 55 147 92", hand: CGPoint(x: 147, y: 92))
        let smile = line("M -26 36 Q 0 52 27 36")
        let openMouth: (inout GraphicsContext) -> Void = { [ink] c in
            var p = Path()
            p.move(to: CGPoint(x: -29, y: 30))
            p.addLine(to: CGPoint(x: 29, y: 30))
            p.addQuadCurve(to: CGPoint(x: 0, y: 60), control: CGPoint(x: 27, y: 60))
            p.addQuadCurve(to: CGPoint(x: -29, y: 30), control: CGPoint(x: -27, y: 60))
            c.fill(p, with: .color(ink))
        }

        switch mood {
        case .idle:
            back += [armLeftDown, armRightDown]
            front += [line("M -58 -66 L -20 -66 M 18 -66 L 58 -66"),
                      eye(-38, -24, blink ? .closed : .open, 2, -2), eye(38, -24, blink ? .closed : .open, 2, -2), smile]
        case .waiting:
            back += [armLeftDown]
            front += [line("M -58 -72 Q -38 -90 -18 -74"), line("M 17 -64 L 59 -70"),
                      eye(-38, -26, blink ? .closed : .open, 5, -6), eye(38, -24, blink ? .closed : .open, 5, -6),
                      line("M -20 49 L 25 39"), line("M 106 52 L 66 70"), dot(64, 70, 17),
                      dot(135, -118, 6), dot(162, -147, 9), bubble(at: CGPoint(x: 211, y: -186), text: "?")]
        case .correct:
            back += [arm("M -104 -17 C -140 -45 -153 -85 -153 -126", hand: CGPoint(x: -153, y: -126)),
                     arm("M 104 -17 C 140 -45 153 -85 153 -126", hand: CGPoint(x: 153, y: -126))]
            front += [eye(-36, -18, .happy, 0, 0), eye(39, -18, .happy, 0, 0), openMouth, plus(-76, -176, 14), plus(83, -193, 14)]
        case .wrong:
            back += [armLeftDown, arm("M 106 -13 C 140 -45 142 -95 88 -130", hand: CGPoint(x: 88, y: -130))]
            front += [line("M -58 -59 L -18 -75"), line("M 18 -75 L 58 -59"),
                      eye(-37, -23, .open, -6, 4), eye(38, -23, .open, -6, 4),
                      line("M -25 47 C -17 37 -9 37 0 45 C 9 53 17 53 25 43"),
                      label("?", at: CGPoint(x: -147, y: -140), size: 54)]
        case .hint:
            back += [armLeftDown]
            front += [line("M -58 -64 L -18 -64"), line("M 19 -76 Q 39 -92 59 -76"),
                      eye(-38, -25, .open, 8, 0), eye(39, -25, .open, 8, 0), line("M -20 37 Q 4 52 29 34"),
                      line("M 106 22 L 229 -15"), dot(184, -1, 13), bulb()]
        case .streak:
            back += [arm("M -104 -18 C -140 -40 -164 -80 -164 -126", hand: CGPoint(x: -164, y: -126)),
                     arm("M 104 -18 C 140 -40 165 -80 165 -126", hand: CGPoint(x: 165, y: -126))]
            front += [line("M -59 -74 Q -40 -88 -21 -74 M 19 -74 Q 38 -88 59 -74"),
                      eye(-37, -26, .open, 0, -2), eye(38, -26, .open, 0, -2), openMouth, crown(),
                      plus(-88, -186, 14), plus(94, -200, 13), plus(71, -148, 10)]
        }

        for f in back { f(&ctx) }
        let body = Path(roundedRect: CGRect(x: -105, y: -105, width: 210, height: 210), cornerRadius: 64, style: .continuous)
        ctx.fill(body, with: .linearGradient(Gradient(colors: [bodyTop, bodyBottom]),
                                             startPoint: CGPoint(x: 0, y: -105), endPoint: CGPoint(x: 0, y: 105)))
        ctx.stroke(body, with: .color(outline), lineWidth: 3)
        line("M -88 -46 C -88 -60 -82 -70 -70 -73", width: 3.5, opacity: 0.85)(&ctx)
        for f in front { f(&ctx) }
    }

    // MARK: Детали

    enum EyeMode { case open, closed, happy }

    func eye(_ cx: CGFloat, _ cy: CGFloat, _ mode: EyeMode, _ dx: CGFloat, _ dy: CGFloat) -> (inout GraphicsContext) -> Void {
        switch mode {
        case .closed:
            return line("M \(cx - 17) \(cy) Q \(cx) \(cy + 8) \(cx + 17) \(cy)")
        case .happy:
            return line("M \(cx - 17) \(cy + 7) Q \(cx) \(cy - 15) \(cx + 17) \(cy + 7)")
        case .open:
            return { [outline] c in
                let white = Path(ellipseIn: CGRect(x: cx - 22, y: cy - 22, width: 44, height: 44))
                c.fill(white, with: .color(Color(white: self.dark ? 0.96 : 1)))
                c.stroke(white, with: .color(outline), lineWidth: 3)
                let px = cx + dx, py = cy + dy
                c.fill(Path(ellipseIn: CGRect(x: px - 10.5, y: py - 10.5, width: 21, height: 21)), with: .color(Color(white: 0.07)))
                c.fill(Path(ellipseIn: CGRect(x: px + 0.5, y: py - 6.5, width: 6, height: 6)), with: .color(.white))
            }
        }
    }

    func line(_ d: String, width: CGFloat = 4.5, opacity: Double = 1) -> (inout GraphicsContext) -> Void {
        let path = svgPath(d)
        return { [ink] c in
            c.stroke(path, with: .color(ink.opacity(opacity)),
                     style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }

    func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> (inout GraphicsContext) -> Void {
        { [ink] c in c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(ink)) }
    }

    func arm(_ d: String, hand: CGPoint) -> (inout GraphicsContext) -> Void {
        let l = line(d)
        let h = dot(hand.x, hand.y, 13)
        return { c in l(&c); h(&c) }
    }

    func plus(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) -> (inout GraphicsContext) -> Void {
        line("M \(x - s) \(y) L \(x + s) \(y) M \(x) \(y - s) L \(x) \(y + s)")
    }

    func label(_ s: String, at p: CGPoint, size: CGFloat) -> (inout GraphicsContext) -> Void {
        { [ink, mirrored] c in
            var copy = c
            if mirrored { copy.scaleBy(x: -1, y: 1) }
            let point = mirrored ? CGPoint(x: -p.x, y: p.y) : p
            copy.draw(Text(s).font(.system(size: size, weight: .bold, design: .rounded)).foregroundColor(ink), at: point)
        }
    }

    func bubble(at p: CGPoint, text: String) -> (inout GraphicsContext) -> Void {
        { [ink, pop, popInk, mirrored] c in
            let r = Path(ellipseIn: CGRect(x: p.x - 50, y: p.y - 30, width: 100, height: 60))
            c.fill(r, with: .color(pop))
            c.stroke(r, with: .color(ink), lineWidth: 3)
            var copy = c
            if mirrored { copy.scaleBy(x: -1, y: 1) }
            let point = mirrored ? CGPoint(x: -p.x, y: p.y) : p
            copy.draw(Text(text).font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(popInk), at: point)
        }
    }

    func bulb() -> (inout GraphicsContext) -> Void {
        let rays = line("M -136 -197 L -136 -208 M -166 -181 L -176 -187 M -106 -181 L -96 -187", width: 3.5)
        let base = line("M -147 -131 L -125 -131 M -145 -123 L -127 -123", width: 3.5)
        return { [ink, pop, dark] c in
            let glass = Path(ellipseIn: CGRect(x: -157, y: -181, width: 42, height: 42))
            if dark { c.fill(glass, with: .color(pop)) }
            c.stroke(glass, with: .color(ink), lineWidth: 3.5)
            base(&c)
            rays(&c)
        }
    }

    func crown() -> (inout GraphicsContext) -> Void {
        { [ink, pop, dark] c in
            var p = Path()
            p.move(to: CGPoint(x: -31, y: -110))
            for pt in [(-31, -144), (-15, -128), (0, -153), (15, -128), (32, -144), (32, -110)] {
                p.addLine(to: CGPoint(x: pt.0, y: pt.1))
            }
            p.closeSubpath()
            c.fill(p, with: .color(dark ? pop : ink))
        }
    }

    /// Маленький разборщик SVG-пути: M, L, Q, C с абсолютными координатами.
    func svgPath(_ d: String) -> Path {
        var path = Path()
        let parts = d.split(separator: " ").map(String.init)
        var i = 0
        var command = "M"
        func num() -> CGFloat {
            defer { i += 1 }
            return CGFloat(Double(parts[i]) ?? 0)
        }
        while i < parts.count {
            if let first = parts[i].first, first.isLetter {
                command = parts[i]
                i += 1
            }
            switch command {
            case "M": path.move(to: CGPoint(x: num(), y: num()))
            case "L": path.addLine(to: CGPoint(x: num(), y: num()))
            case "Q":
                let c = CGPoint(x: num(), y: num())
                path.addQuadCurve(to: CGPoint(x: num(), y: num()), control: c)
            case "C":
                let c1 = CGPoint(x: num(), y: num()), c2 = CGPoint(x: num(), y: num())
                path.addCurve(to: CGPoint(x: num(), y: num()), control1: c1, control2: c2)
            default: i += 1
            }
        }
        return path
    }
}
