import SwiftUI

enum LayoutMode: String, CaseIterable {
    case compact, wide, split

    static func mode(fullW: CGFloat, fullH: CGFloat, W: CGFloat) -> LayoutMode {
        if fullH > 0, fullW / fullH > 1.15, fullW >= 800 { return .split }
        if W >= 600 { return .wide }
        return .compact
    }

    var horizontalPadding: CGFloat {
        switch self { case .compact: 20; case .wide: 40; case .split: 48 }
    }
    var topPadding: CGFloat { self == .compact ? 8 : 0 }
    var columnMax: CGFloat {
        switch self { case .compact: .infinity; case .wide: 520; case .split: 440 }
    }
    var titleSize: CGFloat { self == .compact ? 28 : 34 }
    func bottomPadding(safeHeight: CGFloat) -> CGFloat {
        switch self {
        case .compact: 16
        case .wide: min(120, max(40, safeHeight * 0.08))
        case .split: 24
        }
    }
}

struct LayoutMetrics {
    let fullSize: CGSize
    let safeSize: CGSize
    let safeAreaInsets: EdgeInsets
    var mode: LayoutMode {
        .mode(fullW: fullSize.width, fullH: fullSize.height, W: safeSize.width)
    }
    var isShort: Bool { safeSize.height < 640 }
}

/// Install at the scene root. Geometry's size is the real safe area; no device inset tables.
struct LayoutReader<Content: View>: View {
    @ViewBuilder let content: (LayoutMetrics) -> Content

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            content(LayoutMetrics(
                fullSize: CGSize(width: proxy.size.width + insets.leading + insets.trailing,
                                 height: proxy.size.height + insets.top + insets.bottom),
                safeSize: proxy.size, safeAreaInsets: insets))
        }
    }
}

/// Adaptive scrolling content. Toolbars belong to the screen, outside geometry/layout branches.
struct AdaptiveLayout<Header: View, Content: View>: View {
    let metrics: LayoutMetrics
    var actionStyle = false
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if metrics.mode == .split {
                HStack(spacing: 0) {
                    ScrollView {
                        header().frame(maxWidth: actionStyle ? 560 : 440)
                            .padding(.leading, 48)
                            .padding(.trailing, actionStyle ? 32 : 48)
                            .frame(maxWidth: .infinity)
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    column(showHeader: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                column(showHeader: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, metrics.mode.topPadding)
    }

    private func column(showHeader: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if showHeader { header() }
                content()
            }
            .frame(maxWidth: actionStyle && metrics.mode != .compact ? 560 : metrics.mode.columnMax, alignment: .leading)
            // Keep gutters inside the viewport: native switches and control
            // effects can draw beyond their layout bounds on either side.
            .padding(.leading, actionStyle && metrics.mode == .split ? 32 : metrics.mode.horizontalPadding)
            .padding(.trailing, metrics.mode.horizontalPadding)
            .frame(maxWidth: .infinity)
        }
    }
}
