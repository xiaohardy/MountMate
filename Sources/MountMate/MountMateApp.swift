import AppKit
import SwiftUI
import MountMateCore

@main
struct MountMateApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("MountMate", id: "main") {
            SettingsView()
                .environmentObject(model)
        }
        .defaultSize(width: 760, height: 600)

        MenuBarExtra {
            StatusMenuView()
                .environmentObject(model)
        } label: {
            Image(nsImage: StatusIcon.make(state: model.starSnapshot))
                .renderingMode(.original)
                .accessibilityLabel("MountMate")
        }
    }
}

private struct StatusMenuView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(model.t("openMountMate")) { showMainWindow() }
        Button(model.t("addShareEllipsis")) {
            model.requestAddShare()
            showMainWindow()
        }
        .disabled(model.storageIssue != nil)
        Divider()
        ForEach(model.settings.shares) { share in
            Button("\(share.name) · \(model.statusTitle(for: share))") {
                showMainWindow()
            }
        }
        if !model.settings.shares.isEmpty { Divider() }
        Button(model.t("refreshMounts")) { model.refresh() }
        Button(model.t("cleanupTemporaryCount", ["count": String(model.cleanupCandidates.count)])) {
            model.cleanNow()
        }
            .disabled(model.isCleaning || model.cleanupCandidates.isEmpty || model.storageIssue != nil)
        Divider()
        Button(model.t("quitMountMate")) { NSApplication.shared.terminate(nil) }
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
