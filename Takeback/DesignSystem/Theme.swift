import SwiftUI
import UIKit

enum Theme {
    static let bg = adaptive(0xF7F7F5, 0x0B0B0B)
    static let fg = adaptive(0x121211, 0xF4F4F1)
    static let mute = adaptive(0x86867F, 0x808079)
    static let line = adaptive(0xE3E3DE, 0x252524)
    static let card = adaptive(0xECECE8, 0x181817)
    static let amber = Color(hex: 0xE5A100)
    static let amberText = Color(hex: 0xB54708)
    static let amberBackground = amber.opacity(0.12)
    static let amberBorder = amber.opacity(0.35)
    static let green = Color(hex: 0x12B76A)
    static let red = Color(hex: 0xD92D20)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 255) / 255,
                  green: CGFloat((rgb >> 8) & 255) / 255,
                  blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(rgb: hex)) }
}

enum Geist {
    enum Weight: String, CaseIterable {
        case regular = "Geist-Regular"
        case medium = "Geist-Medium"
        case semibold = "Geist-SemiBold"
    }

    static func font(_ size: CGFloat, _ weight: Weight = .regular,
                     relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    static func uiFont(_ size: CGFloat, _ weight: Weight = .regular,
                       traits: UITraitCollection? = nil) -> UIFont {
        // Fail visibly during development if font bundling breaks; never silently substitute SF text.
        guard let font = UIFont(name: weight.rawValue, size: size) else {
            preconditionFailure("Bundled Geist font missing")
        }
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font, compatibleWith: traits)
    }
}

struct TakebackStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(Geist.font(16)).foregroundStyle(Theme.fg).tint(Theme.fg)
    }
}

extension View {
    func takebackStyle() -> some View { modifier(TakebackStyle()) }
}
