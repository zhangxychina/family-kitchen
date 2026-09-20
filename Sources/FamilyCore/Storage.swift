import Foundation

/// A box that holds food: a fridge, a standalone freezer, or a room-temperature
/// pantry. Kitchens differ enormously, so the app supplies a usual layout and then
/// gets out of the way — every shelf can be renamed, removed, or added to.
public enum ApplianceKind: String, Codable, CaseIterable, Sendable {
    /// A fridge, including the freezer compartment most of them carry on top.
    case fridge
    /// A freezer standing on its own, in a garage or a basement.
    case freezer
    /// Room-temperature shelving: a cupboard, a larder, a rack in the garage.
    /// The stored value stays `cupboard`, which is what earlier versions wrote.
    case pantry = "cupboard"

    public var en: String {
        switch self {
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        case .pantry: return "Pantry"
        }
    }
    public var zh: String {
        switch self {
        case .fridge: return "冰箱"
        case .freezer: return "冷冻柜"
        case .pantry: return "储藏柜"
        }
    }
    /// The temperature zone most of this appliance sits at. Individual compartments
    /// can differ — that is exactly why a fridge can hold a frozen shelf.
    public var zone: String {
        switch self {
        case .fridge: return "Refrigerated"
        case .freezer: return "Frozen"
        case .pantry: return "Pantry"
        }
    }
    public var symbol: String {
        switch self {
        case .fridge: return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet"
        }
    }
    /// What the app calls this one before the family renames it.
    public var defaultName: String {
        switch self {
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        case .pantry: return "Pantry"
        }
    }

    /// The shelves a new appliance starts with, in the order they are reached.
    ///
    /// `detailed` is the layout of an ordinary American fridge — freezer on top,
    /// three shelves, two drawers, and the door. `detailed: false` is for a family
    /// who would rather just say "it is in the fridge" and get on with dinner.
    public func startingCompartments(detailed: Bool) -> [(name: String, zone: String)] {
        switch (self, detailed) {
        case (.fridge, true):
            return [("Freezer on top", "Frozen"),
                    ("Top shelf", "Refrigerated"),
                    ("Middle shelf", "Refrigerated"),
                    ("Bottom shelf", "Refrigerated"),
                    ("Fruit & veg drawer", "Refrigerated"),
                    ("Dairy drawer", "Refrigerated"),
                    ("Door", "Refrigerated")]
        case (.fridge, false):
            // Even the simple layout keeps fridge and freezer apart: which of the two
            // something is in decides how long it keeps.
            return [("Fridge", "Refrigerated"), ("Freezer", "Frozen")]
        case (.freezer, true):
            return [("Top basket", "Frozen"), ("Middle basket", "Frozen"), ("Bottom basket", "Frozen")]
        case (.freezer, false):
            return [("Inside", "Frozen")]
        case (.pantry, true):
            return [("Top shelf", "Pantry"), ("Middle shelf", "Pantry"), ("Bottom shelf", "Pantry")]
        case (.pantry, false):
            return [("Shelves", "Pantry")]
        }
    }
}

/// One fridge, freezer or pantry, and the room it stands in.
///
/// Where it stands matters more than what is on which shelf: "the garage fridge" is
/// how a family actually talks, and a household with two fridges needs to tell them
/// apart before anything else.
public struct Appliance: Codable, Identifiable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var kind: ApplianceKind
    public var name: String
    /// The room it is in — "Kitchen", "Garage", anything the family types. Empty is
    /// allowed; not every home needs to say.
    public var place: String

    public init(id: UUID = UUID(), kind: ApplianceKind, name: String, place: String = "") {
        self.id = id; self.kind = kind; self.name = name; self.place = place
    }

    /// Lenient decoding, so a file written before a field existed still opens.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(ApplianceKind.self, forKey: .kind) ?? .fridge
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? kind.defaultName
        place = try c.decodeIfPresent(String.self, forKey: .place) ?? ""
    }

    /// How this appliance reads on its own: "Fridge · Garage".
    public var fullName: String {
        place.trimmingCharacters(in: .whitespaces).isEmpty ? name : "\(name) · \(place)"
    }

    /// Rooms offered as a starting point. Anything can be typed instead.
    public static let suggestedPlaces = ["Kitchen", "Garage", "Basement", "Laundry room", "Utility room", "Outside"]
}

public extension FamilyState {
    /// Families are capped at four of each kind, which is already more than most
    /// homes have and keeps a slip of the finger from filling the screen.
    static var maxAppliancesPerKind: Int { 4 }

    func appliance(_ id: UUID?) -> Appliance? {
        guard let id else { return nil }
        return appliances.first { $0.id == id }
    }
    /// The shelves inside one appliance, in the order they were set up.
    func compartments(of applianceID: UUID) -> [Location] {
        locations.filter { $0.applianceID == applianceID }
    }
    /// Places that belong to no appliance — a shelf in the garage, a fruit bowl.
    ///
    /// A shelf pointing at an appliance that is no longer there counts as loose too.
    /// It should not happen, but if it ever does the family must still be able to see
    /// it and delete it, rather than it sitting in the file where no screen shows it.
    var looseLocations: [Location] {
        locations.filter { location in
            guard let id = location.applianceID else { return true }
            return !appliances.contains { $0.id == id }
        }
    }

    func applianceCount(of kind: ApplianceKind) -> Int {
        appliances.filter { $0.kind == kind }.count
    }

    /// Appliances grouped by the room they stand in, rooms in the order they were
    /// first used, and anything without a room last.
    var appliancesByPlace: [(place: String, appliances: [Appliance])] {
        var order: [String] = []
        var grouped: [String: [Appliance]] = [:]
        for appliance in appliances {
            let place = appliance.place.trimmingCharacters(in: .whitespaces)
            if grouped[place] == nil { order.append(place) }
            grouped[place, default: []].append(appliance)
        }
        // An appliance with no room named is listed after the ones that have one,
        // and the rooms themselves stay in the order the family created them.
        let named = order.filter { !$0.isEmpty }
        let unnamed = order.filter(\.isEmpty)
        return (named + unnamed).map { ($0, grouped[$0] ?? []) }
    }

    /// How a place reads away from its own section: "Garage fridge · Door".
    func describe(_ location: Location) -> String {
        guard let appliance = appliance(location.applianceID) else { return location.name }
        return "\(appliance.name) · \(location.name)"
    }
    /// The same, for a place referred to only by id.
    func locationLabel(_ id: UUID?) -> String {
        guard let id, let location = locations.first(where: { $0.id == id }) else {
            return "Location unconfirmed · 位置待确认"
        }
        return describe(location)
    }

    /// Adds an appliance with a starting set of shelves. Returns it, or nil when this
    /// family already has the maximum of that kind.
    @discardableResult
    mutating func addAppliance(_ kind: ApplianceKind, named name: String? = nil,
                               place: String = "", detailed: Bool = true) -> Appliance? {
        guard applianceCount(of: kind) < FamilyState.maxAppliancesPerKind else { return nil }
        var candidate = (name ?? "").trimmingCharacters(in: .whitespaces)
        if candidate.isEmpty { candidate = kind.defaultName }
        var unique = candidate
        var suffix = 2
        while appliances.contains(where: { $0.name == unique }) { unique = "\(candidate) \(suffix)"; suffix += 1 }
        let appliance = Appliance(kind: kind, name: unique,
                                  place: place.trimmingCharacters(in: .whitespaces))
        appliances.append(appliance)
        for compartment in kind.startingCompartments(detailed: detailed) {
            locations.append(Location(name: compartment.name, zone: compartment.zone, applianceID: appliance.id))
        }
        return appliance
    }

    /// Adds one shelf to an appliance that already exists.
    @discardableResult
    mutating func addCompartment(to applianceID: UUID, named name: String, zone: String? = nil) -> Location? {
        guard let appliance = appliance(applianceID) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let location = Location(name: trimmed, zone: zone ?? appliance.kind.zone, applianceID: applianceID)
        locations.append(location)
        return location
    }

    /// Removes an appliance and its shelves. Food stored there is left without a
    /// confirmed place rather than deleted — it is still in someone's kitchen.
    mutating func removeAppliance(_ id: UUID) {
        let removed = Set(compartments(of: id).map(\.id))
        locations.removeAll { removed.contains($0.id) }
        appliances.removeAll { $0.id == id }
        for index in stock.indices where removed.contains(stock[index].location ?? UUID()) {
            stock[index].location = nil
        }
    }

    /// Removes one shelf, on the same terms.
    mutating func removeLocation(_ id: UUID) {
        locations.removeAll { $0.id == id }
        for index in stock.indices where stock[index].location == id { stock[index].location = nil }
    }

    /// Renames an appliance. An emptied field falls back to the plain name for its
    /// kind rather than leaving a nameless box in the list — the family can see what
    /// happened and type over it.
    mutating func renameAppliance(_ id: UUID, to name: String) {
        guard let index = appliances.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        appliances[index].name = trimmed.isEmpty ? appliances[index].kind.defaultName : String(trimmed.prefix(40))
    }
    /// The same for a shelf: never nameless, because its name is how food is found.
    mutating func renameLocation(_ id: UUID, to name: String) {
        guard let index = locations.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        locations[index].name = trimmed.isEmpty ? "Unnamed place" : String(trimmed.prefix(40))
    }
    mutating func setPlace(_ place: String, forAppliance id: UUID) {
        guard let index = appliances.firstIndex(where: { $0.id == id }) else { return }
        appliances[index].place = String(place.prefix(40))
    }
}
