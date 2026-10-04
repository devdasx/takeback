import SwiftUI

struct ScannerView: View {
    @StateObject private var model: ScannerModel
    private let usesNativeNavigation: Bool
    private let startsCamera: Bool
    private let onResult: (SecureBytes) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var guide = CGRect.zero
    init(session: SecretSession, configuration: ScannerConfiguration = .privateKey,
         model: ScannerModel? = nil, startsCamera: Bool = true, usesNativeNavigation: Bool = false, onResult: @escaping (SecureBytes) -> Void) {
        _model = StateObject(wrappedValue: model ?? ScannerModel(session: session, configuration: configuration))
        self.startsCamera = startsCamera; self.usesNativeNavigation = usesNativeNavigation; self.onResult = onResult
    }
    var body: some View {
        if usesNativeNavigation { scanner }
        else { NavigationStack { scanner.nativeNavigation(title: "Scan") } }
    }
    private var scanner: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if model.access == .ready {
                    if startsCamera { ScannerCamera(model: model, guide: guide).secretPrivacy().accessibilityHidden(true) }
                    ScannerMask(hole: guide).fill(.black.opacity(0.55), style: FillStyle(eoFill: true)).allowsHitTesting(false)
                }
                VStack(spacing: 0) {
                    if model.access == .unavailable && model.event == .scanning {
                        noCamera
                    }
                    else {
                        GeometryReader { area in
                            ScrollView {
                                VStack(spacing: 24) {
                                    ScannerGuide(event: model.event, active: model.active)
                                        .frame(width: max(1, min(geometry.size.width - 80, 300)), height: max(1, min(geometry.size.width - 80, 300)))
                                        .background { GeometryReader { frame in Color.clear.preference(key: ScannerGuidePreference.self, value: frame.frame(in: .named("scanner"))) } }
                                        .accessibilityHidden(true)
                                    status.fixedSize(horizontal: false, vertical: true).frame(maxWidth: 360)
                                }
                                .padding(.horizontal, 24).padding(.vertical, 24)
                                .frame(maxWidth: .infinity, minHeight: area.size.height)
                            }.scrollBounceBehavior(.basedOnSize)
                        }
                    }
                }
            }.coordinateSpace(name: "scanner")
                .onPreferenceChange(ScannerGuidePreference.self) { guide = $0 }
        }
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .toolbar {
            if !usesNativeNavigation {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { model.close(); dismiss() }
                        .accessibilityIdentifier("scanner.close")
                }
            }
            NativeBottomBar {
                if model.access == .unavailable && model.event == .scanning {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }.accessibilityIdentifier("scanner.settings")
                }
                photoButton
            }
            if model.hasTorch && model.access == .ready {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: model.toggleTorch) {
                        Image(systemName: model.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    }
                    .accessibilityLabel(model.torchOn ? "Turn off flashlight" : "Turn on flashlight")
                    .accessibilityIdentifier("scanner.torch")
                }
            }
        }
        .sheet(isPresented: $model.choosingPhoto) { ScannerPhotoPicker(model: model).secretPrivacy().ignoresSafeArea() }
        .onAppear { model.onResult = onResult; if startsCamera { model.activate() } }
        .onDisappear { if startsCamera { model.close() } }
        .onChange(of: scenePhase) { _, phase in
            guard startsCamera else { return }
            if phase == .active { model.activate() } else { model.pause() }
        }
        .onChange(of: model.isClosed) { _, closed in if closed { dismiss() } }
    }
    private var photoButton: some View {
        Button { model.choosePhoto() } label: {
            HStack {
                Image(systemName: "photo").accessibilityHidden(true)
                Text("Choose photo")
            }
        }
            .accessibilityLabel("Choose photo")
            .disabled(model.isFound || model.decodingPhoto)
            .accessibilityIdentifier("scanner.photo")
    }
    @ViewBuilder private var status: some View {
        switch model.event {
        case .scanning:
            Text(model.configuration.instruction).font(Geist.font(17, .medium)).multilineTextAlignment(.center)
        case .progress(let read, let total):
            VStack(spacing: 8) {
                Text("Part \(read) of \(total)").font(Geist.font(17, .semibold))
                Text("Keep the camera on the code until all parts are read").font(Geist.font(14)).foregroundStyle(.white.opacity(0.7))
            }.multilineTextAlignment(.center).accessibilityElement(children: .combine)
        case .found(let label):
            Text(label).font(Geist.font(15, .medium)).foregroundStyle(ScannerGuide.green)
                .multilineTextAlignment(.center).padding(.horizontal, 16).padding(.vertical, 10)
                .background(ScannerGuide.green.opacity(0.16), in: Capsule())
        case .wrong(let message):
            Text(message).font(Geist.font(15, .medium)).foregroundStyle(ScannerGuide.red)
                .multilineTextAlignment(.center).padding(16)
                .background(ScannerGuide.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    private var noCamera: some View {
        GeometryReader { area in
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "camera.fill").font(.system(size: 44)).accessibilityHidden(true)
                    VStack(spacing: 12) {
                        Text("Camera access is off").font(Geist.font(22, .medium)).accessibilityAddTraits(.isHeader)
                        Text("Allow camera access in Settings to scan QR codes. You can still paste or choose a photo.")
                            .font(Geist.font(15)).foregroundStyle(.white.opacity(0.7))
                    }.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)

                }.frame(maxWidth: 360).padding(24).frame(maxWidth: .infinity, minHeight: area.size.height)
            }.scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct ScannerGuidePreference: PreferenceKey {
    static let defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { let next = nextValue(); if !next.isEmpty { value = next } }
}
private struct ScannerMask: Shape {
    let hole: CGRect
    func path(in rect: CGRect) -> Path { var path = Path(rect); path.addRoundedRect(in: hole, cornerSize: CGSize(width: 28, height: 28)); return path }
}
struct ScannerGuide: View {
    let event: ScannerEvent
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var began = Date()
    static let green = Color(red: 18/255, green: 183/255, blue: 106/255)
    static let red = Color(red: 217/255, green: 45/255, blue: 32/255)
    private var found: Bool { if case .found = event { true } else { false } }
    private var color: Color { if found { Self.green } else if case .wrong = event { Self.red } else { .white } }
    var body: some View {
        GeometryReader { area in
            ZStack {
                if !reduceMotion && !found {
                    TimelineView(.animation(paused: !active)) { time in
                        let phase = time.date.timeIntervalSince(began).truncatingRemainder(dividingBy: 2.4) / 2.4
                        let travel = phase < 0.5 ? phase*2 : (1-phase)*2
                        Rectangle().fill(.white.opacity(0.7)).frame(height: 2)
                            .shadow(color: .white.opacity(0.7), radius: 7)
                            .opacity(0.2 + 0.8 * travel)
                            .position(x: area.size.width/2, y: area.size.height * (0.12 + 0.74*travel))
                    }.clipShape(RoundedRectangle(cornerRadius: 28))
                }
                if case .progress(let read, let total) = event {
                    RoundedRectangle(cornerRadius: 34).trim(from: 0, to: CGFloat(read)/CGFloat(max(1,total)))
                        .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round)).padding(-7)
                }
                ScannerCorners().stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: found && !reduceMotion) { view, scale in view.scaleEffect(scale) } keyframes: { _ in
                        LinearKeyframe(1.035, duration: 0.1); LinearKeyframe(1, duration: 0.1)
                    }
            }
        }
    }
}
private struct ScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Each bracket follows the 28 pt corner of the rounded guide.
        for corner in 0..<4 {
            var segment = Path()
            segment.move(to: CGPoint(x: 0, y: 28))
            segment.addQuadCurve(to: CGPoint(x: 28, y: 0), control: .zero)
            let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
                .rotated(by: CGFloat(corner) * .pi/2).translatedBy(x: -rect.width/2, y: -rect.height/2)
            path.addPath(segment, transform: transform)
        }
        return path
    }
}
