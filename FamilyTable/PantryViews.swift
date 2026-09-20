import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

struct ShoppingView: View {
    @EnvironmentObject var store: FamilyStore
    var lines: [ShoppingLine] { store.state.shopping() }
    var categories: [String] { Array(Set(lines.map { Catalog.ingredient($0.ingredient).category })).sorted() }
    var body: some View {
        List {
            Section {
                if lines.isEmpty {
                    VStack(alignment:.leading,spacing:12) {
                        Text("Your list follows your menu").font(.system(.title3, design:.serif).bold())
                        Text("Plan a week of breakfasts and dinners, and everything those meals need appears here — combined, scaled to your family, minus what your pantry already holds.").font(.footnote).foregroundStyle(.secondary)
                        Button { store.tab = 1 } label: { Label("Plan next week's menu",systemImage:"calendar").frame(maxWidth:.infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("shoppingPlanWeek")
                    }.padding(.vertical,6)
                } else {
                    if let first = store.state.planStart, let last = store.state.planEnd {
                        Text("For the menu of \(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day())) · \(store.state.itemsToBuy) items to buy").font(.headline)
                    }
                    NavigationLink { PutAwayView() } label: { Label("Put away · \(store.state.purchases.filter{!$0.stored}.count) waiting",systemImage:"shippingbox") }
                    Text("For \(store.state.people) people. Recipe amounts are combined before rounding; buy the next suitable package. Only confirmed pantry amounts are deducted.").font(.footnote)
                    if store.state.meals.contains(where:{ !$0.approved && !$0.cooked }) {
                        Label("Some meals still need parent approval. List is provisional.",systemImage:"exclamationmark.circle").font(.footnote).foregroundStyle(.orange)
                        Button("Review the menu") { store.tab = 1 }.font(.footnote)
                    }
                }
            }
            ForEach(categories,id:\.self) { category in
                Section(category) {
                    ForEach(lines.filter{ Catalog.ingredient($0.ingredient).category == category }) { line in
                        let ingredient = Catalog.ingredient(line.ingredient)
                        HStack(alignment:.top) {
                            Button { store.update { $0.buy(line.ingredient) } } label: { Image(systemName:line.shortage > 0 ? "circle" : "checkmark.circle.fill").font(.title2).padding(.vertical,6) }.buttonStyle(.borderless).disabled(line.shortage <= 0).accessibilityLabel("Mark \(ingredient.en) purchased")
                            VStack(alignment:.leading,spacing:5) {
                                Text(ingredient.name).font(.headline)
                                Text(line.shortage > 0 ? "Buy \(quantityText(line.shortage,unit:ingredient.unit))" : "Covered ✓").foregroundStyle(line.shortage > 0 ? Color.primary : Color.secondary)
                                Text("Need \(quantityText(line.required,unit:ingredient.unit)) · pantry \(quantityText(line.stock,unit:ingredient.unit)) · bought \(quantityText(line.purchased,unit:ingredient.unit))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if !store.state.purchases.filter({!$0.stored}).isEmpty {
                Section("Purchased, awaiting storage") {
                    ForEach(store.state.purchases.filter{!$0.stored}) { p in
                        HStack { Text(Catalog.ingredient(p.ingredient).name); Spacer(); Button("Undo") { store.update { $0.purchases.removeAll { $0.id == p.id } } }.buttonStyle(.borderless) }
                    }
                }
            }
        }.navigationTitle("Shopping")
    }
}
struct PutAwayView: View {
    @EnvironmentObject var store: FamilyStore
    var body: some View {
        List {
            Section { Text("Suggestions are not actual locations. Choose where you really put each item and confirm the actual purchased amount. Only then will it count as pantry stock.").font(.footnote)
                NavigationLink("Edit storage locations",destination:SettingsView())
            }
            ForEach(store.state.purchases.filter{!$0.stored}) { p in PutAwayRow(purchase:p) }
            if store.state.purchases.allSatisfy(\.stored) { Text("All put away. Nice teamwork!") }
        }.navigationTitle("Put away")
    }
}
struct PutAwayRow: View {
    @EnvironmentObject var store: FamilyStore
    let purchase: Purchase
    @State private var location = ""
    @State private var amount = ""
    var item: Ingredient { Catalog.ingredient(purchase.ingredient) }
    var validAmount: Double? { guard let n = Double(amount), n.isFinite, n > 0 else { return nil }; return n }
    var compatible: [Location] { store.state.locations.filter { $0.zone == item.storage || (item.storage == "Refrigerated" && $0.zone == "Frozen" && item.category == "Protein") } }
    var body: some View {
        Section(item.name) {
            Text("Suggested storage: \(item.storage) · confirm package instructions").font(.caption).foregroundStyle(.secondary)
            if let suggestion = compatible.first { Text("Suggested place: \(suggestion.name) — choose below to confirm.").font(.caption) }
            if item.category == "Protein" { Text("Keep raw meat/fish sealed to prevent drips. Freeze portions for later days promptly; thaw in the fridge in advance.").font(.caption) }
            TextField("Actual amount (\(item.unit))",text:$amount).keyboardType(.decimalPad)
            Picker("Actual location",selection:$location) { Text("Choose…").tag(""); ForEach(compatible) { l in Text(l.name).tag(l.id.uuidString) } }
            if compatible.isEmpty { Text("Add a \(item.storage) location in Settings first.").foregroundStyle(.orange) }
            Button("Placed here — confirm") { if let id = UUID(uuidString:location), let qty = validAmount { store.update { $0.storePurchase(purchase.id,location:id,actualQuantity:qty) } } }.disabled(validAmount == nil || UUID(uuidString:location) == nil)
        }.onAppear { if amount.isEmpty { amount = String(purchase.quantity) } }
    }
}
struct PantryView: View {
    @EnvironmentObject var store: FamilyStore
    @State private var add = false
    @State private var editing: Stock?
    @State private var photos: [PhotosPickerItem] = []
    @State private var camera = false
    @State private var cameraDenied = false
    @State private var selectedPhoto: String?
    @State private var addAfterPhoto = false
    var body: some View {
        List {
            Section {
                NavigationLink { SettingsView() } label: { Label("Family & storage settings",systemImage:"gearshape") }
                Button { add = true } label: { Label("Confirm an ingredient",systemImage:"plus.circle") }
            }
            Section("Pantry photos · private on this device") {
                Text("Automatic recognition is not enabled. Add photos, inspect them, then manually confirm ingredients and quantities below. Photos never determine freshness or amounts and are not uploaded.").font(.footnote).foregroundStyle(.secondary)
                PhotosPicker(selection:$photos,maxSelectionCount:8,matching:.images) { Label("Import photos",systemImage:"photo.on.rectangle") }
                Button {
                    Task {
                        if await AVCaptureDevice.requestAccess(for: .video) { camera = true }
                        else { cameraDenied = true }
                    }
                } label:{ Label("Take a photo",systemImage:"camera") }.disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                if !store.state.photoFiles.isEmpty {
                    ScrollView(.horizontal) { LazyHStack { ForEach(store.state.photoFiles,id:\.self) { name in
                        if let image = UIImage(contentsOfFile:store.directory.appendingPathComponent(name).path) {
                            Button { selectedPhoto = name } label: { Image(uiImage:image).resizable().scaledToFill().frame(width:90,height:90).clipped().cornerRadius(10) }.buttonStyle(.plain)
                        }
                    } } }
                }
            }
            Section("Confirmed inventory · tap to correct") {
                if store.state.stock.isEmpty { Text("No assumptions about what you own. Add your first item.").foregroundStyle(.secondary) }
                ForEach(store.state.stock) { s in
                    Button { editing = s } label: {
                        VStack(alignment:.leading,spacing:5) { Text(Catalog.ingredient(s.ingredient).name).foregroundStyle(.primary); Text("\(quantityText(s.quantity,unit:Catalog.ingredient(s.ingredient).unit)) · \(store.location(s.location))").font(.caption).foregroundStyle(.secondary); if !s.confirmed { Text("Unconfirmed — not deducted").font(.caption) } }
                    }
                }.onDelete { indices in store.update { $0.stock.remove(atOffsets:indices) } }
            }
            Section { Text("Fridge ≤40°F / 4°C · Freezer ≤0°F / −18°C. Photos cannot establish food safety. Check labels and storage times; freeze later-week raw meat/fish promptly.").font(.footnote); Link("FDA storage guidance",destination:URL(string:"https://www.fda.gov/consumers/consumer-updates/are-you-storing-food-safely")!); Link("Cold storage time chart",destination:URL(string:"https://www.foodsafety.gov/food-safety-charts/cold-food-storage-charts")!) }
        }.navigationTitle("Our pantry")
        .sheet(isPresented:$add) { NavigationStack { StockEditor(existing:nil) } }
        .sheet(item:$editing) { item in NavigationStack { StockEditor(existing:item) } }
        .alert("Camera access is off", isPresented:$cameraDenied) {
            Button("Open Settings") { if let url = URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            Button("Cancel", role:.cancel) {}
        } message: { Text("Allow camera access in Settings, or use Import photos instead.") }
        .sheet(isPresented:$camera) { CameraCapture { data in Task { await store.importPhoto(data) } } }
        .sheet(isPresented:Binding(get:{selectedPhoto != nil},set:{if !$0 {selectedPhoto = nil}}), onDismiss:{ if addAfterPhoto { addAfterPhoto = false; add = true } }) {
            NavigationStack { if let name = selectedPhoto, let img = UIImage(contentsOfFile:store.directory.appendingPathComponent(name).path) {
                ScrollView { Image(uiImage:img).resizable().scaledToFit(); Text("Inspect this photo, then confirm each ingredient manually. Existing ingredient + location entries are replaced, not duplicated.").padding(); Button("Confirm an ingredient") { addAfterPhoto = true; selectedPhoto = nil }.buttonStyle(.borderedProminent) }.toolbar { Button("Done") { selectedPhoto = nil } }
            } }
        }
        .onChange(of:photos) { _, items in Task { for p in items { do { if let data = try await p.loadTransferable(type:Data.self) { await store.importPhoto(data) } } catch { store.error = "Photo import failed: \(error.localizedDescription)" } }; photos = [] } }
    }
}
struct StockEditor: View {
    @EnvironmentObject var store: FamilyStore
    @Environment(\.dismiss) var dismiss
    let existing: Stock?
    @State private var ingredient = "chicken"
    @State private var amount = ""
    @State private var location = ""
    @State private var confirmed = false
    var quantity: Double? { guard let n = Double(amount), n.isFinite, n >= 0 else { return nil }; return n }
    var body: some View {
        Form {
            Section("Identify & measure") {
                Picker("Ingredient",selection:$ingredient) { ForEach(Catalog.ingredients) { i in Text(i.name).tag(i.id) } }.disabled(existing != nil)
                TextField("Amount (\(Catalog.ingredient(ingredient).unit))",text:$amount).keyboardType(.decimalPad)
                Picker("Actual location",selection:$location) { Text("Unconfirmed").tag(""); ForEach(store.state.locations) { l in Text("\(l.name) · \(l.zone)").tag(l.id.uuidString) } }
                Toggle("Parent confirmed this quantity",isOn:$confirmed)
                Text("Enter the total currently present at this location, not an amount to add. Matching ingredient + location is updated to prevent duplicates. No freshness is inferred.").font(.caption)
            }
            Button("Save inventory") {
                guard let qty = quantity else { return }
                let saved = store.update { state in
                    if let old = existing { state.stock.removeAll { $0.id == old.id } }
                    state.confirmStock(Stock(ingredient:ingredient,quantity:qty,confirmed:confirmed,location:UUID(uuidString:location)))
                }; if saved { dismiss() }
            }.disabled(quantity == nil)
        }.navigationTitle(existing == nil ? "Confirm ingredient" : "Correct inventory").toolbar { Button("Cancel") { dismiss() } }
        .onAppear { if let s = existing { ingredient = s.ingredient; amount = String(s.quantity); location = s.location?.uuidString ?? ""; confirmed = s.confirmed } }
    }
}
struct SettingsView: View {
    @EnvironmentObject var store: FamilyStore
    @State private var name = ""
    @State private var zone = "Refrigerated"
    let zones = ["Refrigerated","Frozen","Pantry"]
    var body: some View {
        Form {
            Section("Family") { Stepper("\(store.state.people) people",value:Binding(get:{store.state.people},set:{ n in store.update { $0.people = n; for i in $0.meals.indices where !$0.meals[i].cooked { $0.meals[i].approved = false } } }),in:1...12); Text("Default: five. Amounts scale immediately. Above six people, allow more preparation and batch-cooking time.").font(.caption) }
            Section("Your real storage locations") {
                Text("These are your labels, not a map of your fridge. You can use Fridge shelf 1/2/3, Produce drawer, Yogurt zone, Door, Freezer or Pantry. Set the correct temperature zone.").font(.caption)
                ForEach(store.state.locations) { location in
                    VStack {
                        TextField("Location name",text:Binding(get:{store.state.locations.first{$0.id == location.id}?.name ?? ""},set:{ v in store.update { s in if let i = s.locations.firstIndex(where:{$0.id == location.id}) { s.locations[i].name = v } } }))
                        Text(location.zone).font(.caption).foregroundStyle(.secondary)
                    }
                }.onDelete { offsets in store.update { s in let deleted = offsets.map { s.locations[$0].id }; s.locations.remove(atOffsets:offsets); for i in s.stock.indices where deleted.contains(s.stock[i].location ?? UUID()) { s.stock[i].location = nil } } }
                TextField("New location name",text:$name)
                Picker("Temperature zone",selection:$zone) { ForEach(zones,id:\.self) { Text($0).tag($0) } }
                Button("Add location") { store.update { $0.locations.append(Location(name:name.trimmingCharacters(in:.whitespaces),zone:zone)) }; name = "" }.disabled(name.trimmingCharacters(in:.whitespaces).isEmpty)
            }
            Section("About this first edition") {
                LabeledContent("Version","\(Brand.appName) · \(Brand.appNameZh) \(Brand.version)")
                Text("Local to this iPhone. No account, cloud sync or photo uploads. Parent/child roles are social controls on a shared device. 50 dinner and 20 breakfast recipes; breakfast preferences and children's ages have not been assumed.").font(.footnote)
                Text("Images: AI-generated recipe illustrations, created for this app. They are not photographs of tested recipes. Cooking times are estimates, not kitchen-tested guarantees.").font(.footnote)
            }
        }.navigationTitle("Family & storage")
    }
}
struct CameraCapture: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onCapture: (Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context:Context) -> UIImagePickerController { let controller = UIImagePickerController(); controller.sourceType = .camera; controller.delegate = context.coordinator; return controller }
    func updateUIViewController(_ controller:UIImagePickerController,context:Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent:CameraCapture) { self.parent = parent }
        func imagePickerController(_ picker:UIImagePickerController,didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey:Any]) { if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality:0.8) { parent.onCapture(data) }; parent.dismiss() }
        func imagePickerControllerDidCancel(_ picker:UIImagePickerController) { parent.dismiss() }
    }
}
