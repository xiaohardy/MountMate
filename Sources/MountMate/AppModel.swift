import AppKit
import Combine
import Darwin
import Foundation
import Network
import ServiceManagement
import MountMateCore

enum ShareStatus: Equatable {
    case disconnected
    case connecting
    case mounted
    case checking
    case unhealthy
    case waiting
    case needsPassword
    case paused

    var localizationKey: String {
        switch self {
        case .disconnected: return "statusDisconnected"
        case .connecting: return "statusConnecting"
        case .mounted: return "statusMounted"
        case .checking: return "statusChecking"
        case .unhealthy: return "statusUnhealthy"
        case .waiting: return "statusWaiting"
        case .needsPassword: return "statusNeedsPassword"
        case .paused: return "statusPaused"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var volumes: [MountedVolume] = []
    @Published private(set) var shareStatuses: [UUID: ShareStatus] = [:]
    @Published private(set) var starSnapshot: MountStarSnapshot = .empty
    @Published private(set) var isCleaning = false
    @Published private(set) var isScanning = false
    @Published private(set) var storageIssue: String?
    @Published private(set) var loginIssue: String?
    @Published private(set) var addShareRequest = 0

    private let networkMonitor = NWPathMonitor()
    private var networkAvailable = true
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?
    private var sleeping = false
    private var connecting: Set<UUID> = []
    private var authFailures: Set<UUID> = []
    private var retryCount: [UUID: Int] = [:]
    private var nextRetry: [UUID: Date] = [:]
    private var probes: [UUID: UUID] = [:]
    private var lastProbe: [UUID: Date] = [:]
    private var starState = MountStarState()
    private var refreshPending = false

    init() {
        do { settings = try SettingsStore.load() }
        catch {
            settings = AppSettings()
            storageIssue = L10n.text("settingsReadFailed", language: .system,
                                     arguments: ["path": SettingsStore.fileURL.path])
        }
        updateStarSnapshot()
        startObserving()
        refresh()
    }

    deinit {
        networkMonitor.cancel()
        timer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let mountObserver { NSWorkspace.shared.notificationCenter.removeObserver(mountObserver) }
        if let unmountObserver { NSWorkspace.shared.notificationCenter.removeObserver(unmountObserver) }
    }

    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    var language: AppLanguage { settings.language ?? .system }

    func t(_ key: String, _ arguments: [String: String] = [:]) -> String {
        L10n.text(key, language: language, arguments: arguments)
    }

    func statusTitle(for share: ManagedShare) -> String { t(status(for: share).localizationKey) }

    func kindTitle(_ kind: MountKind) -> String {
        switch kind {
        case .diskImage: return t("kindDiskImage")
        case .usb: return t("kindUSB")
        case .external: return t("kindExternal")
        case .network: return t("kindNetwork")
        }
    }

    func setLanguage(_ language: AppLanguage) {
        mutate { $0.language = language == .system ? nil : language }
    }

    func requestAddShare() { addShareRequest += 1 }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginIssue = nil
            objectWillChange.send()
        } catch {
            loginIssue = t("launchAtLoginFailed", ["error": error.localizedDescription])
            addEvent(loginIssue!)
        }
    }

    func refresh() {
        guard !isScanning else { refreshPending = true; return }
        isScanning = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let current = VolumeScanner.scan()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.volumes = current
                self.isScanning = false
                self.reconcileShares()
                self.updateStarSnapshot()
                if self.refreshPending {
                    self.refreshPending = false
                    self.refresh()
                }
            }
        }
    }

    func status(for share: ManagedShare) -> ShareStatus {
        if share.paused { return .paused }
        return shareStatuses[share.id] ?? .disconnected
    }

    func mountedVolume(for share: ManagedShare) -> MountedVolume? {
        guard let key = SMBAddress(share.address)?.key else { return nil }
        return volumes.first { SMBAddress.key(forMountSource: $0.source) == key }
    }

    var importCandidates: [SMBImportCandidate] {
        ShareImport.candidates(from: volumes, excluding: settings.shares)
    }

    @discardableResult
    func importCurrentSMBShares(_ selectedIDs: Set<String>) -> Int {
        let chosen = importCandidates.filter { selectedIDs.contains($0.id) }
        guard !chosen.isEmpty else { return 0 }
        mutate { value in
            for candidate in chosen {
                value.shares.append(ManagedShare(name: candidate.name, address: candidate.address,
                                                username: candidate.username, guestAccess: false,
                                                useSystemCredentials: true, keepConnected: true,
                                                protectFromCleanup: true))
            }
        }
        addEvent(t("importSuccessCount", ["count": String(chosen.count)]))
        refresh()
        return chosen.count
    }

    func connectNow(_ id: UUID) {
        guard let share = settings.shares.first(where: { $0.id == id }) else { return }
        if share.paused {
            mutate { value in
                guard let index = value.shares.firstIndex(where: { $0.id == id }) else { return }
                value.shares[index].paused = false
            }
        }
        authFailures.remove(id)
        nextRetry.removeValue(forKey: id)
        attemptConnect(id)
        refresh()
    }

    func disconnect(_ id: UUID) {
        guard let share = settings.shares.first(where: { $0.id == id }),
              let volume = mountedVolume(for: share) else { return }
        pauseShare(id)
        Task {
            await unmountVerified(volume, reason: t("reasonManualDisconnect"))
            refresh()
        }
    }

    func updateShare(_ share: ManagedShare, newPassword: String?) -> String? {
        guard SMBAddress(share.address) != nil else { return t("invalidSMBAddress") }
        guard !share.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return t("missingShareName") }
        let key = SMBAddress(share.address)!.key
        if settings.shares.contains(where: { $0.id != share.id && SMBAddress($0.address)?.key == key }) {
            return t("duplicateSMBShare")
        }
        var updatedShare = share
        if !share.guestAccess, let newPassword, !newPassword.isEmpty {
            updatedShare.useSystemCredentials = false
        }
        if !updatedShare.guestAccess && updatedShare.useSystemCredentials != true &&
            (updatedShare.username.isEmpty || ((newPassword ?? "").isEmpty && PasswordStore.read(for: share.id) == nil)) {
            return t("credentialsRequired")
        }
        if !updatedShare.guestAccess, let newPassword, !newPassword.isEmpty {
            do { try PasswordStore.save(newPassword, for: share.id) }
            catch { return error.localizedDescription }
        }
        if updatedShare.guestAccess {
            updatedShare.useSystemCredentials = false
            PasswordStore.delete(for: share.id)
        }
        if updatedShare.useSystemCredentials == true { PasswordStore.delete(for: share.id) }
        mutate { value in
            if let index = value.shares.firstIndex(where: { $0.id == share.id }) { value.shares[index] = updatedShare }
            else { value.shares.append(updatedShare) }
        }
        authFailures.remove(share.id)
        nextRetry.removeValue(forKey: share.id)
        refresh()
        return nil
    }

    func removeShare(_ id: UUID) {
        mutate { $0.shares.removeAll { $0.id == id } }
        PasswordStore.delete(for: id)
        shareStatuses.removeValue(forKey: id)
        authFailures.remove(id)
        nextRetry.removeValue(forKey: id)
        addEvent(t("eventShareRemoved"))
    }

    func setCleanupKind(_ kind: MountKind, enabled: Bool) {
        mutate { value in
            if enabled { value.cleanup.kinds.insert(kind) }
            else { value.cleanup.kinds.remove(kind) }
        }
    }

    func setDailyCleanup(enabled: Bool, hour: Int, minute: Int) {
        mutate { value in
            value.cleanup.dailyEnabled = enabled
            value.cleanup.hour = min(23, max(0, hour))
            value.cleanup.minute = min(59, max(0, minute))
        }
    }

    func toggleProtection(_ volume: MountedVolume) {
        mutate { value in
            if value.cleanup.protectedIDs.contains(volume.stableID) {
                value.cleanup.protectedIDs.remove(volume.stableID)
            } else {
                value.cleanup.protectedIDs.insert(volume.stableID)
            }
        }
    }

    func removeProtectedID(_ id: String) {
        mutate { $0.cleanup.protectedIDs.remove(id) }
    }

    func isProtected(_ volume: MountedVolume) -> Bool {
        CleanupPolicy.isProtected(volume, settings: settings)
    }

    var cleanupCandidates: [MountedVolume] {
        CleanupPolicy.candidates(from: volumes, settings: settings)
    }

    func cleanNow() { runCleanup(reason: t("reasonManualCleanup")) }

    func unmountOne(_ volume: MountedVolume) {
        Task {
            pauseMatchingShare(for: volume)
            await unmountVerified(volume, reason: t("reasonManualUnmount"))
            refresh()
        }
    }

    func unmountSelected(_ selectedIDs: Set<String>) {
        guard !isCleaning else { return }
        isCleaning = true
        Task {
            let fresh = await Task.detached(priority: .utility) { VolumeScanner.scan() }.value
            for volume in fresh where selectedIDs.contains(volume.id) {
                pauseMatchingShare(for: volume)
                await unmountVerified(volume, reason: t("reasonSelectedUnmount"))
            }
            isCleaning = false
            refresh()
        }
    }

    private func startObserving() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let restored = !self.networkAvailable && path.status == .satisfied
                self.networkAvailable = path.status == .satisfied
                if restored {
                    self.nextRetry.removeAll()
                    self.retryCount.removeAll()
                    self.refresh()
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "MountMate.Network"))
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sleeping = true }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleWake() }
        }
        mountObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        unmountObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.checkDailyCleanup()
            }
        }
    }

    private func handleWake() {
        sleeping = false
        nextRetry.removeAll()
        retryCount.removeAll()
        let now = Date()
        if settings.cleanup.dailyEnabled,
           DailyCleanup.shouldRun(at: now, hour: settings.cleanup.hour, minute: settings.cleanup.minute,
                                  lastRunDay: settings.lastCleanupDay) {
            mutate { $0.lastCleanupDay = DailyCleanup.dayKey(for: now) }
            addEvent(t("eventDailyCleanupMissed"))
        }
        refresh()
    }

    private func reconcileShares() {
        for share in settings.shares {
            if share.paused {
                shareStatuses[share.id] = .paused
            } else if let mounted = mountedVolume(for: share) {
                checkHealth(of: mounted, for: share)
            } else {
                probes.removeValue(forKey: share.id)
                if connecting.contains(share.id) { continue }
                if authFailures.contains(share.id) { shareStatuses[share.id] = .needsPassword; continue }
                if share.keepConnected {
                    attemptConnect(share.id)
                } else {
                    shareStatuses[share.id] = .disconnected
                }
            }
        }
    }

    private func checkHealth(of volume: MountedVolume, for share: ManagedShare) {
        guard probes[share.id] == nil else { return }
        if let previous = lastProbe[share.id], Date().timeIntervalSince(previous) < 55 {
            if shareStatuses[share.id] == nil { shareStatuses[share.id] = .mounted }
            return
        }
        let token = UUID()
        probes[share.id] = token
        lastProbe[share.id] = Date()
        shareStatuses[share.id] = .checking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Reading an entire NAS directory can be very slow when it contains many files.
            // Opening the directory is enough for a low-cost reachability check.
            let directory = opendir(volume.path)
            let healthy = directory != nil
            if let directory { closedir(directory) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.probes[share.id] == token else { return }
                self.probes.removeValue(forKey: share.id)
                self.shareStatuses[share.id] = healthy ? .mounted : .unhealthy
                self.updateStarSnapshot()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.probes[share.id] == token else { return }
            self.shareStatuses[share.id] = .unhealthy
            self.updateStarSnapshot()
        }
    }

    private func attemptConnect(_ id: UUID) {
        guard let share = settings.shares.first(where: { $0.id == id }),
              !share.paused, !connecting.contains(id), mountedVolume(for: share) == nil else { return }
        guard networkAvailable else { shareStatuses[id] = .waiting; return }
        guard nextRetry[id, default: .distantPast] <= Date() else { shareStatuses[id] = .waiting; return }
        let password = share.guestAccess || share.useSystemCredentials == true ? nil : PasswordStore.read(for: id)
        if !share.guestAccess && share.useSystemCredentials != true && (share.username.isEmpty || password == nil) {
            shareStatuses[id] = .needsPassword
            return
        }
        connecting.insert(id)
        shareStatuses[id] = .connecting
        SMBMounter.connect(share, password: password) { [weak self] result in
            DispatchQueue.main.async { [weak self] in self?.handleConnectResult(result, for: id) }
        }
    }

    private func handleConnectResult(_ result: Int32, for id: UUID) {
        connecting.remove(id)
        guard let share = settings.shares.first(where: { $0.id == id }) else { return }
        if result == 0 {
            retryCount[id] = 0
            nextRetry.removeValue(forKey: id)
            shareStatuses[id] = .checking
            addEvent(t("eventConnectSucceeded", ["name": share.name]))
            refresh()
        } else if SMBMounter.isAuthenticationError(result) {
            authFailures.insert(id)
            shareStatuses[id] = .needsPassword
            addEvent(t("eventAuthFailed", ["name": share.name, "code": String(result)]))
        } else {
            let count = min((retryCount[id] ?? 0) + 1, 6)
            retryCount[id] = count
            nextRetry[id] = Date().addingTimeInterval(min(900, 30 * pow(2, Double(count - 1))))
            shareStatuses[id] = .waiting
            addEvent(t("eventConnectFailed", ["name": share.name, "code": String(result)]))
        }
    }

    private func pauseShare(_ id: UUID) {
        mutate { value in
            guard let index = value.shares.firstIndex(where: { $0.id == id }) else { return }
            value.shares[index].paused = true
        }
        shareStatuses[id] = .paused
        updateStarSnapshot()
    }

    private func pauseMatchingShare(for volume: MountedVolume) {
        guard let key = SMBAddress.key(forMountSource: volume.source) else { return }
        for share in settings.shares where SMBAddress(share.address)?.key == key { pauseShare(share.id) }
    }

    private func checkDailyCleanup() {
        guard !sleeping, settings.cleanup.dailyEnabled,
              DailyCleanup.shouldRun(at: Date(), hour: settings.cleanup.hour, minute: settings.cleanup.minute,
                                     lastRunDay: settings.lastCleanupDay) else { return }
        mutate { $0.lastCleanupDay = DailyCleanup.dayKey(for: Date()) }
        runCleanup(reason: t("reasonDailyCleanup"))
    }

    private func runCleanup(reason: String) {
        guard !isCleaning else { return }
        isCleaning = true
        Task {
            let fresh = await Task.detached(priority: .utility) { VolumeScanner.scan() }.value
            let candidates = CleanupPolicy.candidates(from: fresh, settings: settings)
            if candidates.isEmpty { addEvent(t("eventNoMatchingMount", ["reason": reason])) }
            for volume in candidates { await unmountVerified(volume, reason: reason) }
            isCleaning = false
            refresh()
        }
    }

    private func unmountVerified(_ volume: MountedVolume, reason: String) async {
        let fresh = await Task.detached(priority: .utility) { VolumeScanner.scan() }.value
        guard fresh.contains(where: { $0.path == volume.path && $0.source == volume.source }) else {
            addEvent(t("eventMountChanged", ["name": volume.name]))
            return
        }
        let error = await withCheckedContinuation { continuation in
            FileManager.default.unmountVolume(at: URL(fileURLWithPath: volume.path), options: []) {
                continuation.resume(returning: $0)
            }
        }
        if let error {
            addEvent(t("eventUnmountFailed", ["reason": reason, "name": volume.name,
                                         "error": error.localizedDescription]))
        } else {
            addEvent(t("eventUnmounted", ["reason": reason, "name": volume.name]))
        }
    }

    private func addEvent(_ message: String) {
        mutate { value in
            value.events.insert(EventRecord(message: message), at: 0)
            if value.events.count > 150 { value.events.removeLast(value.events.count - 150) }
        }
    }

    private func mutate(_ body: (inout AppSettings) -> Void) {
        var updated = settings
        body(&updated)
        settings = updated
        updateStarSnapshot()
        guard storageIssue == nil else { return }
        do { try SettingsStore.save(settings) }
        catch { storageIssue = t("settingsSaveFailed", ["error": error.localizedDescription]) }
    }

    private func updateStarSnapshot() {
        let unhealthy = Set(shareStatuses.compactMap { $0.value == .unhealthy ? $0.key : nil })
        starSnapshot = starState.update(shares: settings.shares, mounts: volumes,
                                        unavailableShareIDs: unhealthy)
    }
}
