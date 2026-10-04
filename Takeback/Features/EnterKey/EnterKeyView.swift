import SwiftUI

struct EnterKeyView: View {
    @ObservedObject var router: WelcomeRouter
    @ObservedObject private var session: SecretSession
    @StateObject private var model: EnterKeyModel
    @State private var showsPassphrase = false
    @State private var editingKey = false
    @Environment(\.openURL) private var openURL

    init(router: WelcomeRouter, session: SecretSession, model: EnterKeyModel? = nil) {
        self.router = router
        self.session = session
        _model = StateObject(wrappedValue: model ?? EnterKeyModel(session: session))
    }

    var body: some View {
        LayoutReader { metrics in
            VStack(spacing: 0) {
                if metrics.mode == .split {
                    HStack(alignment: .top, spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) { introduction(metrics); memoryNote }
                                .frame(maxWidth: 440).padding(.top, 24)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .padding(.horizontal, 48).frame(maxWidth: .infinity)
                        ScrollView { form(metrics).frame(maxWidth: 440).padding(.top, 24) }
                            .scrollBounceBehavior(.basedOnSize)
                            .padding(.horizontal, 48).frame(maxWidth: .infinity)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            introduction(metrics)
                            form(metrics)
                            memoryNote
                        }
                        .frame(maxWidth: metrics.mode.columnMax)
                        .padding(.horizontal, metrics.mode.horizontalPadding)
                        .padding(.top, 24).padding(.bottom, 16)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .padding(.top, metrics.mode.topPadding)

        }
        .background(Theme.bg.ignoresSafeArea())
        .takebackStyle()
        .nativeNavigation()
        .background(NavigationEditingBoundary())
        .toolbar {
            if !editingKey {
                NativeBottomBar {
                    PrimaryButton(title: model.preparing ? "Finding payments…" : "Find pending payments", isEnabled: model.canFind, action: findPayments)
                        .accessibilityIdentifier("enterKey.find")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: router.openSettings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings").accessibilityIdentifier("enterKey.settings")
            }
        }
        .onAppear { model.refresh() }
        .onDisappear { model.suspend() }
        .sheet(isPresented: $showsPassphrase) {
            PassphraseSheet(session: session)
        }

    }
    private func findPayments() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task { if let plan = await model.prepareAccounts() { router.findPendingPayments(plan) } }
    }
    private func introduction(_ metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enter your key").font(Geist.font(metrics.mode.titleSize, .medium, relativeTo: .title))
                .accessibilityAddTraits(.isHeader)
            Text("The recovery phrase or private key of the wallet that sent the payment.")
                .font(Geist.font(15)).foregroundStyle(Theme.mute)
        }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func form(_ metrics: LayoutMetrics) -> some View {
        VStack(spacing: 12) {
            SmartSecretField(model: model, height: metrics.isShort ? 104 : metrics.mode == .compact ? 124 : 140, onFind: findPayments, onEditingChanged: { editingKey = $0 })
            HStack(alignment: .top, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(model.canFind ? Theme.fg : Theme.line).frame(width: 6, height: 6)
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }.accessibilityHidden(true)
                    Text(model.status).font(Geist.font(14, model.hasError ? .medium : .regular))
                        .foregroundStyle(model.hasError ? Theme.red : Theme.mute)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("enterKey.status")
                }.frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                HStack(spacing: 8) {
                    capsule("Scan", id: "enterKey.scan") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        router.openScanner { [weak model] bytes in model?.importScanned(bytes) }
                    }
                    capsule(model.hasInput ? "Clear" : "Paste", id: model.hasInput ? "enterKey.clear" : "enterKey.paste") {
                        if model.hasInput { model.clear() } else { model.paste() }
                    }
                }
            }
            if model.showsPassphrase { passphraseRow }
            if let plan = model.detection.searchPlan, !model.isDetecting {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    router.path.append(.searchPaths)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "list.bullet").font(.system(size: 20)).foregroundStyle(Theme.mute)
                        Text(plan.origin == .single ? "Address types" : "Search paths").font(Geist.font(16))
                        Spacer(minLength: 4)
                        Text((session.searchSelection ?? SearchDefaults.shared.selection).summary(for: plan)).font(Geist.font(15)).foregroundStyle(Theme.mute)
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.mute)
                    }.padding(.horizontal, 14).frame(minHeight: 52)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }.buttonStyle(.plain).accessibilityIdentifier("enterKey.paths")
            }
        }
    }
    private func capsule(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.custom(Geist.Weight.medium.rawValue, fixedSize: 14))
                .padding(.horizontal, 12).frame(height: 36)
                .overlay { Capsule().strokeBorder(Theme.line, lineWidth: 1) }
                .contentShape(Capsule())
        }.buttonStyle(.plain).fixedSize().accessibilityIdentifier(id)
    }
    private var passphraseRow: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            showsPassphrase = true
        } label: {
            ViewThatFits {
                passphraseLabel(fixed: false)
                passphraseLabel(fixed: true)
            }
            .padding(.horizontal, 14).frame(height: 52)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }.buttonStyle(.plain).accessibilityIdentifier("enterKey.passphrase")
    }
    private func passphraseLabel(fixed: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock").font(.system(size: 20)).foregroundStyle(Theme.mute)
            Text("Passphrase").font(fixed ? .custom(Geist.Weight.regular.rawValue, fixedSize: 16) : Geist.font(16))
                .fixedSize()
            Spacer(minLength: 4)
            Text(session.passphraseFingerprint.map { "•••••• · \(WalletFingerprints.formatted($0))" }
                 ?? (session.passphrase.count > 0 ? "••••••" : "None"))
                .font(fixed ? .custom(Geist.Weight.regular.rawValue, fixedSize: 15) : Geist.font(15))
                .monospacedDigit().foregroundStyle(Theme.mute).fixedSize()
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.mute)
        }
    }
    private var memoryNote: some View {
        NoteCard(symbol: "memorychip",
                 text: "Never saved. It’s wiped when you close the app or after you cancel.",
                 title: "Stays in memory only", titleSize: 14, titleWeight: .medium,
                 textColor: Theme.mute, footer: AnyView(sourceLink))
    }
    private var sourceLink: some View {
        Button {
            if let url = AppConfiguration.sourceRepositoryURL { openURL(url) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 13))
                Text("View the source code on GitHub").font(Geist.font(13, .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(Theme.mute)
            }.frame(minHeight: 28, alignment: .leading)
        }.buttonStyle(.plain).disabled(AppConfiguration.sourceRepositoryURL == nil)
            .accessibilityIdentifier("enterKey.source")
    }
}
