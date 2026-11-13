import SwiftUI
import UIKit

/// Строго чёрно-белая палитра. Системные «серые» в iOS чуть голубые, поэтому серые задаём сами.
extension Color {
    static func gray(light: CGFloat, dark: CGFloat, opacity: CGFloat = 1) -> Color {
        Color(UIColor { traits in
            UIColor(white: traits.userInterfaceStyle == .dark ? dark : light, alpha: opacity)
        })
    }

    /// Основной текст и линии: чёрный / белый.
    static let ink = Color.gray(light: 0.07, dark: 0.95)
    /// Второстепенный текст.
    static let sub = Color.gray(light: 0.43, dark: 0.62)
    /// Едва заметные элементы.
    static let faint = Color.gray(light: 0.64, dark: 0.38)
    /// Фон экрана.
    static let canvas = Color.gray(light: 1.0, dark: 0.0)
    /// Цвет, обратный ink: текст на залитой кнопке.
    static let inverse = Color.gray(light: 1.0, dark: 0.0)
    /// Карточка контента (не стекло).
    static let card = Color.gray(light: 1.0, dark: 0.11, opacity: 0.86)
    static let cardStroke = Color.gray(light: 0.0, dark: 1.0, opacity: 0.07)
    static let hairline = Color.gray(light: 0.0, dark: 1.0, opacity: 0.08)
}

enum Metrics {
    static let cardRadius: CGFloat = 26
    static let controlRadius: CGFloat = 18
    static let gutter: CGFloat = 20
}

/// Спокойный фон: крупные размытые серые формы, чтобы стекло было видно.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.canvas
                if !reduceTransparency {
                    let w = geo.size.width, h = geo.size.height
                    blob(0.81, 0.23).frame(width: w * 0.9).position(x: w * 0.1, y: h * 0.2)
                    blob(0.90, 0.15).frame(width: w * 0.75).position(x: w * 0.92, y: h * 0.42)
                    blob(0.74, 0.29).frame(width: w * 1.05).position(x: w * 0.76, y: h * 0.9)
                    blob(0.86, 0.18).frame(width: w * 0.6).position(x: w * 0.15, y: h * 0.72)
                }
            }
            .blur(radius: reduceTransparency ? 0 : 60)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func blob(_ light: CGFloat, _ dark: CGFloat) -> some View {
        Circle().fill(Color.gray(light: light, dark: dark)).aspectRatio(1, contentMode: .fit)
    }
}

extension View {
    /// Карточка контента: сплошная, без стекла (стекло — только для управления).
    func contentCard(radius: CGFloat = Metrics.cardRadius, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.card))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.cardStroke))
    }

    /// Фон экрана.
    func screenBackground() -> some View {
        background(AppBackground())
    }
}

/// Шрифты: SF, числа — скруглённые.
extension Font {
    static func numbers(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
