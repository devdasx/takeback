import SwiftUI

struct IndexRow: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var emphasizedValue = false
    var action: (() -> Void)? = nil
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }.buttonStyle(IndexPressStyle())
            } else { label }
        }
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1 / displayScale) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1 / displayScale) }
    }

    private var label: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(Theme.mute)
                .frame(width: 24).accessibilityHidden(true)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(Geist.font(16)).foregroundStyle(Theme.fg)
                    if let subtitle { Text(subtitle).font(Geist.font(13)).foregroundStyle(Theme.mute) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let value {
                    Text(value).font(Geist.font(15, emphasizedValue ? .medium : .regular)).monospacedDigit().foregroundStyle(emphasizedValue ? Theme.fg : Theme.mute)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            if action != nil {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.mute).accessibilityHidden(true)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 18).frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct IndexPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Theme.card.opacity(0.6) : .clear)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title).font(Geist.font(13, .medium)).foregroundStyle(Theme.mute)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}
