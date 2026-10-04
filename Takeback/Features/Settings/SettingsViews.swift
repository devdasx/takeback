import SwiftUI

struct SettingsPage<Content: View>: View {
    @ObservedObject var router: WelcomeRouter
    let title: String
    var subtitle: String? = nil
    var save: (() -> Void)? = nil
    var saveEnabled = false
    var hero: AnyView? = nil
    var centeredHeader = false
    @ViewBuilder let content: () -> Content
    var body: some View {
        LayoutReader { metrics in
            VStack(spacing: 0) {
                if metrics.mode == .split {
                    HStack(alignment: .top, spacing: 0) {
                        ScrollView { header(metrics).frame(maxWidth: 440).padding(.top, 24) }
                            .padding(.horizontal, 48).frame(maxWidth: .infinity)
                        list(metrics, header: false).padding(.horizontal, 48).frame(maxWidth: .infinity)
                    }
                } else {
                    list(metrics, header: true).frame(maxWidth: metrics.mode.columnMax)
                        .padding(.horizontal, metrics.mode.horizontalPadding).frame(maxWidth: .infinity)
                }
            }
        }.background(Theme.bg.ignoresSafeArea()).takebackStyle().nativeNavigation()
        .toolbar {
            if let save {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save).disabled(!saveEnabled)
                        .accessibilityIdentifier("server.save")
                }
            }
        }
    }
    private func header(_ metrics: LayoutMetrics) -> some View {
        VStack(alignment: centeredHeader ? .center : .leading, spacing: 12) {
            if let hero { hero }
            Text(title).font(Geist.font(metrics.mode.titleSize, .medium, relativeTo: .title)).accessibilityAddTraits(.isHeader).accessibilityIdentifier("settings.title")
            if let subtitle { Text(subtitle).font(Geist.font(15)).foregroundStyle(Theme.mute) }
        }.multilineTextAlignment(centeredHeader ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: centeredHeader ? .center : .leading)
    }
    private func list(_ metrics: LayoutMetrics, header showHeader: Bool) -> some View {
        List {
            if showHeader { header(metrics).padding(.top, 24).padding(.bottom, 28).listRowInsets(EdgeInsets()).listRowSeparator(.hidden).listRowBackground(Color.clear) }
            content().listRowInsets(EdgeInsets()).listRowSeparator(.hidden).listRowBackground(Color.clear)
        }
        .listStyle(.plain).scrollContentBackground(.hidden).environment(\.defaultMinListRowHeight, 0)
        .listSectionSpacing(.custom(24)).scrollDismissesKeyboard(.interactively)
    }
}

struct SettingsView: View {
    @ObservedObject var router: WelcomeRouter
    @ObservedObject var preferences: NetworkPreferences = .shared
    @ObservedObject var searchDefaults: SearchDefaults = .shared
    @AppStorage("defaultFee") private var fee = FeeSpeed.fast.rawValue
    var body: some View {
        SettingsPage(router: router, title: "Settings", subtitle: "No accounts, no history and no wallet. Keys are never saved.") {
            Section {
                IndexRow(symbol: "bolt", title: "Default fee", value: (FeeSpeed(rawValue: fee).flatMap { $0 == .custom ? nil : $0 } ?? .fast).title) { router.path.append(.defaultFee) }.accessibilityIdentifier("settings.fee")
            } header: { SectionHeader(title: "Fees") }
            Section {
                IndexRow(symbol: "globe", title: "Servers", value: preferences.usesOwnServer ? "Only my servers" : "Automatic", action: router.openServerSettings).accessibilityIdentifier("settings.server")
            } header: { SectionHeader(title: "Network") }
            Section {
                SearchDepthControls(accounts: $searchDefaults.accounts, addresses: $searchDefaults.addresses)
            } header: { SectionHeader(title: "Search") }
            Section {
                IndexRow(symbol: "info.circle", title: "About Takeback", value: AppConfiguration.version) { router.path.append(.about) }.accessibilityIdentifier("settings.about")
            } header: { SectionHeader(title: "About") }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("route.settings")
    }
}

struct SettingsRadio: View {
    @Environment(\.displayScale) private var displayScale
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(Geist.font(16)).foregroundStyle(Theme.fg)
                    Text(subtitle).font(Geist.font(13)).foregroundStyle(Theme.mute)
                }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.system(size: 22)).foregroundStyle(selected ? Theme.fg : Theme.line).accessibilityHidden(true)
            }.padding(.vertical, 18).contentShape(Rectangle())
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1 / displayScale) }
        }.buttonStyle(.plain).accessibilityValue(selected ? "Selected" : "Not selected").accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct DefaultFeeView: View {
    @ObservedObject var router: WelcomeRouter
    @ObservedObject var preferences: NetworkPreferences = .shared
    @AppStorage("defaultFee") private var fee = FeeSpeed.fast.rawValue
    @State private var rates: FeeRecommendations?
    var previewRates: FeeRecommendations? = nil
    var body: some View {
        SettingsPage(router: router, title: "Default fee", subtitle: "Used every time you speed up or cancel. You can still change it on each one.") {
            ForEach([FeeSpeed.nextBlock, .fast, .medium], id: \.rawValue) { speed in
                SettingsRadio(title: speed == .fast ? "Fast · Recommended" : speed.title, subtitle: subtitle(speed), selected: selected == speed) { fee = speed.rawValue }
                    .accessibilityIdentifier("defaultFee.\(speed.rawValue)")
            }
        }.task {
            if let previewRates { rates = previewRates; return }
            #if DEBUG
            if SettingsFixtures.isUITest { rates = SettingsFixtures.rates; return }
            #endif
            rates = try? await ChainService(configuration: preferences.configuration).fees()
        }
    }
    private var selected: FeeSpeed { let speed = FeeSpeed(rawValue: fee) ?? .fast; return speed == .custom ? .fast : speed }
    private func subtitle(_ speed: FeeSpeed) -> String {
        let text = speed == .nextBlock ? "Fastest · highest fee" : speed == .fast ? "~10 min" : "~30 min · cheaper"
        return text + (rates.flatMap { speed.rate($0) }.map { " · \(PaymentText.rate($0))" } ?? "")
    }
}

struct ServerSettingsView: View {
    @ObservedObject var router: WelcomeRouter
    @ObservedObject var preferences: NetworkPreferences
    @StateObject var model: ServerSettingsModel
    @AppStorage("showUSD") private var showUSD = true
    @State private var adding = false
    @State private var host = ""
    @State private var tcp = false
    init(router: WelcomeRouter, preferences: NetworkPreferences = .shared, model: ServerSettingsModel? = nil) {
        self.router = router; self.preferences = preferences
        _model = StateObject(wrappedValue: model ?? ServerSettingsModel(preferences: preferences))
    }
    var body: some View {
        SettingsPage(router: router, title: "Servers", subtitle: "Takeback talks only to Electrum servers that support batch requests.") {
            SettingsRadio(title: "Automatic · Recommended", subtitle: "Picks the fastest working server from the public list", selected: !preferences.usesOwnServer) { preferences.setMode(onlyMine: false) }.accessibilityIdentifier("server.default")
            SettingsRadio(title: "Only my servers", subtitle: "Uses the list below, in order", selected: preferences.usesOwnServer) { preferences.setMode(onlyMine: true) }.accessibilityIdentifier("server.own")
            Section {
                ForEach(preferences.backups) { item in
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.server.endpoint).font(Geist.font(16)).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 6) {
                                if model.checking.contains(item.server.id) { ProgressView(); Text("Checking…") }
                                else if let result = model.probes[item.server.id] {
                                    Circle().fill(result.state == .batch ? Theme.green : result.state == .noBatch ? Theme.mute : Theme.red).frame(width: 6, height: 6)
                                    Text(result.failure == .certificateChanged ? "This server’s certificate changed" : result.label)
                                } else { Text("Checking…") }
                            }.font(Geist.font(13)).foregroundStyle(Theme.mute)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Toggle(item.server.host, isOn: Binding(get: { item.enabled }, set: { preferences.setEnabled(item, $0) }))
                            .labelsHidden().tint(Theme.fg).accessibilityIdentifier("server.backup.\(item.server.host)")
                    }.padding(.vertical, 16)
                        .swipeActions { if !item.isDefault { Button("Delete", role: .destructive) { preferences.delete(item) } } }
                        .moveDisabled(!preferences.usesOwnServer)
                }.onMove(perform: preferences.move)
                Button("Add server…") { host = ""; tcp = false; adding = true }.font(Geist.font(16)).frame(minHeight: 52).accessibilityIdentifier("server.add")
                Button("Check all servers") { model.checkAll(force: true) }.font(Geist.font(16)).frame(minHeight: 52)
            } header: { SectionHeader(title: "Servers") }
            Text("Default list from Muun’s open-source recovery tool · \(ElectrumSeed.bundled.commit.prefix(7))").font(Geist.font(13)).foregroundStyle(Theme.mute).padding(.vertical, 16)
            Toggle("Show amounts in USD", isOn: $showUSD).font(Geist.font(16)).tint(Theme.fg).padding(.vertical, 16)
        }.environment(\.editMode, .constant(preferences.usesOwnServer ? .active : .inactive))
            .accessibilityElement(children: .contain).accessibilityIdentifier("route.settings.server")
            .task { model.checkAll() }.onDisappear { model.stop() }
            .sheet(isPresented: $adding) {
                NavigationStack {
                    Form {
                        TextField("host:port", text: $host).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        if ServerAddress.electrum(host)?.host.hasSuffix(".onion") == true { Toggle("Use TCP", isOn: $tcp) }
                        if model.adding { ProgressView("Checking…") }
                        if let error = model.addError { Text(error).foregroundStyle(Theme.red) }
                    }.font(Geist.font(16)).navigationTitle("Add server…").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { adding = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("Add") { model.add(host, useTCP: tcp) }.disabled(model.adding || ServerAddress.electrum(host) == nil) }
                        }
                }.presentationDetents([.medium, .large])
                    .onChange(of: model.adding) { old, new in if old && !new && model.addError == nil { adding = false } }
            }
    }
}
