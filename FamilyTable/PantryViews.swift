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
                    InfoNote(title:"How these amounts are worked out · 数量怎么来的",lines:[
                        "Every meal on the menu is scaled to \(store.state.servings.formatted(.number.precision(.fractionLength(0...2)))) adult portions (\(store.state.servingsExplanation)), then the same ingredient is added up across the week.",
                        "Only pantry amounts you have confirmed are subtracted — a photo alone never counts as stock.",
                        "Buy the next suitable package size; the figure here is what the recipes ask for, not a shelf size."
                    ])
                    if store.state.meals.contains(where:{ !$0.approved && !$0.cooked }) {
                        Label("Some meals still need parent approval. List is provisional.",systemImage:"exclamationmark.circle").font(.footnote).foregroundStyle(.orange)
                        Button("Review the menu") { store.tab = 1 }.font(.footnote)
                    }
                }
            }
            ForEach(categories,id:\.self) { category in
                Section(category) {
                    ForEach(lines.filter{ Catalog.ingredient($0.ingredient).category == category }) { line in
                        ShoppingRow(line: line)
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
/// One line of the shopping list. Ticking it off records the purchase; tapping again
/// puts it back, for as long as it has not been put away.
struct ShoppingRow: View {
    @EnvironmentObject var store: FamilyStore
    let line: ShoppingLine
    private var ingredient: Ingredient { Catalog.ingredient(line.ingredient) }
    private var undoable: Bool { store.state.canUnbuy(line.ingredient) }
    private var bought: Bool { line.shortage <= 0 }
    private var statusText: String {
        if !bought { return "Buy \(quantityText(line.shortage, unit: ingredient.unit))" }
        return undoable ? "In the basket · tap to undo" : "Covered by the pantry ✓"
    }
    var body: some View {
        HStack(alignment: .top) {
            Button {
                store.update { state in
                    if bought { state.unbuy(line.ingredient) } else { state.buy(line.ingredient) }
                }
            } label: {
                Image(systemName: bought ? "checkmark.circle.fill" : "circle")
                    .font(.title2).padding(.vertical, 6)
                    .foregroundStyle(bought ? Brand.protein : Color.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(bought && !undoable)
            .accessibilityLabel(bought ? "Put \(ingredient.en) back on the list" : "Mark \(ingredient.en) purchased")
            VStack(alignment: .leading, spacing: 5) {
                Text(ingredient.name).font(.headline)
                Text(statusText).foregroundStyle(bought ? Color.secondary : Color.primary)
                Text("Need \(quantityText(line.required, unit: ingredient.unit)) · pantry \(quantityText(line.stock, unit: ingredient.unit)) · bought \(quantityText(line.purchased, unit: ingredient.unit))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PutAwayView: View {
    @EnvironmentObject var store: FamilyStore
    var body: some View {
        List {
            Section {
                Text("Confirm where each item really went, and how much you actually bought.").font(.subheadline)
                InfoNote(title:"Why confirm instead of assume · 为什么要确认",lines:[
                    "A suggested shelf is only a suggestion; the app never records it as the real place.",
                    "Stock counts only after someone confirms the amount and the location, so the shopping list cannot quietly under-buy.",
                    "Children can do this step; changing a location later is always allowed."
                ])
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
                Text("Photograph a shelf, then confirm what you see.").font(.subheadline)
                InfoNote(title:"What happens to these photos · 照片如何处理",lines:[
                    "Photos stay on this iPhone. Nothing is uploaded and no account is involved.",
                    "Automatic recognition is not enabled — you confirm each ingredient yourself.",
                    "A photo never decides freshness or quantity; only what you confirm becomes stock."
                ])
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
    @State private var newMember = ""
    @State private var newMemberIsChild = true
    @State private var newMemberAge = 8
    @State private var name = ""
    @State private var zone = "Refrigerated"
    let zones = ["Refrigerated","Frozen","Pantry"]

    var body: some View {
        Form {
            kitchenNameSection
            familySection
            portionsSection
            allergenSection
            storageSection
            languageSection
            appearanceSection
            aboutSection
        }.navigationTitle("Family & storage")
    }

    /// Whose kitchen this is. The app takes this name everywhere.
    @ViewBuilder private var kitchenNameSection: some View {
        Section("Our kitchen · 我们的厨房") {
            TextField("Name your kitchen, e.g. Zhang Kitchen",text:Binding(
                get:{ store.state.kitchenName },
                set:{ v in store.update { $0.kitchenName = String(v.prefix(40)) } }))
            Text("Shown at the top of Today and on the week. Leave it empty to just say \(Brand.appName).").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var familySection: some View {
        Section("Who eats here · 家里有谁") {
            ForEach(store.state.members) { member in FamilyMemberRow(member: member) }
                .onDelete { offsets in store.update { $0.members.remove(atOffsets:offsets) } }
            VStack(alignment:.leading,spacing:8) {
                TextField("Add a name",text:$newMember)
                Picker("They are",selection:$newMemberIsChild) { Text("A child").tag(true); Text("An adult").tag(false) }
                    .pickerStyle(.segmented)
                if newMemberIsChild {
                    Stepper("Age \(newMemberAge)",value:$newMemberAge,in:0...17)
                }
                Button {
                    let trimmed = newMember.trimmingCharacters(in:.whitespaces)
                    store.update { $0.members.append(FamilyMember(name:trimmed,isChild:newMemberIsChild,age:newMemberIsChild ? newMemberAge : nil)) }
                    newMember = ""
                } label: { Label("Add to the family",systemImage:"person.badge.plus") }
                .disabled(newMember.trimmingCharacters(in:.whitespaces).isEmpty)
            }
            Text("Children get a vote on every meal, and their age sets how much food is cooked for them.").font(.caption).foregroundStyle(.secondary)
        }
    }

    /// What all of that adds up to at the stove.
    @ViewBuilder private var portionsSection: some View {
        Section("Portions · 份量") {
            LabeledContent("Cooking for") {
                Text("\(store.state.servings.formatted(.number.precision(.fractionLength(0...2)))) adult portions")
                    .font(.headline)
            }
            Text(store.state.servingsExplanation).font(.caption).foregroundStyle(.secondary)
            Stepper("Guests this week: \(store.state.guests)",value:Binding(
                get:{store.state.guests},
                set:{ n in store.update { $0.guests = n } }),in:0...8)
            if store.state.members.isEmpty {
                Stepper("\(store.state.people) people",value:Binding(
                    get:{store.state.people},
                    set:{ n in store.update { $0.people = n } }),in:1...12)
                Text("Add your family above and portions will follow each person instead of a flat headcount.").font(.caption).foregroundStyle(.secondary)
            }
            InfoNote(title:"How portions are worked out · 份量怎么算",lines:[
                "Recipes are written for five adult portions. Everything is scaled from that.",
                "An adult counts as one portion. A child counts by age: about a quarter under 2, 0.4 at 2–3, 0.65 at 4–8, 0.85 at 9–13, and a full portion from 14.",
                "These are household planning figures, not nutrition requirements. Tap anyone above to set their own amount if they eat more or less.",
                "The shopping list follows this number directly, so a family with young children buys less than a family of five adults."
            ])
        }
    }

    @ViewBuilder private var allergenSection: some View {
        Section("Allergies & foods to avoid · 过敏与忌口") {
            ForEach(Allergen.allCases,id:\.self) { allergen in
                Toggle(allergen.name,isOn:Binding(
                    get:{ store.state.excludedAllergens.contains(allergen) },
                    set:{ on in store.update { s in
                        if on { s.excludedAllergens.insert(allergen) } else { s.excludedAllergens.remove(allergen) }
                    } }))
            }
            InfoNote(title:"What excluding does — and does not do · 排除的含义",lines:[
                "Excluded allergens are never recommended and never offered as a swap.",
                "A meal you choose yourself is still allowed, but it is clearly flagged.",
                "This matches ingredients, not labels. Brands, sauces and shared equipment cause cross-contact that no app can see — a family managing a real allergy still reads every package.",
                "Ordinary soy sauce contains wheat, and most dried soba is cut with wheat flour; both are marked accordingly."
            ])
        }
    }

    /// Fridges, freezers and cupboards, each with its own shelves.
    @ViewBuilder private var storageSection: some View {
        Section("Where food lives · 食物放在哪里") {
            ForEach(store.state.appliances,id:\.self) { appliance in
                DisclosureGroup {
                    ForEach(store.state.compartments(of: appliance)) { location in
                        LocationRow(location: location)
                    }
                    Button(role:.destructive) { store.update { $0.removeAppliance(appliance) } } label: {
                        Label("Remove \(appliance)",systemImage:"trash")
                    }.font(.footnote)
                } label: {
                    HStack {
                        Text(appliance).font(.headline)
                        Spacer()
                        Text("\(store.state.compartments(of: appliance).count) places").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(store.state.looseLocations) { location in LocationRow(location: location) }
            HStack(spacing:10) {
                ForEach(ApplianceKind.allCases,id:\.self) { kind in
                    Button {
                        store.update { $0.addAppliance(kind) }
                    } label: {
                        Label("\(kind.en)",systemImage:kind.symbol).font(.footnote)
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.state.applianceCount(of: kind) >= FamilyState.maxAppliancesPerKind)
                }
            }
            Text("Add up to three fridges, three freezers and three cupboards. Each one arrives with the usual shelves — rename them to match your kitchen, or delete the ones you do not have.").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Add a single place by hand") {
                TextField("Place name",text:$name)
                Picker("Temperature zone",selection:$zone) { ForEach(zones,id:\.self) { Text($0).tag($0) } }
                Button("Add place") {
                    store.update { $0.locations.append(Location(name:name.trimmingCharacters(in:.whitespaces),zone:zone)) }
                    name = ""
                }.disabled(name.trimmingCharacters(in:.whitespaces).isEmpty)
            }.font(.footnote)
        }
    }

    @ViewBuilder private var languageSection: some View {
        Section("Recipe language · 菜谱语言") {
            Picker("Show recipes in",selection:Binding(get:{store.state.recipeLanguage},set:{ v in store.update { $0.recipeLanguage = v } })) {
                ForEach(RecipeLanguage.allCases,id:\.self) { Text($0.en).tag($0) }
            }.pickerStyle(.segmented)
            Text("Every built-in dish is written in both languages — the same steps, the same temperatures. Ingredient names and the shopping list stay bilingual whatever you choose here, so whoever is shopping can read them.").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var appearanceSection: some View {
        Section("Day & night · 白天与夜间") {
            Picker("View",selection:Binding(get:{store.state.appearance},set:{ v in store.update { $0.appearance = v } })) {
                ForEach(Appearance.allCases,id:\.self) { Text("\($0.en) · \($0.zh)").tag($0) }
            }.pickerStyle(.segmented)
            Text("Night view keeps the same colours, stepped for a dark screen — easier on the eyes when you are cooking late or checking tomorrow's menu in bed.").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var aboutSection: some View {
        Section("About this edition") {
            LabeledContent("Version",value:"\(Brand.appName) \(Brand.version)")
            InfoNote(title:"What this edition is · 这一版是什么",lines:[
                "Everything lives on this iPhone: no account, no cloud sync, no photo uploads.",
                "Parent and child roles are an agreement on a shared device, not password-protected accounts.",
                "56 dinners and 20 breakfasts, each written in Chinese and English.",
                "Recipe pictures are AI-generated illustrations made for this app, not photographs of tested cooking.",
                "Cooking times and nutrition figures are estimates, not kitchen-tested or laboratory-measured."
            ])
        }
    }
}

/// One person: their name, whether they are a child, their age and their portion.
struct FamilyMemberRow: View {
    @EnvironmentObject var store: FamilyStore
    let member: FamilyMember
    private func update(_ change: @escaping (inout FamilyMember) -> Void) {
        store.update { state in
            guard let index = state.members.firstIndex(where: { $0.id == member.id }) else { return }
            change(&state.members[index])
        }
    }
    var body: some View {
        DisclosureGroup {
            Picker("They are",selection:Binding(get:{member.isChild},set:{ isChild in update { $0.isChild = isChild; if !isChild { $0.age = nil } else if $0.age == nil { $0.age = 8 } } })) {
                Text("A child").tag(true); Text("An adult").tag(false)
            }.pickerStyle(.segmented)
            if member.isChild {
                Stepper("Age \(member.age ?? 8)",value:Binding(get:{member.age ?? 8},set:{ age in update { $0.age = age } }),in:0...17)
            }
            Toggle("Set their portion by hand",isOn:Binding(
                get:{ member.portionOverride != nil },
                set:{ on in update { $0.portionOverride = on ? $0.portionFactor : nil } }))
            if let override = member.portionOverride {
                Stepper("\(override.formatted(.number.precision(.fractionLength(0...2)))) adult portions",
                        value:Binding(get:{override},set:{ v in update { $0.portionOverride = v } }),
                        in:0.25...3,step:0.25)
            }
        } label: {
            HStack {
                TextField("Name",text:Binding(get:{member.name},set:{ v in update { $0.name = v } }))
                Spacer()
                Text(member.portionDescription).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// One shelf, drawer or cupboard space.
struct LocationRow: View {
    @EnvironmentObject var store: FamilyStore
    let location: Location
    var body: some View {
        HStack {
            TextField("Place name",text:Binding(
                get:{ store.state.locations.first{ $0.id == location.id }?.name ?? "" },
                set:{ v in store.update { s in if let i = s.locations.firstIndex(where:{$0.id == location.id}) { s.locations[i].name = v } } }))
            Spacer()
            Text(location.zone).font(.caption).foregroundStyle(.secondary)
            Button(role:.destructive) {
                store.update { s in
                    s.locations.removeAll { $0.id == location.id }
                    for i in s.stock.indices where s.stock[i].location == location.id { s.stock[i].location = nil }
                }
            } label: { Image(systemName:"minus.circle") }.buttonStyle(.borderless)
        }
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
