import AppKit
import SwiftUI
import MountMateCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedIDs: Set<String> = []
    let onAddShare: () -> Void
    let onImportMount: () -> Void
    let onShowSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("MountMate").font(.headline)
                Spacer()
                Picker(model.t("language"), selection: Binding(
                    get: { model.language },
                    set: { model.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language == .system ? model.t("systemLanguage") : language.nativeName)
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 190)
                if model.isScanning {
                    ProgressView().controlSize(.small)
                        .help(model.t("scanningMounts"))
                }
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .disabled(model.isScanning)
                    .help(model.t("refreshMounts"))
            }
            Text(model.t("appSubtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let issue = model.storageIssue {
                Label(issue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack {
                sectionTitle(model.t("pinnedMounts"), count: model.settings.shares.count)
                Spacer()
                Button(model.t("addFromCurrentMounts")) { onImportMount() }
                Button(model.t("addShare")) { onAddShare() }
                    .buttonStyle(.borderedProminent)
            }
            if model.settings.shares.isEmpty {
                emptyMessage(model.t("noSharesDashboard"))
            } else {
                ForEach(model.settings.shares) { share in
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .frame(width: 20).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(share.name).lineLimit(1)
                            Text(model.statusTitle(for: share))
                                .font(.caption)
                                .foregroundStyle(statusColor(model.status(for: share)))
                        }
                        Spacer()
                        if model.mountedVolume(for: share) != nil {
                            Button(model.t("disconnectAndPause")) { model.disconnect(share.id) }
                                .controlSize(.small)
                        } else {
                            Button(model.t(share.paused ? "resumeConnection" : "connect")) {
                                model.connectNow(share.id)
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()
            sectionTitle(model.t("currentMounts"), count: model.volumes.count)
            if model.volumes.isEmpty {
                emptyMessage(model.t("noCurrentMounts"))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        ForEach(model.volumes) { volume in volumeRow(volume) }
                    }
                }
                .frame(maxHeight: 245)
            }

            HStack {
                Button(model.t("cleanupTemporaryCount", ["count": String(model.cleanupCandidates.count)])) {
                    model.cleanNow()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isCleaning || model.cleanupCandidates.isEmpty)
                Button(model.t("unmountSelected")) {
                    model.unmountSelected(selectedIDs)
                    selectedIDs.removeAll()
                }
                .disabled(model.isCleaning || selectedIDs.isEmpty)
                Spacer()
            }
            Text(model.t("cleanupExplanation"))
                .font(.caption2).foregroundStyle(.secondary)

            Divider()
            Button { onShowSettings() } label: {
                Label(model.t("viewCleanupRules"), systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: model.volumes) { _, current in
            selectedIDs.formIntersection(Set(current.map(\.id)))
        }
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold))
            Text("\(count)").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func emptyMessage(_ message: String) -> some View {
        Text(message)
            .font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
    }

    private func volumeRow(_ volume: MountedVolume) -> some View {
        let managed = model.settings.shares.contains {
            SMBAddress($0.address)?.key == SMBAddress.key(forMountSource: volume.source) && $0.keepConnected
        }
        return HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { selectedIDs.contains(volume.id) },
                set: { if $0 { selectedIDs.insert(volume.id) } else { selectedIDs.remove(volume.id) } }
            ))
            .labelsHidden()
            .help(model.t("selectForBatchUnmount"))
            Image(systemName: icon(for: volume.kind))
                .frame(width: 18).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name).lineLimit(1)
                Text(model.kindTitle(volume.kind))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.toggleProtection(volume) } label: {
                Label(model.t(managed ? "autoProtected" :
                              (model.isProtected(volume) ? "removeProtection" : "protect")),
                      systemImage: model.isProtected(volume) ? "shield.fill" : "shield")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(managed)
            .help(model.t(managed ? "alwaysProtectKeptShare" :
                          (model.isProtected(volume) ? "removeProtection" : "addToProtectionList")))
            Button { model.unmountOne(volume) } label: {
                Label(model.t("unmount"), systemImage: "eject")
            }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(model.t("unmountMountHelp"))
        }
        .padding(.vertical, 2)
    }

    private func icon(for kind: MountKind) -> String {
        switch kind {
        case .diskImage: return "shippingbox"
        case .usb: return "externaldrive"
        case .external: return "externaldrive.fill"
        case .network: return "network"
        }
    }

    private func statusColor(_ status: ShareStatus) -> Color {
        switch status {
        case .mounted: return .green
        case .unhealthy, .needsPassword: return .orange
        default: return .secondary
        }
    }
}
