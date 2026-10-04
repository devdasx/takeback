import SwiftUI
import UIKit

struct WelcomeHeadline: View {
    let size: CGFloat
    let width: CGFloat
    let alignment: TextAlignment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let traits = UITraitCollection(preferredContentSizeCategory: dynamicTypeSize.uiCategory)
        let base = UIFont(name: Geist.Weight.medium.rawValue, size: size)!
        let font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: base, compatibleWith: traits)
        let tracking = -0.04 * font.pointSize
        Text(BalancedWelcomeHeadline.text(width: width, font: font, tracking: tracking))
            .font(Geist.font(size, .medium, relativeTo: .largeTitle))
            .tracking(tracking)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Cancel a stuck Bitcoin payment")
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("welcome.headline")
    }
}

enum BalancedWelcomeHeadline {
    static func text(width: CGFloat, font: UIFont, tracking: CGFloat) -> String {
        let words = ["Cancel", "a", "stuck", "Bitcoin", "payment"]
        // The copy has four possible break positions. Choose the fewest lines that fit,
        // then the partition with the least line-width variance.
        var best: (lines: Int, cost: CGFloat, text: String)?
        for mask in 0..<16 {
            var lines = [words[0]]
            for index in 1..<words.count {
                if mask & (1 << (index - 1)) != 0 { lines.append(words[index]) }
                else { lines[lines.count - 1] += " " + words[index] }
            }
            let widths = lines.map {
                ($0 as NSString).size(withAttributes: [.font: font, .kern: tracking]).width
            }
            guard widths.allSatisfy({ $0 <= width }) else { continue }
            let mean = widths.reduce(0, +) / CGFloat(widths.count)
            let cost = widths.reduce(CGFloat(0)) { $0 + pow($1 - mean, 2) }
            if best == nil || lines.count < best!.lines || (lines.count == best!.lines && cost < best!.cost) {
                best = (lines.count, cost, lines.joined(separator: "\n"))
            }
        }
        return best?.text ?? words.joined(separator: " ")
    }
}

extension DynamicTypeSize {
    var uiCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}
