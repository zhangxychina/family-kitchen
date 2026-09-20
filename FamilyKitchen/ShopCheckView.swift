import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

/// The check you do at the door: photograph the fridge, and the list stops asking
/// for things already on the shelf.
///
/// The app reads the photos on this phone and proposes what it saw. Nothing is
/// ticked off until someone looks at the proposal and confirms it — a recogniser
/// that mistakes a lemon for an orange must not be able to send the family home
/// without the eggs.
struct ShopCheckView: View {
    @EnvironmentObject var store: FamilyStore
    @Environment(\.dismiss) private var dismiss

    /// Which shelf the photos were taken of, so what is confirmed lands in a real
    /// place rather than floating free.
    @State private var location = ""
    @State private var photos: [PhotosPickerItem] = []
    @State private var camera = false
    @State private var cameraDenied = false
    @State private var scanning = false
    @State private var scanned = 0
    @State private var findings: [ScanFinding] = []
    @State private var accepted: Set<String> = []
    @State private var amounts: [String: String] = [:]
    @State private var failure: String?
    /// True between the tap and the camera actually appearing, so the button says
    /// something is happening instead of looking dead.
    @State private var opening = false

    private let recognizer = VisionPantryRecognizer()

    private var onList: [ScanFinding] { findings.filter(\.onList) }
    private var alsoSeen: [ScanFinding] { findings.filter { !$0.onList } }
    private var chosenLocation: UUID? { UUID(uuidString: location) }
    private var toBuy: Int { store.state.itemsToBuy }
    /// What confirming would actually record: ticked, with an amount that means
    /// something. A ticked line with the amount cleared is not a confirmation.
    private var confirmations: [ScanConfirmation] {
        findings.compactMap { finding in
            guard accepted.contains(finding.ingredient),
                  let quantity = Double(amounts[finding.ingredient] ?? ""),
                  quantity.isFinite, quantity > 0 else { return nil }
            return ScanConfirmation(ingredient: finding.ingredient, quantity: quantity, location: chosenLocation)
        }
    }

    var body: some View {
        List {
            introSection
            placeSection
            captureSection
            if scanning { scanningSection }
            if !findings.isEmpty { findingsSection; confirmSection }
            else if scanned > 0 && !scanning { nothingFoundSection }
            if let failure { Section { Text(failure).font(.footnote).foregroundStyle(Brand.clay) } }
        }
        .navigationTitle("Check before you shop")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Camera access is off", isPresented: $cameraDenied) {
            Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Allow camera access in Settings, or import photos from your library instead.") }
        // Full screen rather than a sheet: the system camera is a full-screen
        // controller, and presenting it in a card is what makes it stutter on the way in.
        .fullScreenCover(isPresented: $camera, onDismiss: { opening = false }) {
            CameraCapture { data in Task { await scan([data]) } }
        }
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            Task {
                photos = []
                // One photo at a time. Eight full-size pictures held together is a
                // memory spike on an older iPhone, and nothing here needs them at once.
                for item in items {
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        failure = "One photo could not be opened."
                        continue
                    }
                    await scan([data])
                }
            }
        }
        .onChange(of: location) { _, _ in
            // "Total here" means something different on a different shelf, so every
            // offered amount is worked out again rather than left pointing at the
            // place it was calculated for.
            amounts = [:]
            for finding in findings { fillAmount(finding) }
        }
        .onAppear {
            if location.isEmpty, let first = store.state.locations.first { location = first.id.uuidString }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(en: "Photograph what you already have", zh: "出门前先拍一拍")
                Text(toBuy == 0
                     ? "Nothing on the list needs buying right now."
                     : "Your list is asking for \(toBuy) item\(toBuy == 1 ? "" : "s"). Take a few photos of the fridge or the shelf, and anything already at home is ticked off and moved to the bottom of the list.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
            InfoNote(title: "What this can and cannot do · 能做什么，不能做什么", lines: [
                "Photos are read on this iPhone. Nothing is uploaded, no account is involved, and a photo taken here is not kept once it has been read.",
                "Recognition is general: it is good at whole foods and vague about boxes and jars. Whatever it misses, you add by hand as before.",
                "It never decides on its own. You confirm each item, and only then does the shopping list change.",
                "A photo cannot say how much there is, or whether it is still good. The amount offered is exactly what this week's menu needs — correct it if you can see it is wrong."
            ])
        }
    }

    @ViewBuilder private var placeSection: some View {
        Section("Which place are you photographing · 拍的是哪里") {
            if store.state.locations.isEmpty {
                NavigationLink { StorageSettingsView() } label: {
                    Label("Set up your fridges and pantries first", systemImage: "refrigerator").foregroundStyle(Brand.clay)
                }
            } else {
                Picker("Place", selection: $location) {
                    Text("Do not record a place").tag("")
                    ForEach(store.state.locations) { place in
                        Text(store.state.describe(place)).tag(place.id.uuidString)
                    }
                }
                Text("What you confirm is recorded here, so the kitchen list stays true to where things actually are.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var captureSection: some View {
        Section {
            Button { openCamera() } label: {
                Label(opening ? "Opening the camera…" : "Take a photo · 拍照", systemImage: "camera")
            }
                .disabled(!CameraAccess.hasCamera || scanning || opening)
                .accessibilityIdentifier("shopCheckCamera")
            PhotosPicker(selection: $photos, maxSelectionCount: 8, matching: .images) {
                Label("Use photos from my library · 从相册选择", systemImage: "photo.on.rectangle")
            }.disabled(scanning)
            if scanned > 0 {
                Text("\(scanned) photo\(scanned == 1 ? "" : "s") read. Take more if some shelves are not shown.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } footer: {
            Text("Open the door, stand back far enough to see whole shelves, and take one photo per shelf.")
        }
    }

    @ViewBuilder private var scanningSection: some View {
        Section { HStack(spacing: 12) { ProgressView(); Text("Reading the photos…").font(.footnote) } }
    }

    @ViewBuilder private var nothingFoundSection: some View {
        Section {
            Text("Nothing on your list was recognised in those photos. That does not mean it is not there — add anything you can see yourself, in Our kitchen.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var findingsSection: some View {
        if !onList.isEmpty {
            Section("Already at home · 家里已有") {
                ForEach(onList) { finding in row(finding) }
            }
        }
        if !alsoSeen.isEmpty {
            Section {
                ForEach(alsoSeen) { finding in row(finding) }
            } header: {
                Text("Also spotted · 另外看到")
            } footer: {
                Text("These are not on this week's list. Tick any you want recorded in your kitchen anyway.")
            }
        }
    }

    private func row(_ finding: ScanFinding) -> some View {
        let item = Catalog.ingredient(finding.ingredient)
        let isOn = accepted.contains(finding.ingredient)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Button {
                    if isOn { accepted.remove(finding.ingredient) } else { accepted.insert(finding.ingredient) }
                } label: {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.title2).foregroundStyle(isOn ? Brand.protein : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(isOn ? "Do not record" : "Record") \(item.en)")
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.headline)
                    Text("Seen as “\(finding.label)” · \(finding.confidenceText)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !finding.onList { StatusPill(text: "Not on the list", state: .waiting) }
            }
            if isOn {
                HStack {
                    Text("Total here").font(.caption).foregroundStyle(.secondary)
                    TextField("Amount (\(item.unit))", text: Binding(
                        get: { amounts[finding.ingredient] ?? "" },
                        set: { amounts[finding.ingredient] = $0 }))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            }
        }.padding(.vertical, 2)
    }

    @ViewBuilder private var confirmSection: some View {
        Section {
            let ready = confirmations
            Button {
                if store.update({ $0.applyScan(ready) }) { dismiss() }
            } label: {
                Label("Confirm \(ready.count) item\(ready.count == 1 ? "" : "s") · 确认", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(ready.isEmpty)
            .accessibilityIdentifier("shopCheckConfirm")
            Button("Tick everything on my list") {
                for finding in onList { accepted.insert(finding.ingredient); fillAmount(finding) }
            }.font(.footnote).disabled(onList.isEmpty)
            Text("Confirming records these amounts in \(chosenLocation == nil ? "your kitchen, without a place" : store.state.locationLabel(chosenLocation)) and updates the shopping list.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Work

    /// Opens the camera with as little between the tap and the viewfinder as
    /// possible. Permission is only *asked* for the first time; after that the
    /// answer is already known, so the camera is presented on the spot.
    private func openCamera() {
        guard CameraAccess.hasCamera else { return }
        if CameraAccess.isAuthorized { opening = true; camera = true; return }
        if CameraAccess.isDenied { cameraDenied = true; return }
        opening = true
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { camera = true } else { opening = false; cameraDenied = true }
        }
    }

    /// Reads a batch of photos and merges what they show into the findings already on
    /// screen, so several trips to the camera build one list.
    private func scan(_ images: [Data]) async {
        guard !images.isEmpty else { return }
        scanning = true
        failure = nil
        defer { scanning = false }
        let wanted = store.state.shoppingListIngredients
        var labels: [(label: String, confidence: Double)] = []
        for image in images {
            do { labels += try await recognizer.labels(from: image) }
            catch { failure = "One photo could not be read: \(error.localizedDescription)" }
        }
        scanned += images.count
        let fresh = PantryMatcher.findings(from: labels, shoppingList: wanted)
        // Keep the best sighting of each ingredient across every batch so far.
        var merged = Dictionary(uniqueKeysWithValues: findings.map { ($0.ingredient, $0) })
        for finding in fresh {
            if let existing = merged[finding.ingredient], existing.confidence >= finding.confidence { continue }
            merged[finding.ingredient] = finding
        }
        findings = merged.values.sorted {
            $0.onList == $1.onList
                ? ($0.confidence == $1.confidence ? $0.ingredient < $1.ingredient : $0.confidence > $1.confidence)
                : $0.onList
        }
        // Something on the list that the camera is sure about starts ticked; anything
        // doubtful, or not on the list at all, waits to be asked for.
        for finding in findings where finding.onList && finding.confidence >= ScanFinding.trustedConfidence {
            accepted.insert(finding.ingredient)
        }
        for finding in findings { fillAmount(finding) }
    }

    /// Offers the amount that would close this line, leaving it editable.
    private func fillAmount(_ finding: ScanFinding) {
        guard amounts[finding.ingredient] == nil else { return }
        let suggested = store.state.suggestedScanQuantity(finding.ingredient, at: chosenLocation)
        amounts[finding.ingredient] = suggested > 0
            ? suggested.formatted(.number.precision(.fractionLength(0...2)))
            : ""
    }
}
