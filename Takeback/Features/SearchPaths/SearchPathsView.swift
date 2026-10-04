import SwiftUI

struct SearchDepthControls: View {
    @Binding var accounts: Int
    @Binding var addresses: Int
    var showAccounts = true
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showAccounts {
                Stepper(value: $accounts, in: 1...10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Accounts per type").font(Geist.font(16))
                        Text(accounts == 1 ? "Account 0 only · m/84'/0'/0'" : "Accounts 0–\(accounts - 1)")
                            .font(Geist.font(13)).foregroundStyle(Theme.mute)
                    }.fixedSize(horizontal: false, vertical: true)
                }.accessibilityIdentifier("search.accounts")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Addresses per path").font(Geist.font(16))
                Picker("Addresses per path", selection: $addresses) {
                    ForEach(SearchDefaults.depths, id: \.self) { Text("\($0)").tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("search.depth")
                Text("Each path checks this many receive and change addresses. Most wallets use 20.")
                    .font(Geist.font(13)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.vertical, 16)
    }
}

struct SearchPathsView: View {
    @ObservedObject var router: WelcomeRouter
    @ObservedObject var session: SecretSession
    @State private var editor: SearchPath?
    @State private var attemptedDone = false
    private var detection: KeyDetection { detectKey(session.key) }
    private var plan: KeySearchPlan? { detection.searchPlan }
    private var selection: SearchSelection { session.searchSelection ?? SearchDefaults.shared.selection }
    private var single: Bool { plan?.origin == .single }
    private func update(_ body: (inout SearchSelection) -> Void) { var next = selection; body(&next); session.searchSelection = next }
    var body: some View {
        LayoutReader { metrics in
            VStack(spacing: 16) {
                AdaptiveLayout(metrics: metrics) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(detection.label(settled: true)).font(Geist.font(13)).foregroundStyle(Theme.mute)
                        Text(single ? "Address types" : "Search paths").font(Geist.font(metrics.mode.titleSize, .medium)).accessibilityAddTraits(.isHeader)
                        Text(single ? "A single key has one address of each type. Choose which ones to check." : "Where Takeback looks for your payments. The standard paths cover almost every wallet.")
                            .font(Geist.font(15)).foregroundStyle(Theme.mute)
                    }.fixedSize(horizontal: false, vertical: true)
                } content: {
                    if let plan {
                        contents(plan)
                        Text(summary(plan)).font(Geist.font(13)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
                        if attemptedDone && !selection.isValid(for: plan) {
                            Text("Turn on at least one path").font(Geist.font(14, .medium)).foregroundStyle(Theme.red)
                        }
                    }
                }
            }
        }.background(Theme.bg.ignoresSafeArea()).takebackStyle().nativeNavigation()
        .toolbar {
            NativeBottomBar {
                if let plan {
                    PrimaryButton(title: "Done") {
                        attemptedDone = true
                        if selection.isValid(for: plan) { router.goBack() }
                    }.accessibilityIdentifier("paths.done")
                }
            }
        }
            .onAppear { session.ensureSearchSelection() }
            .onChange(of: session.wipeGeneration) { _, _ in editor = nil; router.backToKey() }
            .sheet(item: $editor) { path in
                SearchPathSheet(session: session, initial: path, editing: selection.custom.contains { $0.id == path.id })
            }
    }
    private func summary(_ plan: KeySearchPlan) -> String {
        let total = selection.total(for: plan)
        if single { return "Checks \(total) \(total == 1 ? "address" : "addresses")" }
        return "Checks \(total) addresses on \(selection.paths(for: plan).count) paths" + (total > 2000 ? " · may take a little longer" : "")
    }
    private func contents(_ plan: KeySearchPlan) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 0) {
                section(single ? "Check these addresses" : "Standard", value: "\(selection.enabledTypes(for: plan).count) of 4")
                ForEach(plan.types, id: \.self) { type in
                    Toggle(isOn: Binding(get: { selection.enabled.contains(type) }, set: { value in update { if value { $0.enabled.insert(type) } else { $0.enabled.remove(type) } } })) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(type.title).font(Geist.font(16))
                            Text(single ? (type == .bip49 ? "P2SH-P2WPKH · 3…" : type.subtitle) : standardSubtitle(type, plan: plan))
                                .font(Geist.font(13)).foregroundStyle(Theme.mute)
                        }.fixedSize(horizontal: false, vertical: true)
                    }.tint(Theme.fg).padding(.vertical, 16).accessibilityIdentifier("paths.type.\(type.rawValue)")
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
            }
            if single {
                Text("Derivation paths apply only to recovery phrases and extended keys (xprv). An uncompressed WIF only has a Legacy address.")
                    .font(Geist.font(13)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    section("Custom", value: "\(selection.custom.count)")
                    if plan.isAccount {
                        Text("Custom paths need a recovery phrase or root xprv").font(Geist.font(13)).foregroundStyle(Theme.mute).padding(.vertical, 16)
                    } else {
                        ForEach(selection.custom) { path in
                            IndexRow(symbol: "list.bullet", title: path.title, subtitle: path.subtitle) { editor = path }
                                .accessibilityIdentifier("paths.custom.\(path.id)")
                        }
                        Button { editor = SearchPath(components: [], scriptType: .bip84) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "plus").font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.bg).frame(width: 32, height: 32).background(Theme.fg, in: Circle())
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Add path").font(Geist.font(16))
                                    Text("Another account, an old wallet or any path").font(Geist.font(13)).foregroundStyle(Theme.mute)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(.vertical, 18).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("paths.add")
                        Text("Use this if your wallet used another account or a non-standard path. Ask your wallet’s support or check its settings for the path.")
                            .font(Geist.font(13)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    section("Search depth")
                    SearchDepthControls(accounts: Binding(get: { selection.accounts }, set: { v in update { $0.accounts = v } }),
                                        addresses: Binding(get: { selection.addressesPerPath }, set: { v in update { $0.addressesPerPath = v } }), showAccounts: !plan.isAccount)
                }
            }
        }
    }
    private func standardSubtitle(_ type: AddressStandard, plan: KeySearchPlan) -> String {
        let account: Int
        if case .account(let n) = plan.origin { account = Int(n & 0x7fffffff) } else { account = 0 }
        return "BIP\(type.rawValue) · \(SearchPath.standard(type, account: account).path)"
    }
    private func section(_ title: String, value: String? = nil) -> some View {
        HStack { SectionHeader(title: title); Spacer(); if let value { Text(value).font(Geist.font(13)).foregroundStyle(Theme.mute) } }
    }
}
