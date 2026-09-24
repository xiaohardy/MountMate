import SwiftUI
import MountMateCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedTab = 0
    @State private var editingShare: ManagedShare?
    @State private var showingImport = false
    @State private var handledAddShareRequest = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                onAddShare: { editingShare = ManagedShare(name: "", address: "smb://") },
                onImportMount: { showingImport = true },
                onShowSettings: { selectedTab = 2 }
            )
                .tabItem { Label(model.t("overview"), systemImage: "square.grid.2x2") }
                .tag(0)
            SharesSettingsView(editingShare: $editingShare)
                .tabItem { Label(model.t("pinnedMounts"), systemImage: "server.rack") }
                .tag(1)
            CleanupSettingsView()
                .tabItem { Label(model.t("cleanupRules"), systemImage: "externaldrive.badge.minus") }
                .tag(2)
            ActivityView()
                .tabItem { Label(model.t("activityLog"), systemImage: "clock.arrow.circlepath") }
                .tag(3)
        }
        .padding(16)
        .frame(minWidth: 700, minHeight: 540)
        .sheet(item: $editingShare) { share in
            ShareEditorView(original: share)
                .environmentObject(model)
        }
        .sheet(isPresented: $showingImport) {
            ImportMountsView().environmentObject(model)
        }
        .onAppear(perform: handleAddShareRequest)
        .onChange(of: model.addShareRequest) { _, _ in handleAddShareRequest() }
    }

    private func handleAddShareRequest() {
        guard model.addShareRequest != handledAddShareRequest else { return }
        handledAddShareRequest = model.addShareRequest
        selectedTab = 1
        editingShare = ManagedShare(name: "", address: "smb://")
    }
}

private struct SharesSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var editingShare: ManagedShare?
    @State private var removalID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(model.t("favoriteSMBShares")).font(.title3.weight(.semibold))
                    Text(model.t("favoriteSharesDescription"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.t("addShare")) {
                    editingShare = ManagedShare(name: "", address: "smb://")
                }
                .disabled(model.storageIssue != nil)
            }
            Divider()
            if model.settings.shares.isEmpty {
                ContentUnavailableView(model.t("noFavoriteShares"), systemImage: "server.rack",
                                       description: Text(model.t("addSMBHelp")))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.settings.shares) { share in
                            HStack(spacing: 12) {
                                Image(systemName: "server.rack").font(.title3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(share.name).fontWeight(.medium)
                                    Text(share.address).font(.caption).foregroundStyle(.secondary)
                                    Text("\(model.statusTitle(for: share)) · \(model.t(share.keepConnected ? "keepConnected" : "manualOnly"))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(model.t("edit")) { editingShare = share }
                                    .disabled(model.storageIssue != nil)
                                Button(model.t("remove"), role: .destructive) { removalID = share.id }
                                    .disabled(model.storageIssue != nil)
                            }
                            .padding(10)
                            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            Divider()
            Toggle(model.t("launchAtLogin"), isOn: Binding(
                get: { model.loginEnabled },
                set: { model.setLoginEnabled($0) }
            ))
            Text(model.t("keepRunningHelp"))
                .font(.caption).foregroundStyle(.secondary)
            if let issue = model.loginIssue { Text(issue).font(.caption).foregroundStyle(.orange) }
        }
        .confirmationDialog(model.t("confirmRemoveShare"), isPresented: Binding(
            get: { removalID != nil },
            set: { if !$0 { removalID = nil } }
        )) {
            Button(model.t("remove"), role: .destructive) {
                if let removalID { model.removeShare(removalID) }
                removalID = nil
            }
        }
    }
}

private struct ShareEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var share: ManagedShare
    @State private var password = ""
    @State private var error: String?
    private let isNew: Bool

    init(original: ManagedShare) {
        _share = State(initialValue: original)
        isNew = original.name.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.t(isNew ? "addSMBShare" : "editSMBShare"))
                .font(.title3.weight(.semibold))
            Form {
                TextField(model.t("name"), text: $share.name)
                TextField(model.t("address"), text: $share.address)
                    .textContentType(.URL)
                Toggle(model.t("guestAccess"), isOn: $share.guestAccess)
                if !share.guestAccess {
                    TextField(model.t("username"), text: $share.username)
                    Toggle(model.t("useSavedCredentials"), isOn: Binding(
                        get: { share.useSystemCredentials == true },
                        set: { share.useSystemCredentials = $0 }
                    ))
                    if share.useSystemCredentials != true {
                        SecureField(model.t(isNew ? "password" : "newPasswordHint"), text: $password)
                    }
                }
                Toggle(model.t("keepConnected"), isOn: $share.keepConnected)
                Toggle(model.t("protectShareDuringCleanup"), isOn: $share.protectFromCleanup)
                    .disabled(share.keepConnected)
            }
            Text(model.t(share.useSystemCredentials == true && !share.guestAccess ?
                         "savedCredentialsHelp" : "shareAddressHelp"))
                .font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(model.t("cancel")) { dismiss() }
                Button(model.t("save")) {
                    error = model.updateShare(share, newPassword: password.isEmpty ? nil : password)
                    if error == nil { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.storageIssue != nil)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}

private struct CleanupSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section(model.t("cleanupScope")) {
                ForEach(MountKind.allCases) { kind in
                    Toggle(model.kindTitle(kind), isOn: Binding(
                        get: { model.settings.cleanup.kinds.contains(kind) },
                        set: { model.setCleanupKind(kind, enabled: $0) }
                    ))
                }
                Text(model.t("cleanupScopeHelp"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(model.t("dailyCleanup")) {
                Toggle(model.t("enableDailyCleanup"), isOn: Binding(
                    get: { model.settings.cleanup.dailyEnabled },
                    set: { model.setDailyCleanup(enabled: $0, hour: model.settings.cleanup.hour, minute: model.settings.cleanup.minute) }
                ))
                HStack {
                    Text(model.t("executionTime"))
                    Spacer()
                    HStack(spacing: 4) {
                        Picker(model.t("hour"), selection: Binding(
                            get: { model.settings.cleanup.hour },
                            set: { model.setDailyCleanup(enabled: model.settings.cleanup.dailyEnabled, hour: $0, minute: model.settings.cleanup.minute) }
                        )) {
                            ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 72)
                        Text(":").font(.headline.monospacedDigit())
                        Picker(model.t("minute"), selection: Binding(
                            get: { model.settings.cleanup.minute },
                            set: { model.setDailyCleanup(enabled: model.settings.cleanup.dailyEnabled, hour: model.settings.cleanup.hour, minute: $0) }
                        )) {
                            ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 72)
                    }
                }
                Text(model.t("dailyCleanupTimeHelp"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(model.t("protectionList")) {
                if model.settings.cleanup.protectedIDs.isEmpty {
                    Text(model.t("emptyProtectionList"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.settings.cleanup.protectedIDs.sorted(), id: \.self) { id in
                        HStack {
                            Text(model.volumes.first(where: { $0.stableID == id })?.name ?? id)
                                .lineLimit(1)
                            Spacer()
                            Button(model.t("remove")) { model.removeProtectedID(id) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .disabled(model.storageIssue != nil)
    }
}

private struct ActivityView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.t("recentActivity")).font(.title3.weight(.semibold))
            Text(model.t("activityPrivacyHelp"))
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            if model.settings.events.isEmpty {
                ContentUnavailableView(model.t("noActivity"), systemImage: "clock")
            } else {
                List(model.settings.events) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.message)
                        Text(event.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
