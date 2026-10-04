import SwiftUI
import LocalAuthentication

struct WelcomeBiometry: Equatable {
    let symbol: String
    let name: String
    static func value(_ type: LABiometryType) -> Self {
        switch type {
        case .touchID: .init(symbol: "touchid", name: "Touch ID")
        case .opticID: .init(symbol: "opticid", name: "Optic ID")
        default: .init(symbol: "faceid", name: "Face ID")
        }
    }
    static var device: Self {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        defer { context.invalidate() }
        return value(context.biometryType)
    }
}

struct WelcomeView: View {
    @ObservedObject var router: WelcomeRouter
    @State private var showsSource = false
    private let biometry = WelcomeBiometry.device
    private var deviceName: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }
    var body: some View {
        LayoutReader { metrics in
            VStack(spacing: 0) {
                if metrics.mode == .split { split(metrics) } else { column(metrics) }
            }
            .sheet(isPresented: $router.showsHowItWorks) { HowItWorksSheet(availableHeight: metrics.safeSize.height) }
            .sheet(isPresented: $showsSource) { OpenSourceSheet() }
        }.background(Theme.bg.ignoresSafeArea()).takebackStyle().nativeNavigation(title: "Takeback")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: router.openSettings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings").accessibilityIdentifier("welcome.settings")
            }
        }
        .bottomActions(welcome: true) {
            PrimaryButton(title: "Cancel a payment", height: 56, action: router.cancelTransaction)
                .accessibilityIdentifier("welcome.cancel")
            SecondaryButton(title: "How it works", plain: true, height: 48, action: router.showHowItWorks)
                .accessibilityIdentifier("welcome.howItWorks")
        }
    }
    private func column(_ metrics: LayoutMetrics) -> some View {
        let wide = metrics.mode == .wide
        let padding: CGFloat = wide ? 48 : 24
        let width = max(1, min(wide ? 520 : .infinity, metrics.safeSize.width - 2 * padding))
        // The system bars are already excluded from the safe content area.
        let short = metrics.safeSize.height < 640
        let textGap: CGFloat = wide ? 26 : short ? 16 : 22
        return VStack(spacing: 0) {
            GeometryReader { area in
                ScrollView {
                    VStack(spacing: 0) {
                        WelcomeHero(mode: metrics.mode, isShort: short)
                            .frame(maxWidth: wide ? 400 : .infinity)
                            .padding(.top, wide ? 0 : short ? 12 : 24)
                        message(metrics, width: width).padding(.top, wide ? 48 : short ? 20 : 28)
                        trustPoints.frame(maxWidth: wide ? 420 : .infinity).padding(.top, textGap)
                    }
                    .frame(maxWidth: wide ? 520 : .infinity)
                    .padding(.horizontal, padding)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: area.size.height, alignment: .center)
                }.scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("welcome.content")
            }
        }.frame(maxWidth: .infinity)
    }
    private func split(_ metrics: LayoutMetrics) -> some View {
        let width = max(1, min(440, (metrics.safeSize.width - 112 - 72) / 2))
        return HStack(spacing: 0) {
            ScrollView {
                WelcomeHero(mode: .split, isShort: false).frame(maxWidth: 380)
                    .frame(maxWidth: .infinity).padding(.leading, 56).padding(.trailing, 36)
                    .frame(minHeight: max(1, metrics.safeSize.height), alignment: .center)
            }.scrollBounceBehavior(.basedOnSize).frame(maxWidth: .infinity)
            ViewThatFits(in: .vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    message(metrics, width: width)
                    trustPoints.frame(maxWidth: 380)
                }.fixedSize(horizontal: false, vertical: true).padding(.bottom, 24)
                    .frame(maxWidth: width, alignment: .leading)
                    .padding(.leading, 36).padding(.trailing, 56).frame(maxWidth: .infinity, alignment: .leading)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        message(metrics, width: width)
                        trustPoints.frame(maxWidth: 380)
                    }
                    .frame(maxWidth: width, alignment: .leading)
                    .padding(.leading, 36).padding(.trailing, 56).frame(maxWidth: .infinity, alignment: .leading)
                }.scrollBounceBehavior(.basedOnSize)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        }
    }
    private func message(_ metrics: LayoutMetrics, width: CGFloat) -> some View {
        let split = metrics.mode == .split
        let size: CGFloat = metrics.mode == .split ? 42 : metrics.mode == .wide ? 46 : metrics.safeSize.height < 640 ? 30 : 34
        return VStack(alignment: split ? .leading : .center, spacing: 10) {
            Image("LogoTile").resizable().scaledToFit()
                .frame(width: metrics.mode == .compact ? 88 : 96, height: metrics.mode == .compact ? 88 : 96)
                .accessibilityLabel("Takeback").accessibilityIdentifier("welcome.logo")
                .padding(.bottom, 10)
            WelcomeHeadline(size: size, width: width, alignment: split ? .leading : .center)
            Text("Takeback can speed it up or send it back to you.")
                .font(Geist.font(16)).foregroundStyle(Theme.mute).lineSpacing(4)
                .multilineTextAlignment(split ? .leading : .center).fixedSize(horizontal: false, vertical: true).frame(maxWidth: 380)
        }.frame(maxWidth: width, alignment: split ? .leading : .center)
    }
    private var trustPoints: some View {
        HStack(alignment: .top, spacing: 8) {
            trustItem(symbol: biometry.symbol, label: "One tap with\n\(biometry.name)", id: "biometry")
            trustItem(symbol: "lock", label: "Keys stay on\nthis \(deviceName)", id: "keys")
            Button { showsSource = true } label: {
                trustItem(symbol: "chevron.left.forwardslash.chevron.right", label: "Open source", id: "source", underline: true)
            }.buttonStyle(.plain).frame(maxWidth: .infinity)
                .accessibilityLabel("Open source").accessibilityHint("Learn why Takeback is open source")
                .accessibilityIdentifier("welcome.source")
        }.padding(.vertical, 4)
    }
    private func trustItem(symbol: String, label: String, id: String, underline: Bool = false) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 18)).frame(width: 40, height: 40)
                .background(Theme.card, in: Circle()).accessibilityIdentifier("welcome.trust.\(id).icon")
            Text(label).font(Geist.font(13)).underline(underline, pattern: .dot, color: Theme.mute)
                .multilineTextAlignment(.center).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 34, alignment: .top).accessibilityIdentifier("welcome.trust.\(id).label")
        }.frame(maxWidth: .infinity).contentShape(Rectangle())
    }
}
