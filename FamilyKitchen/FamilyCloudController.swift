import Foundation
import CloudKit
import os
import Combine

@MainActor final class FamilyCloudController: ObservableObject {
    struct SharePresentation: Identifiable {
        let id = UUID()
        let share: CKShare
        let container: CKContainer
    }
    struct RemoteFamily: Identifiable {
        let record: CKRecord
        let isOwner: Bool
        var id: String { record.recordID.zoneID.ownerName + record.recordID.zoneID.zoneName }
        var name: String { record["name"] as? String ?? "Family Kitchen" }
    }
    enum SharingError: LocalizedError {
        case account, changedAccount, invalidFamily, alreadyConnected, readOnly, busy
        var errorDescription: String? {
            switch self {
            case .account: return "Sign in to iCloud in iPhone Settings first. 请先在 iPhone 设置中登录 iCloud。"
            case .changedAccount: return "This kitchen belongs to another iCloud account. Switch back or return to your local kitchen. iCloud 账号已更换，请切回原账号或返回本机厨房。"
            case .invalidFamily: return "This invitation or cloud kitchen is not supported. 无法读取此家庭数据。"
            case .alreadyConnected: return "Return to your local kitchen before joining another family. 请先返回本机厨房，再加入其他家庭。"
            case .readOnly: return "You have view-only access. Ask the owner for editing access. 当前只有查看权限。"
            case .busy: return "Please wait for the current iCloud operation. 请等待当前同步完成。"
            }
        }
    }

    // Set CLOUDKIT_CONTAINER_IDENTIFIER in the app build settings to your team's container.
    static var containerIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String ?? "iCloud.com.jiatingchufang.app"
    }
    lazy var container = CKContainer(identifier: Self.containerIdentifier)
    @Published private(set) var session: FamilyCloudSession?
    @Published private(set) var isBusy = false
    @Published private(set) var changingFamily = false
    /// True only when this device must not show the shared kitchen at all: the iCloud
    /// account has actually changed, or access was taken away.
    @Published private(set) var accessBlocked = false
    /// Whether the iCloud identity behind the cached kitchen has been confirmed since
    /// launch. False simply means "not checked yet" — being offline is not suspicious.
    @Published private(set) var identityConfirmed = false
    @Published private(set) var canWrite = true
    @Published private(set) var status = "Local kitchen · 本机厨房"
    @Published var error: String?
    @Published var sharePresentation: SharePresentation?
    @Published private(set) var conflict = false
    @Published private(set) var availableFamilies: [RemoteFamily] = []
    private var conflictRemote: Data?
    private(set) var loadError: Error?
    private let directory: URL
    private let sessionURL: URL
    private let localURL: URL
    private var retryTask: Task<Void, Never>?
    private var foregroundTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    var currentLocal: (() -> FamilyState)?
    var didChangeState: ((FamilyState) -> Void)?
    var connected: Bool { session != nil }
    var pending: Bool { session?.hasPendingChanges ?? false }
    var editingAllowed: Bool { loadError == nil && !changingFamily && !accessBlocked && canWrite && !conflict }

    init(directory: URL) {
        self.directory = directory
        sessionURL = directory.appendingPathComponent("icloud-session.json")
        localURL = directory.appendingPathComponent("family.json")
        if FileManager.default.fileExists(atPath: sessionURL.path) {
            do {
                session = try FamilyCloudSession.load(from: sessionURL)
                status = "Waiting for iCloud · 等待同步"
                // The cached kitchen is already on this iPhone and is shown while the
                // account is checked. Hiding it would take the shopping list away in
                // exactly the place it is needed — a shop with no signal. What waits
                // for confirmation is uploading, which `sync` does only after `verify`.
                identityConfirmed = false
            } catch { loadError = error; self.error = "Could not read shared kitchen. Its file is preserved. 共享数据无法读取，原文件已保留。" }
        }
    }

    func start() {
        guard observers.isEmpty else { return }
        observers.append(NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.identityConfirmed = false
                self?.availableFamilies = []
                self?.sharePresentation = nil
                self?.conflict = false; self?.conflictRemote = nil
                await self?.sync()
            }
        })
        setForeground(true)
    }

    func setForeground(_ active: Bool) {
        foregroundTask?.cancel()
        guard active else { return }
        foregroundTask = Task { [weak self] in
            while !Task.isCancelled {
                // Stopping the foreground timer must not cancel a CloudKit write
                // that may already have committed on the server.
                Task { await self?.sync() }
                do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
            }
        }
    }

    /// Called before FamilyStore publishes a local edit; the queue survives app termination.
    func saveLocal(_ state: FamilyState) throws {
        guard editingAllowed else { throw SharingError.busy }
        guard var next = session else { try StateFile.save(state, to: localURL); return }
        next.local = state
        try persist(next)
        status = next.hasPendingChanges ? "Changes waiting to sync · 修改待同步" : "Synced · 已同步"
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 800_000_000) } catch { return }
            self?.retryTask = nil
            await self?.sync()
        }
    }

    private func persist(_ next: FamilyCloudSession) throws {
        try next.save(to: sessionURL)
        session = next
    }
    private func account() async throws -> String {
        guard try await container.accountStatus() == .available else { throw SharingError.account }
        return try await container.userRecordID().recordName
    }
    private func verify(_ expected: String) async throws {
        guard try await account() == expected else { throw SharingError.changedAccount }
    }
    private func database(_ owner: Bool) -> CKDatabase {
        owner ? container.privateCloudDatabase : container.sharedCloudDatabase
    }
    private func recordID(_ session: FamilyCloudSession) -> CKRecord.ID {
        CKRecord.ID(recordName: session.recordName,
                    zoneID: CKRecordZone.ID(zoneName: session.zoneName, ownerName: session.ownerName))
    }
    private func payload(_ record: CKRecord) throws -> Data {
        defer { Catalog.setCustomRecipes(currentLocal?().customRecipes ?? []) }
        guard record.recordType == "FamilyKitchen", let asset = record["state"] as? CKAsset,
              let url = asset.fileURL else { throw SharingError.invalidFamily }
        let data = try Data(contentsOf: url)
        _ = try StateFile.decode(data)
        return data
    }
    private func save(_ record: CKRecord, data: Data, in db: CKDatabase, share: CKShare? = nil) async throws -> CKRecord {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        record["state"] = CKAsset(fileURL: url)
        let result = try await db.modifyRecords(saving: [record] + (share.map { [$0] } ?? []), deleting: [],
                                                savePolicy: .ifServerRecordUnchanged, atomically: true)
        if let share {
            guard let savedShare = result.saveResults[share.recordID] else { throw SharingError.invalidFamily }
            _ = try savedShare.get()
        }
        guard let saved = try result.saveResults[record.recordID]?.get() else { throw SharingError.invalidFamily }
        return saved
    }
    /// How many rescue copies to keep. Each connect, disconnect and resolved conflict
    /// writes one, so an unbounded folder is a slow leak on a phone that syncs for
    /// years — and a folder nobody can find is not much of a safety net anyway.
    static let backupsKept = 20

    private var backupsDirectory: URL { directory.appendingPathComponent("Backups") }

    private func backup(_ state: FamilyState) throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        try StateFile.save(state, to: backupsDirectory.appendingPathComponent("\(stamp)-\(UUID().uuidString.prefix(8)).json"))
        pruneBackups()
    }

    /// Newest kept, oldest dropped. Never throws: losing an old copy must not stop
    /// the thing the copy was protecting.
    private func pruneBackups() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupsDirectory, includingPropertiesForKeys: Array(keys)) else { return }
        let sorted = files.filter { $0.pathExtension == "json" }.sorted {
            let a = (try? $0.resourceValues(forKeys: keys).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: keys).contentModificationDate) ?? .distantPast
            return a > b
        }
        for file in sorted.dropFirst(Self.backupsKept) { try? FileManager.default.removeItem(at: file) }
    }

    /// How many rescue copies are on this iPhone, and where they are, so the setup
    /// screen can say so rather than leaving them invisible.
    var backupCount: Int {
        (try? FileManager.default.contentsOfDirectory(atPath: backupsDirectory.path))?
            .filter { $0.hasSuffix(".json") }.count ?? 0
    }
    private func attach(_ record: CKRecord, owner: Bool, accountID: String, local: FamilyState) throws {
        let data = try payload(record)
        var state = try FamilySharing.applying(data, to: local)
        // Photos belong to the local kitchen, not the newly joined family.
        if !owner { state.photoFiles = [] }
        try backup(local)
        let next = FamilyCloudSession(zoneName: record.recordID.zoneID.zoneName,
                                      ownerName: record.recordID.zoneID.ownerName,
                                      recordName: record.recordID.recordName, isOwner: owner,
                                      accountID: accountID, base: data, local: state)
        try persist(next)
        accessBlocked = false; identityConfirmed = true; conflict = false; conflictRemote = nil
        didChangeState?(state)
        status = "Synced · 已同步"
    }

    // MARK: - Setting it up

    /// One line of the setup screen: what was checked, and what came back.
    enum SetupCheck: Equatable {
        case unchecked
        case checking
        case ready(String)
        /// Not yet, but nothing for the family to fix — Apple is still preparing the
        /// container, or the network is away. Checked again without being asked.
        case waiting(String)
        case blocked(String)
        var isReady: Bool { if case .ready = self { return true }; return false }
        var isWaiting: Bool { if case .waiting = self { return true }; return false }
        var detail: String? {
            switch self {
            case .unchecked: return nil
            case .checking: return "Checking · 检查中"
            case .ready(let text), .waiting(let text), .blocked(let text): return text
            }
        }
    }
    @Published private(set) var accountCheck: SetupCheck = .unchecked
    @Published private(set) var containerCheck: SetupCheck = .unchecked
    var setupReady: Bool { accountCheck.isReady && containerCheck.isReady }

    /// Answers the two questions that decide whether sharing can work at all, in the
    /// order they fail: is there an iCloud account, and can this build reach its
    /// CloudKit container. Reported separately because the fixes are different — one
    /// is the family's to do in Settings, the other is the developer's.
    func runSetupChecks(quietly: Bool = false) async {
        // A background re-check keeps showing the last answer instead of flickering
        // through "Checking" once a minute.
        if !quietly { accountCheck = .checking; containerCheck = .checking }
        let status: CKAccountStatus
        do { status = try await container.accountStatus() }
        catch {
            accountCheck = .blocked("Could not ask iCloud: \(error.localizedDescription) 无法查询 iCloud 状态。")
            containerCheck = .unchecked
            return
        }
        switch status {
        case .available:
            accountCheck = .ready("Signed in · 已登录")
        case .noAccount:
            accountCheck = .blocked("No iCloud account on this iPhone. Sign in under Settings → [your name]. 本机未登录 iCloud，请在“设置”中登录。")
            containerCheck = .unchecked; return
        case .restricted:
            accountCheck = .blocked("iCloud is restricted on this iPhone, often by Screen Time. 本机 iCloud 受限，可能由屏幕使用时间限制。")
            containerCheck = .unchecked; return
        case .temporarilyUnavailable:
            accountCheck = .blocked("iCloud is temporarily unavailable. Try again shortly. iCloud 暂时不可用，请稍后再试。")
            containerCheck = .unchecked; return
        default:
            accountCheck = .blocked("iCloud status could not be determined. iCloud 状态无法确定。")
            containerCheck = .unchecked; return
        }
        do {
            _ = try await container.userRecordID()
            containerCheck = .ready("\(Self.containerIdentifier) · 可用")
        } catch {
            Self.log.error("Container check failed: \(String(describing: error), privacy: .public)")
            containerCheck = containerStatus(for: error)
        }
    }

    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FamilyKitchen", category: "iCloud")

    /// Turns CloudKit's answer into something a family can act on — and says which
    /// answer it was, so a wrong guess here can never hide the real one again.
    private func containerStatus(for error: Error) -> SetupCheck {
        let ck = error as? CKError
        let code = ck.map { " (CloudKit \($0.errorCode))" } ?? ""
        switch ck?.code {
        case .badContainer?:
            // What a brand-new container returns until Apple's servers can hand out
            // its configuration: minutes, occasionally about an hour.
            return .waiting("Apple is still preparing this app's iCloud storage. A new container can take up to an hour to become available — this screen checks again by itself. Apple 正在准备本应用的 iCloud 存储，新容器最长约需一小时生效，本页会自动重新检查。" + code)
        case .notAuthenticated?, .permissionFailure?:
            return .blocked("iCloud is switched off for Family Kitchen on this iPhone. Turn it on in Settings → [your name] → iCloud, in the list of apps using iCloud. 本机关闭了本应用的 iCloud，请在 设置 → [你的名字] → iCloud 的应用列表中打开。" + code)
        case .missingEntitlement?:
            return .blocked("This build is not signed for \(Self.containerIdentifier). Check the iCloud capability in Xcode. 此版本签名中缺少该容器的 iCloud 权限，请在 Xcode 中检查。" + code)
        default:
            if offline(error) {
                return .waiting("Could not reach iCloud just now. It will check again once the connection is back. 暂时连不上 iCloud，网络恢复后会自动重新检查。" + code)
            }
            return .blocked("iCloud answered: \(error.localizedDescription) iCloud 返回错误。" + code)
        }
    }

    func createFamily() async {
        guard !isBusy, session == nil, loadError == nil, let local = currentLocal?() else { return }
        isBusy = true; changingFamily = true; error = nil
        defer { isBusy = false; changingFamily = false; Catalog.setCustomRecipes(currentLocal?().customRecipes ?? []) }
        do {
            let user = try await account()
            let db = container.privateCloudDatabase
            let zone = CKRecordZone(zoneName: "FamilyKitchen-v1")
            _ = try await db.save(zone)
            let id = CKRecord.ID(recordName: "Kitchen", zoneID: zone.zoneID)
            // A stable ID prevents duplicate families after a reinstall or a timed-out save.
            do {
                _ = try await db.record(for: id)
                error = "An iCloud kitchen already exists. Use Find my families to reconnect. 已有云端家庭，请使用查找家庭恢复连接。"
                return
            } catch let e as CKError where e.code == .unknownItem { }
            let record = CKRecord(recordType: "FamilyKitchen", recordID: id)
            record["name"] = local.kitchenName.isEmpty ? "Family Kitchen" : local.kitchenName
            let share = CKShare(rootRecord: record)
            share.publicPermission = .none
            share[CKShare.SystemFieldKey.title] = record["name"]
            let saved = try await save(record, data: FamilySharing.payload(local), in: db, share: share)
            try await verify(user)
            try attach(saved, owner: true, accountID: user, local: local)
            canWrite = true
        } catch { report(error) }
    }

    func findFamilies() async {
        guard !isBusy, session == nil, loadError == nil else { return }
        isBusy = true; error = nil; availableFamilies = []
        defer { isBusy = false }
        do {
            let user = try await account()
            var found: [RemoteFamily] = []
            for owner in [true, false] {
                let db = database(owner)
                for zone in try await db.allRecordZones() where zone.zoneID.zoneName == "FamilyKitchen-v1" {
                    let id = CKRecord.ID(recordName: "Kitchen", zoneID: zone.zoneID)
                    do { found.append(RemoteFamily(record: try await db.record(for: id), isOwner: owner)) }
                    catch let e as CKError where e.code == .unknownItem { continue }
                }
            }
            try await verify(user)
            availableFamilies = found
            status = found.isEmpty ? "No families found · 尚无云端家庭" : "Choose a family · 选择家庭"
        } catch { report(error) }
    }

    func connect(_ family: RemoteFamily) async {
        guard !isBusy, session == nil, loadError == nil, let local = currentLocal?() else { return }
        isBusy = true; changingFamily = true; error = nil
        defer { isBusy = false; changingFamily = false; Catalog.setCustomRecipes(currentLocal?().customRecipes ?? []) }
        do {
            let user = try await account()
            let fresh = try await database(family.isOwner).record(for: family.record.recordID)
            canWrite = try await writable(fresh, owner: family.isOwner)
            try await verify(user)
            try attach(fresh, owner: family.isOwner, accountID: user, local: local)
        } catch { report(error) }
    }

    func accept(_ metadata: CKShare.Metadata) async {
        guard !isBusy, loadError == nil, let local = currentLocal?() else { return }
        guard session == nil else { error = SharingError.alreadyConnected.localizedDescription; return }
        isBusy = true; changingFamily = true; error = nil
        defer { isBusy = false; changingFamily = false; Catalog.setCustomRecipes(currentLocal?().customRecipes ?? []) }
        do {
            guard metadata.containerIdentifier == Self.containerIdentifier,
                  let id = metadata.hierarchicalRootRecordID, id.recordName == "Kitchen",
                  id.zoneID.zoneName == "FamilyKitchen-v1" else { throw SharingError.invalidFamily }
            let user = try await account()
            _ = try await container.accept(metadata)
            let record = try await container.sharedCloudDatabase.record(for: id)
            canWrite = try await writable(record, owner: false)
            try await verify(user)
            try attach(record, owner: false, accountID: user, local: local)
        } catch { report(error) }
    }

    private func writable(_ record: CKRecord, owner: Bool) async throws -> Bool {
        if owner { return true }
        guard let reference = record.share,
              let share = try await container.sharedCloudDatabase.record(for: reference.recordID) as? CKShare,
              let participant = share.currentUserParticipant else { throw SharingError.invalidFamily }
        return participant.permission == .readWrite
    }

    func sync() async {
        guard !isBusy, !conflict, let start = session, loadError == nil else { return }
        isBusy = true
        defer { isBusy = false; Catalog.setCustomRecipes(currentLocal?().customRecipes ?? []) }
        do {
            try await verify(start.accountID)
            accessBlocked = false; identityConfirmed = true
            let db = database(start.isOwner)
            let record = try await db.record(for: recordID(start))
            canWrite = try await writable(record, owner: start.isOwner)
            let remote = try payload(record)
            // Read the newest local copy after awaits: edits can arrive while fetching.
            guard let latest = session else { return }
            let merged: FamilyState
            do { merged = try FamilySharing.merge(base: latest.base, local: latest.local, remote: remote) }
            catch let e as FamilySharing.Conflict { setConflict(remote, error: e); return }
            let outgoing = try FamilySharing.payload(merged)
            if outgoing != remote && !canWrite {
                setConflict(remote, error: SharingError.readOnly); return
            }
            if outgoing != remote {
                record["name"] = merged.kitchenName.isEmpty ? "Family Kitchen" : merged.kitchenName
                _ = try await save(record, data: outgoing, in: db)
            }
            try await verify(start.accountID)
            // Rebase edits made during the upload onto the acknowledged cloud state.
            guard var next = session else { return }
            do { next.local = try FamilySharing.merge(base: FamilySharing.payload(latest.local), local: next.local, remote: outgoing) }
            catch let e as FamilySharing.Conflict { setConflict(outgoing, error: e); return }
            next.base = outgoing
            try persist(next)
            didChangeState?(next.local)
            error = nil; status = next.hasPendingChanges ? "Changes waiting to sync · 修改待同步" : "Synced · 已同步"
        } catch { report(error) }
    }

    private func setConflict(_ remote: Data, error: Error) {
        conflictRemote = remote; conflict = true
        self.error = error.localizedDescription
        status = "Choose a version · 需要处理冲突"
    }
    func resolveConflict(useCloud: Bool) {
        guard !isBusy, var next = session, let remote = conflictRemote, !accessBlocked else { return }
        guard useCloud || canWrite else { return }
        do {
            try backup(next.local)
            let cloud = try FamilySharing.applying(remote, to: next.local)
            // Store the alternate version too before explicitly replacing it.
            try backup(cloud)
            if useCloud { next.local = cloud }
            next.base = remote
            try persist(next)
            conflictRemote = nil; conflict = false; error = nil
            didChangeState?(next.local)
            Task { await sync() }
        } catch { report(error) }
    }

    func manageSharing() async {
        guard !isBusy, let session, !accessBlocked else { return }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            try await verify(session.accountID)
            let db = database(session.isOwner)
            let record = try await db.record(for: recordID(session))
            let share: CKShare
            if let reference = record.share, let existing = try await db.record(for: reference.recordID) as? CKShare {
                share = existing
            } else {
                guard session.isOwner else { throw SharingError.invalidFamily }
                share = CKShare(rootRecord: record)
                share.publicPermission = .none
                share[CKShare.SystemFieldKey.title] = record["name"]
                let result = try await db.modifyRecords(saving: [record, share], deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
                for value in result.saveResults.values { _ = try value.get() }
            }
            try await verify(session.accountID)
            sharePresentation = SharePresentation(share: share, container: container)
        } catch { report(error) }
    }

    /// Disconnecting this device does not revoke invitations or delete the owner's data.
    /// The system sharing sheet separately handles removing people / stopping sharing.
    func returnToLocalKitchen() {
        guard !isBusy, let session else { return }
        do {
            try backup(session.local)
            let local = FileManager.default.fileExists(atPath: localURL.path) ? try StateFile.load(from: localURL) : FamilyState()
            try FileManager.default.removeItem(at: sessionURL)
            self.session = nil; accessBlocked = false; identityConfirmed = false; canWrite = true
            conflict = false; conflictRemote = nil; sharePresentation = nil
            availableFamilies = []; error = nil; status = "Local kitchen · 本机厨房"
            didChangeState?(local)
        } catch { report(error) }
    }

    private func report(_ failure: Error) {
        error = failure.localizedDescription
        // Only two things justify hiding a kitchen that is already on this iPhone:
        // the account really is a different one, or this device's access was removed.
        // "I could not reach iCloud" is neither.
        if let e = failure as? SharingError {
            switch e { case .changedAccount: accessBlocked = connected; default: break }
        }
        if let e = failure as? CKError {
            switch e.code {
            case .permissionFailure, .unknownItem, .zoneNotFound, .userDeletedZone:
                accessBlocked = connected
            default: break
            }
        }
        if connected {
            status = offline(failure)
                ? "Offline — using this iPhone's copy · 离线，使用本机副本"
                : "Sync paused — retry available · 同步暂停，可重试"
        } else {
            status = "iCloud unavailable · iCloud 暂不可用"
        }
    }

    /// Whether a failure is simply the network being away.
    private func offline(_ failure: Error) -> Bool {
        guard let e = failure as? CKError else { return (failure as NSError).domain == NSURLErrorDomain }
        switch e.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
             .zoneBusy, .notAuthenticated:
            return true
        default: return false
        }
    }
}
