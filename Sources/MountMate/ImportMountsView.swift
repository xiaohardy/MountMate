import SwiftUI
import MountMateCore

struct ImportMountsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.t("selectSMBMounts"))
                    .font(.title3.weight(.semibold))
                Spacer()
                if model.isScanning { ProgressView().controlSize(.small) }
                Button(model.t("scanAgain")) { model.refresh() }
                    .disabled(model.isScanning)
            }
            Text(model.t("importHelp"))
                .font(.caption).foregroundStyle(.secondary)
            Divider()

            if model.volumes.isEmpty {
                ContentUnavailableView(model.t("noCurrentMounts"), systemImage: "externaldrive")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.volumes) { volume in
                            row(for: volume)
                        }
                    }
                }
                .frame(minHeight: 225)
            }

            if model.importCandidates.isEmpty {
                Text(model.t("noImportableSMB"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(model.t("importNeedsCredential"))
                .font(.caption2).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(model.t("cancel")) { dismiss() }
                Button(model.t("importSelectedCount", ["count": String(selectedIDs.count)])) {
                    if model.importCurrentSMBShares(selectedIDs) > 0 { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIDs.isEmpty || model.isScanning || model.storageIssue != nil)
            }
        }
        .padding(20)
        .frame(width: 570, height: 430)
        .onAppear { model.refresh() }
        .onChange(of: model.volumes) { _, _ in
            selectedIDs.formIntersection(Set(model.importCandidates.map(\.id)))
        }
    }

    private func row(for volume: MountedVolume) -> some View {
        let candidate = ShareImport.candidate(from: volume)
        let available = model.importCandidates.contains { $0.id == volume.id }
        let note = candidate == nil ? model.t("smbOnlyImport") :
            (available ? candidate!.address : model.t("alreadyAdded"))
        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { selectedIDs.contains(volume.id) },
                set: { if $0 { selectedIDs.insert(volume.id) } else { selectedIDs.remove(volume.id) } }
            ))
            .labelsHidden()
            .disabled(!available)
            Image(systemName: volume.kind == .network ? "network" : "externaldrive")
                .frame(width: 20).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(volume.name).lineLimit(1)
                Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(model.kindTitle(volume.kind))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(9)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }
}
