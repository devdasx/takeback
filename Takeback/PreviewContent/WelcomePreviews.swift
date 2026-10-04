#if DEBUG
import SwiftUI

struct WelcomePreview: View {
    enum State: String, CaseIterable { case welcome, howItWorks, openSource }
    let state: State
    @StateObject private var router = WelcomeRouter(session: SecretSession())
    @SwiftUI.State private var source = false
    var body: some View {
        WelcomeView(router: router)
            .onAppear { router.showsHowItWorks = state == .howItWorks; source = state == .openSource }
            .sheet(isPresented: $source) { OpenSourceSheet() }
    }
}

struct WelcomeDeviceFixture: Identifiable {
    let id: String
    let width: CGFloat
    let height: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    var trailing: CGFloat = 0

    static let requested: [Self] = [
        .init(id: "iPhone SE", width: 375, height: 667, top: 20, bottom: 0),
        .init(id: "iPhone 17 Pro", width: 402, height: 874, top: 62, bottom: 34),
        .init(id: "iPhone 17 Pro Max", width: 440, height: 956, top: 62, bottom: 34),
        .init(id: "Duo outer", width: 466, height: 678, top: 0, bottom: 34, trailing: 84),
        .init(id: "Duo inner", width: 890, height: 626, top: 32, bottom: 20),
        .init(id: "Duo rotated", width: 626, height: 890, top: 32, bottom: 20),
        .init(id: "iPad mini portrait", width: 744, height: 1133, top: 24, bottom: 20),
        .init(id: "iPad mini landscape", width: 1133, height: 744, top: 24, bottom: 20),
        .init(id: "iPad Pro 13 landscape", width: 1376, height: 1032, top: 24, bottom: 20)
        ,.init(id: "iPhone 13 mini", width: 375, height: 812, top: 50, bottom: 34)
        ,.init(id: "iPad Pro 13 portrait", width: 1032, height: 1376, top: 24, bottom: 20)
    ]
}

struct WelcomeFixturePreview: View {
    let device: WelcomeDeviceFixture
    let state: WelcomePreview.State
    let scheme: ColorScheme
    var body: some View {
        WelcomePreview(state: state)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
            .preferredColorScheme(scheme)
    }
}

#Preview("iPhone SE · light", traits: .fixedLayout(width: 375, height: 667)) {
    WelcomeFixturePreview(device: .requested[0], state: .welcome, scheme: .light)
}

#Preview("iPhone SE · dark", traits: .fixedLayout(width: 375, height: 667)) {
    WelcomeFixturePreview(device: .requested[0], state: .welcome, scheme: .dark)
}

#Preview("iPhone 17 Pro · light", traits: .fixedLayout(width: 402, height: 874)) {
    WelcomeFixturePreview(device: .requested[1], state: .welcome, scheme: .light)
}

#Preview("iPhone 17 Pro · dark", traits: .fixedLayout(width: 402, height: 874)) {
    WelcomeFixturePreview(device: .requested[1], state: .welcome, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · light", traits: .fixedLayout(width: 440, height: 956)) {
    WelcomeFixturePreview(device: .requested[2], state: .welcome, scheme: .light)
}

#Preview("iPhone 17 Pro Max · dark", traits: .fixedLayout(width: 440, height: 956)) {
    WelcomeFixturePreview(device: .requested[2], state: .welcome, scheme: .dark)
}

#Preview("Duo outer · light", traits: .fixedLayout(width: 466, height: 678)) {
    WelcomeFixturePreview(device: .requested[3], state: .welcome, scheme: .light)
}

#Preview("Duo outer · dark", traits: .fixedLayout(width: 466, height: 678)) {
    WelcomeFixturePreview(device: .requested[3], state: .welcome, scheme: .dark)
}

#Preview("Duo inner · light", traits: .fixedLayout(width: 890, height: 626)) {
    WelcomeFixturePreview(device: .requested[4], state: .welcome, scheme: .light)
}

#Preview("Duo inner · dark", traits: .fixedLayout(width: 890, height: 626)) {
    WelcomeFixturePreview(device: .requested[4], state: .welcome, scheme: .dark)
}

#Preview("Duo rotated · light", traits: .fixedLayout(width: 626, height: 890)) {
    WelcomeFixturePreview(device: .requested[5], state: .welcome, scheme: .light)
}

#Preview("Duo rotated · dark", traits: .fixedLayout(width: 626, height: 890)) {
    WelcomeFixturePreview(device: .requested[5], state: .welcome, scheme: .dark)
}

#Preview("iPad mini portrait · light", traits: .fixedLayout(width: 744, height: 1133)) {
    WelcomeFixturePreview(device: .requested[6], state: .welcome, scheme: .light)
}

#Preview("iPad mini portrait · dark", traits: .fixedLayout(width: 744, height: 1133)) {
    WelcomeFixturePreview(device: .requested[6], state: .welcome, scheme: .dark)
}

#Preview("iPad mini landscape · light", traits: .fixedLayout(width: 1133, height: 744)) {
    WelcomeFixturePreview(device: .requested[7], state: .welcome, scheme: .light)
}

#Preview("iPad mini landscape · dark", traits: .fixedLayout(width: 1133, height: 744)) {
    WelcomeFixturePreview(device: .requested[7], state: .welcome, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · light", traits: .fixedLayout(width: 1376, height: 1032)) {
    WelcomeFixturePreview(device: .requested[8], state: .welcome, scheme: .light)
}

#Preview("iPad Pro 13 landscape · dark", traits: .fixedLayout(width: 1376, height: 1032)) {
    WelcomeFixturePreview(device: .requested[8], state: .welcome, scheme: .dark)
}

#Preview("iPhone 13 mini · light", traits: .fixedLayout(width: 375, height: 812)) {
    WelcomeFixturePreview(device: .requested[9], state: .welcome, scheme: .light)
}

#Preview("iPhone 13 mini · dark", traits: .fixedLayout(width: 375, height: 812)) {
    WelcomeFixturePreview(device: .requested[9], state: .welcome, scheme: .dark)
}

#Preview("iPad Pro 13 portrait · light", traits: .fixedLayout(width: 1032, height: 1376)) {
    WelcomeFixturePreview(device: .requested[10], state: .welcome, scheme: .light)
}

#Preview("iPad Pro 13 portrait · dark", traits: .fixedLayout(width: 1032, height: 1376)) {
    WelcomeFixturePreview(device: .requested[10], state: .welcome, scheme: .dark)
}

#Preview("Open source · iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    WelcomeFixturePreview(device: .requested[0], state: .openSource, scheme: .light)
}

#Preview("Open source · iPhone 17 Pro", traits: .fixedLayout(width: 402, height: 874)) {
    WelcomeFixturePreview(device: .requested[1], state: .openSource, scheme: .light)
}

#Preview("Open source · iPad mini portrait", traits: .fixedLayout(width: 744, height: 1133)) {
    WelcomeFixturePreview(device: .requested[6], state: .openSource, scheme: .light)
}

#Preview("SE · AX3", traits: .fixedLayout(width: 375, height: 667)) {
    WelcomeFixturePreview(device: .requested[0], state: .welcome, scheme: .dark).dynamicTypeSize(.accessibility3)
}

#Preview("Open source · iPhone SE · dark", traits: .fixedLayout(width: 375, height: 667)) {
    WelcomeFixturePreview(device: .requested[0], state: .openSource, scheme: .dark)
}
#Preview("Open source · iPhone 17 Pro · dark", traits: .fixedLayout(width: 402, height: 874)) {
    WelcomeFixturePreview(device: .requested[1], state: .openSource, scheme: .dark)
}
#Preview("Open source · iPad · dark", traits: .fixedLayout(width: 744, height: 1133)) {
    WelcomeFixturePreview(device: .requested[6], state: .openSource, scheme: .dark)
}

#endif
