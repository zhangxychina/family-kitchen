import Foundation

/// A conservative three-way merge. Coupled kitchen records travel together:
/// purchasing and putting away must never be merged into double-counted stock.
public enum FamilySharing {
    public struct Conflict: Error, LocalizedError {
        public let areas: [String]
        public var errorDescription: String? {
            "Both devices changed: \(areas.joined(separator: ", ")). Choose which version to keep. 两台设备修改了相同数据，请选择保留的版本。"
        }
    }

    private static let localKeys = ["photoFiles", "appearance", "recipeLanguage", "nightStartHour", "nightEndHour"]
    private static let groups: [(String, [String])] = [
        ("kitchen / 菜单与库存", ["appliances", "locations", "stock", "meals", "purchases", "history", "customRecipes", "preferred"]),
        ("family / 家庭资料", ["people", "guests", "members", "excludedAllergens"]),
        ("name / 厨房名称", ["kitchenName"])
    ]

    /// Only this payload goes into CloudKit; local photo paths and preferences do not.
    public static func payload(_ state: FamilyState) throws -> Data {
        var object = try dictionary(state)
        for key in localKeys { object.removeValue(forKey: key) }
        return try canonical(object)
    }

    public static func applying(_ data: Data, to local: FamilyState) throws -> FamilyState {
        defer { Catalog.setCustomRecipes(local.customRecipes) }
        // Validate remote data before using it, including version and references.
        var shared = try StateFile.decode(data)
        shared.photoFiles = local.photoFiles
        shared.appearance = local.appearance
        shared.recipeLanguage = local.recipeLanguage
        shared.nightStartHour = local.nightStartHour
        shared.nightEndHour = local.nightEndHour
        return shared
    }

    public static func merge(base: Data, local: FamilyState, remote: Data) throws -> FamilyState {
        defer { Catalog.setCustomRecipes(local.customRecipes) }
        let b = try object(base)
        let l = try object(payload(local))
        let r = try object(remote)
        _ = try StateFile.decode(remote)
        var merged = r
        var conflicts: [String] = []
        for (name, keys) in groups {
            let before = try subset(b, keys)
            let ours = try subset(l, keys)
            let theirs = try subset(r, keys)
            if ours == before { continue }
            if theirs != before && ours != theirs { conflicts.append(name); continue }
            for key in keys { merged[key] = l[key] }
        }
        guard conflicts.isEmpty else { throw Conflict(areas: conflicts) }
        return try applying(canonical(merged), to: local)
    }

    private static func dictionary(_ state: FamilyState) throws -> [String: Any] {
        try object(JSONEncoder().encode(state))
    }
    private static func object(_ data: Data) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw StateError.invalidData }
        return value
    }
    private static func subset(_ object: [String: Any], _ keys: [String]) throws -> Data {
        try canonical(object.filter { keys.contains($0.key) })
    }
    private static func canonical(_ object: [String: Any]) throws -> Data {
        // Codable Sets have no stable order. Normalize only the known set fields.
        var object = object
        for key in ["preferred", "excludedAllergens"] {
            if let values = object[key] as? [String] { object[key] = values.sorted() }
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

/// One atomic file contains the local working copy and its last acknowledged cloud
/// ancestor. A crash can never advance the ancestor without saving the working copy.
public struct FamilyCloudSession: Codable {
    public var formatVersion = 1
    public var zoneName: String
    public var ownerName: String
    public var recordName: String
    public var isOwner: Bool
    public var accountID: String
    public var base: Data
    public var local: FamilyState
    public init(zoneName: String, ownerName: String, recordName: String, isOwner: Bool,
                accountID: String, base: Data, local: FamilyState) {
        self.zoneName = zoneName; self.ownerName = ownerName; self.recordName = recordName
        self.isOwner = isOwner; self.accountID = accountID; self.base = base; self.local = local
    }
    /// Whether the working copy has moved on from the last acknowledged cloud state.
    ///
    /// When the working copy cannot even be encoded there is nothing meaningful to
    /// say, and claiming "waiting to sync" would leave that badge on forever with no
    /// way to clear it. The next sync surfaces the real error instead.
    public var hasPendingChanges: Bool {
        guard let current = try? FamilySharing.payload(local) else { return false }
        return current != base
    }
    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
    public static func load(from url: URL) throws -> Self {
        let session = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        _ = try StateFile.decode(session.base)
        _ = try StateFile.decode(JSONEncoder().encode(session.local))
        guard session.formatVersion == 1, !session.zoneName.isEmpty, !session.recordName.isEmpty, !session.accountID.isEmpty else { throw StateError.invalidData }
        return session
    }
}
