#if DEBUG
import SwiftUI

@MainActor final class ScannerPreviewStore: ObservableObject {
    enum State: String, CaseIterable { case scanning, animated, found, wrong, noCamera }
    let session = SecretSession()
    let model: ScannerModel
    init(state: State, cameraDenied: Bool = false) {
        model = ScannerModel(session: session)
        let event: ScannerEvent
        switch state {
        case .scanning, .noCamera: event = .scanning
        case .animated: event = .progress(3, 7)
        case .found: event = .found("Recovery phrase found · 12 words")
        case .wrong: event = .wrong(KeyScanRouter.addressMessage)
        }
        model.preview(access: state == .noCamera || cameraDenied ? .unavailable : .ready, event: event)
    }
}
struct ScannerFixturePreview: View {
    let device: WelcomeDeviceFixture
    @StateObject private var store: ScannerPreviewStore
    init(device: WelcomeDeviceFixture, state: ScannerPreviewStore.State, cameraDenied: Bool = false) {
        self.device = device; _store = StateObject(wrappedValue: ScannerPreviewStore(state: state, cameraDenied: cameraDenied))
    }
    var body: some View {
        ScannerView(session: store.session, model: store.model, startsCamera: false) { _ in }
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
            .background(.black)
    }
}

#Preview("iPhone SE · light · scanning", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .scanning).environment(\.colorScheme, .light)
}

#Preview("iPhone SE · light · animated", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .animated).environment(\.colorScheme, .light)
}

#Preview("iPhone SE · light · found", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .found).environment(\.colorScheme, .light)
}

#Preview("iPhone SE · light · wrong", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .wrong).environment(\.colorScheme, .light)
}

#Preview("iPhone SE · light · noCamera", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .noCamera).environment(\.colorScheme, .light)
}

#Preview("iPhone SE · dark · scanning", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .scanning).environment(\.colorScheme, .dark)
}

#Preview("iPhone SE · dark · animated", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .animated).environment(\.colorScheme, .dark)
}

#Preview("iPhone SE · dark · found", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .found).environment(\.colorScheme, .dark)
}

#Preview("iPhone SE · dark · wrong", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .wrong).environment(\.colorScheme, .dark)
}

#Preview("iPhone SE · dark · noCamera", traits: .fixedLayout(width: 375, height: 667)) {
    ScannerFixturePreview(device: .requested[0], state: .noCamera).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro · light · scanning", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .scanning).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro · light · animated", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .animated).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro · light · found", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .found).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro · light · wrong", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .wrong).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro · light · noCamera", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .noCamera).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro · dark · scanning", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .scanning).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro · dark · animated", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .animated).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro · dark · found", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .found).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro · dark · wrong", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .wrong).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro · dark · noCamera", traits: .fixedLayout(width: 402, height: 874)) {
    ScannerFixturePreview(device: .requested[1], state: .noCamera).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro Max · light · scanning", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .scanning).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro Max · light · animated", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .animated).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro Max · light · found", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .found).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro Max · light · wrong", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .wrong).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro Max · light · noCamera", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .noCamera).environment(\.colorScheme, .light)
}

#Preview("iPhone 17 Pro Max · dark · scanning", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .scanning).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro Max · dark · animated", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .animated).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro Max · dark · found", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .found).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro Max · dark · wrong", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .wrong).environment(\.colorScheme, .dark)
}

#Preview("iPhone 17 Pro Max · dark · noCamera", traits: .fixedLayout(width: 440, height: 956)) {
    ScannerFixturePreview(device: .requested[2], state: .noCamera).environment(\.colorScheme, .dark)
}

#Preview("Duo outer · light · scanning", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .scanning).environment(\.colorScheme, .light)
}

#Preview("Duo outer · light · animated", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .animated).environment(\.colorScheme, .light)
}

#Preview("Duo outer · light · found", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .found).environment(\.colorScheme, .light)
}

#Preview("Duo outer · light · wrong", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .wrong).environment(\.colorScheme, .light)
}

#Preview("Duo outer · light · noCamera", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .noCamera).environment(\.colorScheme, .light)
}

#Preview("Duo outer · dark · scanning", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .scanning).environment(\.colorScheme, .dark)
}

#Preview("Duo outer · dark · animated", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .animated).environment(\.colorScheme, .dark)
}

#Preview("Duo outer · dark · found", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .found).environment(\.colorScheme, .dark)
}

#Preview("Duo outer · dark · wrong", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .wrong).environment(\.colorScheme, .dark)
}

#Preview("Duo outer · dark · noCamera", traits: .fixedLayout(width: 466, height: 678)) {
    ScannerFixturePreview(device: .requested[3], state: .noCamera).environment(\.colorScheme, .dark)
}

#Preview("Duo inner · light · scanning", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .scanning).environment(\.colorScheme, .light)
}

#Preview("Duo inner · light · animated", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .animated).environment(\.colorScheme, .light)
}

#Preview("Duo inner · light · found", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .found).environment(\.colorScheme, .light)
}

#Preview("Duo inner · light · wrong", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .wrong).environment(\.colorScheme, .light)
}

#Preview("Duo inner · light · noCamera", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .noCamera).environment(\.colorScheme, .light)
}

#Preview("Duo inner · dark · scanning", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .scanning).environment(\.colorScheme, .dark)
}

#Preview("Duo inner · dark · animated", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .animated).environment(\.colorScheme, .dark)
}

#Preview("Duo inner · dark · found", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .found).environment(\.colorScheme, .dark)
}

#Preview("Duo inner · dark · wrong", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .wrong).environment(\.colorScheme, .dark)
}

#Preview("Duo inner · dark · noCamera", traits: .fixedLayout(width: 890, height: 626)) {
    ScannerFixturePreview(device: .requested[4], state: .noCamera).environment(\.colorScheme, .dark)
}

#Preview("Duo rotated · light · scanning", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .scanning).environment(\.colorScheme, .light)
}

#Preview("Duo rotated · light · animated", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .animated).environment(\.colorScheme, .light)
}

#Preview("Duo rotated · light · found", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .found).environment(\.colorScheme, .light)
}

#Preview("Duo rotated · light · wrong", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .wrong).environment(\.colorScheme, .light)
}

#Preview("Duo rotated · light · noCamera", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .noCamera).environment(\.colorScheme, .light)
}

#Preview("Duo rotated · dark · scanning", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .scanning).environment(\.colorScheme, .dark)
}

#Preview("Duo rotated · dark · animated", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .animated).environment(\.colorScheme, .dark)
}

#Preview("Duo rotated · dark · found", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .found).environment(\.colorScheme, .dark)
}

#Preview("Duo rotated · dark · wrong", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .wrong).environment(\.colorScheme, .dark)
}

#Preview("Duo rotated · dark · noCamera", traits: .fixedLayout(width: 626, height: 890)) {
    ScannerFixturePreview(device: .requested[5], state: .noCamera).environment(\.colorScheme, .dark)
}

#Preview("iPad mini portrait · light · scanning", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .scanning).environment(\.colorScheme, .light)
}

#Preview("iPad mini portrait · light · animated", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .animated).environment(\.colorScheme, .light)
}

#Preview("iPad mini portrait · light · found", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .found).environment(\.colorScheme, .light)
}

#Preview("iPad mini portrait · light · wrong", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .wrong).environment(\.colorScheme, .light)
}

#Preview("iPad mini portrait · light · noCamera", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .noCamera).environment(\.colorScheme, .light)
}

#Preview("iPad mini portrait · dark · scanning", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .scanning).environment(\.colorScheme, .dark)
}

#Preview("iPad mini portrait · dark · animated", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .animated).environment(\.colorScheme, .dark)
}

#Preview("iPad mini portrait · dark · found", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .found).environment(\.colorScheme, .dark)
}

#Preview("iPad mini portrait · dark · wrong", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .wrong).environment(\.colorScheme, .dark)
}

#Preview("iPad mini portrait · dark · noCamera", traits: .fixedLayout(width: 744, height: 1133)) {
    ScannerFixturePreview(device: .requested[6], state: .noCamera).environment(\.colorScheme, .dark)
}

#Preview("iPad mini landscape · light · scanning", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .scanning).environment(\.colorScheme, .light)
}

#Preview("iPad mini landscape · light · animated", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .animated).environment(\.colorScheme, .light)
}

#Preview("iPad mini landscape · light · found", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .found).environment(\.colorScheme, .light)
}

#Preview("iPad mini landscape · light · wrong", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .wrong).environment(\.colorScheme, .light)
}

#Preview("iPad mini landscape · light · noCamera", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .noCamera).environment(\.colorScheme, .light)
}

#Preview("iPad mini landscape · dark · scanning", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .scanning).environment(\.colorScheme, .dark)
}

#Preview("iPad mini landscape · dark · animated", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .animated).environment(\.colorScheme, .dark)
}

#Preview("iPad mini landscape · dark · found", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .found).environment(\.colorScheme, .dark)
}

#Preview("iPad mini landscape · dark · wrong", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .wrong).environment(\.colorScheme, .dark)
}

#Preview("iPad mini landscape · dark · noCamera", traits: .fixedLayout(width: 1133, height: 744)) {
    ScannerFixturePreview(device: .requested[7], state: .noCamera).environment(\.colorScheme, .dark)
}

#Preview("iPad Pro 13 landscape · light · scanning", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .scanning).environment(\.colorScheme, .light)
}

#Preview("iPad Pro 13 landscape · light · animated", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .animated).environment(\.colorScheme, .light)
}

#Preview("iPad Pro 13 landscape · light · found", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .found).environment(\.colorScheme, .light)
}

#Preview("iPad Pro 13 landscape · light · wrong", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .wrong).environment(\.colorScheme, .light)
}

#Preview("iPad Pro 13 landscape · light · noCamera", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .noCamera).environment(\.colorScheme, .light)
}

#Preview("iPad Pro 13 landscape · dark · scanning", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .scanning).environment(\.colorScheme, .dark)
}

#Preview("iPad Pro 13 landscape · dark · animated", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .animated).environment(\.colorScheme, .dark)
}

#Preview("iPad Pro 13 landscape · dark · found", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .found).environment(\.colorScheme, .dark)
}

#Preview("iPad Pro 13 landscape · dark · wrong", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .wrong).environment(\.colorScheme, .dark)
}

#Preview("iPad Pro 13 landscape · dark · noCamera", traits: .fixedLayout(width: 1376, height: 1032)) {
    ScannerFixturePreview(device: .requested[8], state: .noCamera).environment(\.colorScheme, .dark)
}

#endif
