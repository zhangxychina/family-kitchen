import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

struct ShoppingView: View {
    @EnvironmentObject var store: FamilyStore
    var lines: [ShoppingLine] { store.state.shopping() }
    /// What still has to be bought, and what the kitchen already covers. The list is
    /// read on the way round a shop, so everything still needed stays at the top and
    /// everything settled drops to the bottom.
    var stillToBuy: [ShoppingLine] { lines.filter { $0.shortage > 0 } }
    var alreadyCovered: [ShoppingLine] { lines.filter { $0.shortage <= 0 } }
    var categories: [String] { Array(Set(stillToBuy.map { Catalog.ingredient($0.ingredient).category })).sorted() }
    var body: some View {
        List {
            Section {
                if lines.isEmpty {
                    VStack(alignment:.leading,spacing:12) {
                        Text("Your list follows your menu").font(.system(.title3, design:.serif).bold())
                        Text("Plan a week of breakfasts and dinners, and everything those meals need appears here — combined, scaled to your family, minus what your kitchen already holds.").font(.footnote).foregroundStyle(.secondary)
                        Button { store.tab = 1 } label: { Label("Plan next week's menu",systemImage:"calendar").frame(maxWidth:.infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("shoppingPlanWeek")
                    }.padding(.vertical,6)
                } else {
                    if let first = store.state.planStart, let last = store.state.planEnd {
                        Text("For the menu of \(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day())) · \(store.state.itemsToBuy) items to buy").font(.headline)
                    }
                    NavigationLink { ShopCheckView() } label: {
                        Label("Check before you shop · 出门前核对", systemImage: "camera.viewfinder")
                    }.accessibilityIdentifier("openShopCheck")
                    NavigationLink { PutAwayView() } label: { Label("Put away · \(store.state.purchases.filter{!$0.stored}.count) waiting",systemImage:"shippingbox") }
                    InfoNote(title:"How these amounts are worked out · 数量怎么来的",lines:[
                        "Every meal on the menu is scaled to \(store.state.servings.formatted(.number.precision(.fractionLength(0...2)))) adult portions (\(store.state.servingsExplanation)), then the same ingredient is added up across the week.",
                        "Only amounts you have confirmed at home are subtracted — a photo alone never counts.",
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
                    ForEach(stillToBuy.filter{ Catalog.ingredient($0.ingredient).category == category }) { line in
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
            if !alreadyCovered.isEmpty {
                Section {
                    ForEach(alreadyCovered) { line in ShoppingRow(line: line) }
                } header: {
                    Text("Nothing to buy · 已有，无需购买 (\(alreadyCovered.count))")
                } footer: {
                    Text("Already in your kitchen or already in the basket. Kept here so you can check the reasoning, and put anything back on the list by tapping it.")
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
        return undoable ? "In the basket · tap to undo" : "Already in your kitchen ✓"
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
                Text("Need \(quantityText(line.required, unit: ingredient.unit)) · at home \(quantityText(line.stock, unit: ingredient.unit)) · bought \(quantityText(line.purchased, unit: ingredient.unit))")
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
                    "It counts only after someone confirms the amount and the place, so the shopping list cannot quietly under-buy.",
                    "Children can do this step; changing a location later is always allowed."
                ])
                NavigationLink("Edit fridges, pantries and shelves",destination:StorageSettingsView())
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
            if let suggestion = compatible.first { Text("Suggested place: \(store.state.describe(suggestion)) — choose below to confirm.").font(.caption) }
            if item.category == "Protein" { Text("Keep raw meat/fish sealed to prevent drips. Freeze portions for later days promptly; thaw in the fridge in advance.").font(.caption) }
            TextField("Actual amount (\(item.unit))",text:$amount).keyboardType(.decimalPad)
            Picker("Actual location",selection:$location) { Text("Choose…").tag(""); ForEach(compatible) { l in Text(store.state.describe(l)).tag(l.id.uuidString) } }
            if compatible.isEmpty { Text("Add a \(item.storage) location in Settings first.").foregroundStyle(.orange) }
            Button("Placed here — confirm") { if let id = UUID(uuidString:location), let qty = validAmount { store.update { $0.storePurchase(purchase.id,location:id,actualQuantity:qty) } } }.disabled(validAmount == nil || UUID(uuidString:location) == nil)
        }.onAppear { if amount.isEmpty { amount = String(purchase.quantity) } }
    }
}
/// What is in this kitchen right now, and where it is.
///
/// Grouped by the place it actually lives, so "where is the ginger?" is answered by
/// looking at the shelf it is on rather than scrolling one long list.
struct KitchenView: View {
    @EnvironmentObject var store: FamilyStore
    @State private var add = false
    @State private var editing: Stock?
    @State private var photos: [PhotosPickerItem] = []
    @State private var camera = false
    @State private var cameraDenied = false
    @State private var selectedPhoto: String?
    @State private var addAfterPhoto = false
    @State private var showPhotos = false

    /// The same fast path as the shop check: ask only when there is something left
    /// to ask, and otherwise go straight to the viewfinder.
    private func openCamera() {
        guard CameraAccess.hasCamera else { return }
        if CameraAccess.isAuthorized { camera = true; return }
        if CameraAccess.isDenied { cameraDenied = true; return }
        Task {
            if await AVCaptureDevice.requestAccess(for: .video) { camera = true } else { cameraDenied = true }
        }
    }

    private var confirmed: [Stock] { store.state.stock.filter(\.confirmed) }
    private var unconfirmed: [Stock] { store.state.stock.filter { !$0.confirmed } }
    private var placesWithFood: [Location] {
        store.state.locations.filter { location in store.state.stock.contains { $0.location == location.id } }
    }
    /// The appliances that actually hold something, in the order they were set up,
    /// so the kitchen reads the way it is walked: this fridge, then that one.
    private var appliancesWithFood: [Appliance] {
        store.state.appliances.filter { appliance in
            store.state.compartments(of: appliance.id).contains { location in
                store.state.stock.contains { $0.location == location.id }
            }
        }
    }
    private var looseWithFood: [Location] {
        let loose = Set(store.state.looseLocations.map(\.id))
        return placesWithFood.filter { loose.contains($0.id) }
    }
    private var unplaced: [Stock] {
        store.state.stock.filter { stock in
            stock.location == nil || !store.state.locations.contains { $0.id == stock.location }
        }
    }

    var body: some View {
        List {
            summarySection
            if store.state.stock.isEmpty { emptySection } else { inventorySections }
            photoSection
            safetySection
        }
        .navigationTitle("Our kitchen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }
                    .accessibilityIdentifier("openSettings")
            }
        }
        .sheet(isPresented:$add) { NavigationStack { StockEditor(existing:nil) } }
        .sheet(item:$editing) { item in NavigationStack { StockEditor(existing:item) } }
        .alert("Camera access is off", isPresented:$cameraDenied) {
            Button("Open Settings") { if let url = URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            Button("Cancel", role:.cancel) {}
        } message: { Text("Allow camera access in Settings, or use Import photos instead.") }
        .fullScreenCover(isPresented:$camera) { CameraCapture { data in Task { await store.importPhoto(data) } } }
        .sheet(isPresented:Binding(get:{selectedPhoto != nil},set:{if !$0 {selectedPhoto = nil}}), onDismiss:{ if addAfterPhoto { addAfterPhoto = false; add = true } }) {
            NavigationStack { if let name = selectedPhoto, let img = UIImage(contentsOfFile:store.directory.appendingPathComponent(name).path) {
                ScrollView { Image(uiImage:img).resizable().scaledToFit(); Text("Inspect this photo, then confirm each ingredient manually. Existing ingredient + location entries are replaced, not duplicated.").padding(); Button("Add what you see") { addAfterPhoto = true; selectedPhoto = nil }.buttonStyle(.borderedProminent) }.toolbar { Button("Done") { selectedPhoto = nil } }
            } }
        }
        .onChange(of:photos) { _, items in Task { for p in items { do { if let data = try await p.loadTransferable(type:Data.self) { await store.importPhoto(data) } } catch { store.error = "Photo import failed: \(error.localizedDescription)" } }; photos = [] } }
    }

    /// Where the kitchen stands, and the one button that matters here.
    @ViewBuilder private var summarySection: some View {
        Section {
            HStack(spacing: 18) {
                KitchenStat(number: "\(confirmed.count)", label: "confirmed\n已确认")
                KitchenStat(number: "\(store.state.appliances.count)", label: "places\n位置")
                if !unconfirmed.isEmpty {
                    KitchenStat(number: "\(unconfirmed.count)", label: "to check\n待确认", tint: Brand.clay)
                }
            }.frame(maxWidth: .infinity).padding(.vertical, 4)
            Button { add = true } label: {
                Label("Add what you have · 添加食材", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("addStock")
            if store.state.locations.isEmpty {
                NavigationLink { StorageSettingsView() } label: {
                    Label("Set up your fridges and pantries first", systemImage: "refrigerator").foregroundStyle(Brand.clay)
                }
            }
        }
    }

    @ViewBuilder private var emptySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeading(en: "Nothing recorded yet", zh: "还没有记录")
                Text("The app never assumes what you own. Add a few things you already have and the shopping list will stop asking you to buy them again.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
        }
    }

    /// One section per real place, then anything without a confirmed home.
    @ViewBuilder private var inventorySections: some View {
        ForEach(appliancesWithFood) { appliance in
            Section {
                ForEach(store.state.compartments(of: appliance.id).filter { place in
                    store.state.stock.contains { $0.location == place.id }
                }) { place in
                    // One appliance, its shelves in order, each shelf named once above
                    // the things on it.
                    Text(place.name).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    ForEach(store.state.stock.filter { $0.location == place.id }) { stock in
                        StockRow(stock: stock) { editing = stock }
                    }
                }
            } header: {
                HStack {
                    Label(appliance.name, systemImage: appliance.kind.symbol)
                    Spacer()
                    Text(appliance.place.isEmpty ? appliance.kind.en : appliance.place)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        ForEach(looseWithFood) { place in
            Section {
                ForEach(store.state.stock.filter { $0.location == place.id }) { stock in
                    StockRow(stock: stock) { editing = stock }
                }
            } header: {
                HStack {
                    Text(place.name)
                    Spacer()
                    Text(place.zone).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        if !unplaced.isEmpty {
            Section("No place confirmed · 位置待确认") {
                ForEach(unplaced) { stock in StockRow(stock: stock) { editing = stock } }
            }
        }
    }

    @ViewBuilder private var photoSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showPhotos) {
                PhotosPicker(selection:$photos,maxSelectionCount:8,matching:.images) { Label("Import photos",systemImage:"photo.on.rectangle") }
                Button { openCamera() } label:{ Label("Take a photo",systemImage:"camera") }
                    .disabled(!CameraAccess.hasCamera)
                if !store.state.photoFiles.isEmpty {
                    ScrollView(.horizontal) { LazyHStack { ForEach(store.state.photoFiles,id:\.self) { name in
                        if let image = UIImage(contentsOfFile:store.directory.appendingPathComponent(name).path) {
                            Button { selectedPhoto = name } label: { Image(uiImage:image).resizable().scaledToFill().frame(width:90,height:90).clipped().cornerRadius(10) }.buttonStyle(.plain)
                        }
                    } } }
                }
                InfoNote(title:"What happens to these photos · 照片如何处理",lines:[
                    "Photos stay on this iPhone. Nothing is uploaded and no account is involved.",
                    "Automatic recognition is not enabled — you confirm each ingredient yourself.",
                    "A photo never decides freshness or quantity; only what you confirm becomes stock."
                ])
            } label: {
                Label("Photograph a shelf · 拍照记录\(store.state.photoFiles.isEmpty ? "" : " (\(store.state.photoFiles.count))")",
                      systemImage: "camera.viewfinder")
            }
        } footer: {
            Text("A photo is a reminder for you, not a record the app reads.")
        }
    }

    @ViewBuilder private var safetySection: some View {
        Section {
            InfoNote(title:"Keeping food safe · 食品安全",lines:[
                "Fridge at or below 40°F / 4°C; freezer at or below 0°F / −18°C.",
                "Photos cannot establish whether food is still good. Check labels and storage times.",
                "Freeze raw meat and fish meant for later in the week, and move them to the fridge to thaw in advance."
            ])
            Link("FDA storage guidance",destination:URL(string:"https://www.fda.gov/consumers/consumer-updates/are-you-storing-food-safely")!).font(.footnote)
            Link("Cold storage time chart",destination:URL(string:"https://www.foodsafety.gov/food-safety-charts/cold-food-storage-charts")!).font(.footnote)
        }
    }
}

/// One number with its label, used in the kitchen summary.
struct KitchenStat: View {
    let number: String
    let label: String
    var tint: Color = Brand.deepGreen
    var body: some View {
        VStack(spacing: 2) {
            Text(number).font(.system(.title2, design: .rounded).weight(.semibold)).foregroundStyle(tint)
            Text(label).font(.caption2).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }
}

/// One thing in the kitchen. Tapping it opens the correction sheet.
struct StockRow: View {
    let stock: Stock
    let edit: () -> Void
    private var item: Ingredient { Catalog.ingredient(stock.ingredient) }
    var body: some View {
        Button(action: edit) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).foregroundStyle(.primary)
                    Text(quantityText(stock.quantity, unit: item.unit)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !stock.confirmed {
                    StatusPill(text: "To check", state: .active)
                }
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }
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
                Picker("Actual location",selection:$location) { Text("Unconfirmed").tag(""); ForEach(store.state.locations) { l in Text(store.state.describe(l)).tag(l.id.uuidString) } }
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
/// Settings as a short menu of focused screens, rather than one very long form.
struct SettingsView: View {
    @EnvironmentObject var store: FamilyStore
    var body: some View {
        List {
            Section("Our kitchen · 我们的厨房") {
                TextField("Name your kitchen, e.g. Zhang Kitchen", text: Binding(
                    get: { store.state.kitchenName },
                    set: { v in store.update { $0.kitchenName = String(v.prefix(40)) } }))
                Text("Shown at the top of Today and on the week. Leave it empty to just say \(Brand.appName).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { FamilySettingsView() } label: {
                    settingRow("Family & portions", "家人与份量", "person.2",
                               detail: store.state.members.isEmpty
                               ? "Not set up yet"
                               : "\(store.state.members.count) people · \(store.state.servings.formatted(.number.precision(.fractionLength(0...2)))) portions")
                }
                NavigationLink { AllergySettingsView() } label: {
                    settingRow("Allergies & foods to avoid", "过敏与忌口", "exclamationmark.shield",
                               detail: store.state.excludedAllergens.isEmpty
                               ? "None excluded"
                               : store.state.excludedAllergens.map(\.en).sorted().joined(separator: ", "))
                }
                NavigationLink { StorageSettingsView() } label: {
                    settingRow("Where food lives", "食物放在哪里", "refrigerator",
                               detail: store.state.locations.isEmpty
                               ? "Not set up yet"
                               : "\(store.state.appliances.count) appliance\(store.state.appliances.count == 1 ? "" : "s") · \(store.state.locations.count) places")
                }
                NavigationLink { DisplaySettingsView() } label: {
                    settingRow("Language & appearance", "语言与显示", "textformat",
                               detail: "\(store.state.recipeLanguage.en) · \(store.state.appearance.en)")
                }
                NavigationLink { AboutSettingsView() } label: {
                    settingRow("About this app", "关于", "info.circle", detail: Brand.version)
                }
            }
        }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
    }

    private func settingRow(_ en: String, _ zh: String, _ symbol: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 26).foregroundStyle(Brand.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(en)
                Text(zh).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}

/// Who lives here, and what that means at the stove.
struct FamilySettingsView: View {
    @EnvironmentObject var store: FamilyStore
    @State private var newMember = ""
    @State private var newMemberIsChild = true
    @State private var newMemberAge = 8
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { newMember.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        List {
            Section("Cooking for · 一共几份") {
                HStack {
                    Text(store.state.servings.formatted(.number.precision(.fractionLength(0...2))))
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold)).foregroundStyle(Brand.deepGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("adult portions").font(.subheadline)
                        Text(store.state.servingsExplanation).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Stepper("Guests this week: \(store.state.guests)", value: Binding(
                    get: { store.state.guests },
                    set: { n in store.update { $0.guests = n } }), in: 0...8)
                if store.state.members.isEmpty {
                    Stepper("\(store.state.people) people", value: Binding(
                        get: { store.state.people },
                        set: { n in store.update { $0.people = n } }), in: 1...12)
                }
            }

            Section("Who eats here · 家里有谁") {
                if store.state.members.isEmpty {
                    Text("Nobody added yet. Add each person below — children get a vote on every meal, and their age sets how much is cooked for them.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(store.state.members) { member in
                    NavigationLink { FamilyMemberEditor(memberID: member.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name.isEmpty ? "Unnamed" : member.name)
                                Text(member.isChild ? "Child\(member.age.map { ", age \($0)" } ?? "")" : "Adult")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(member.portionDescription).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.onDelete { offsets in store.update { $0.members.remove(atOffsets: offsets) } }
            }

            // Each control gets its own row, so taps land where they are aimed.
            Section("Add someone · 添加成员") {
                TextField("Their name", text: $newMember)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit(addMember)
                Picker("They are", selection: $newMemberIsChild) {
                    Text("A child").tag(true)
                    Text("An adult").tag(false)
                }.pickerStyle(.segmented)
                if newMemberIsChild {
                    Stepper("Age \(newMemberAge)", value: $newMemberAge, in: 0...17)
                }
                Button(action: addMember) {
                    Label("Add to the family", systemImage: "person.badge.plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedName.isEmpty)
                .accessibilityIdentifier("addFamilyMember")
                if trimmedName.isEmpty {
                    Text("Type a name first.").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                InfoNote(title: "How portions are worked out · 份量怎么算", lines: [
                    "Recipes are written for five adult portions. Everything is scaled from that.",
                    "An adult counts as one portion. A child counts by age: about a quarter under 2, 0.4 at 2–3, 0.65 at 4–8, 0.85 at 9–13, and a full portion from 14.",
                    "These are household planning figures, not nutrition requirements. Open anyone above to set their own amount if they eat more or less.",
                    "The shopping list follows this number directly, so a family with young children buys less than a family of five adults."
                ])
            }
        }.navigationTitle("Family & portions").navigationBarTitleDisplayMode(.inline)
    }

    private func addMember() {
        let name = trimmedName
        guard !name.isEmpty else { return }
        store.update {
            $0.members.append(FamilyMember(name: name, isChild: newMemberIsChild,
                                           age: newMemberIsChild ? newMemberAge : nil))
        }
        newMember = ""
        nameFocused = false
    }
}

/// One person on their own screen, so every control has room.
struct FamilyMemberEditor: View {
    @EnvironmentObject var store: FamilyStore
    let memberID: UUID
    private var member: FamilyMember? { store.state.members.first { $0.id == memberID } }

    private func update(_ change: @escaping (inout FamilyMember) -> Void) {
        store.update { state in
            guard let index = state.members.firstIndex(where: { $0.id == memberID }) else { return }
            change(&state.members[index])
        }
    }

    var body: some View {
        List {
            if let member {
                Section("Name · 名字") {
                    TextField("Name", text: Binding(get: { member.name }, set: { v in update { $0.name = v } }))
                }
                Section("They are · 身份") {
                    Picker("They are", selection: Binding(
                        get: { member.isChild },
                        set: { isChild in update { $0.isChild = isChild; if !isChild { $0.age = nil } else if $0.age == nil { $0.age = 8 } } })) {
                        Text("A child").tag(true)
                        Text("An adult").tag(false)
                    }.pickerStyle(.segmented)
                    if member.isChild {
                        Stepper("Age \(member.age ?? 8)", value: Binding(
                            get: { member.age ?? 8 },
                            set: { age in update { $0.age = age } }), in: 0...17)
                    }
                }
                Section("Portion · 份量") {
                    LabeledContent("Counts as", value: member.portionDescription)
                    Toggle("Set it by hand", isOn: Binding(
                        get: { member.portionOverride != nil },
                        set: { on in update { $0.portionOverride = on ? $0.portionFactor : nil } }))
                    if let override = member.portionOverride {
                        Stepper("\(override.formatted(.number.precision(.fractionLength(0...2)))) adult portions",
                                value: Binding(get: { override }, set: { v in update { $0.portionOverride = v } }),
                                in: 0.25...3, step: 0.25)
                    }
                    Text(member.isChild
                         ? "Set by age unless you change it here."
                         : "An adult counts as one portion unless you change it here.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("This person has been removed.")
            }
        }.navigationTitle(member?.name.isEmpty == false ? member!.name : "Family member")
         .navigationBarTitleDisplayMode(.inline)
    }
}

struct AllergySettingsView: View {
    @EnvironmentObject var store: FamilyStore
    var body: some View {
        List {
            Section {
                ForEach(Allergen.allCases, id: \.self) { allergen in
                    Toggle(allergen.name, isOn: Binding(
                        get: { store.state.excludedAllergens.contains(allergen) },
                        set: { on in store.update { s in
                            if on { s.excludedAllergens.insert(allergen) } else { s.excludedAllergens.remove(allergen) }
                        } }))
                }
            } footer: {
                Text("Excluded allergens are never recommended and never offered as a swap.")
            }
            Section {
                InfoNote(title: "What excluding does — and does not do · 排除的含义", lines: [
                    "A meal you choose yourself is still allowed, but it is clearly flagged.",
                    "This matches ingredients, not labels. Brands, sauces and shared equipment cause cross-contact that no app can see — a family managing a real allergy still reads every package.",
                    "Ordinary soy sauce contains wheat, and most dried soba is cut with wheat flour; both are marked accordingly."
                ])
            }
        }.navigationTitle("Allergies").navigationBarTitleDisplayMode(.inline)
    }
}

/// Where this family keeps food: which fridges and pantries they have, which room
/// each one stands in, and — for anyone who wants that much detail — which shelf.
///
/// The appliance and its room are the part that matters, so they come first and are
/// always filled in. The shelves inside are offered ready-made and can be cut down to
/// a single "Fridge" by anyone who would rather not think about drawers.
struct StorageSettingsView: View {
    @EnvironmentObject var store: FamilyStore
    @State private var adding: ApplianceKind?
    @State private var name = ""
    @State private var zone = "Pantry"

    private let zones = ["Refrigerated", "Frozen", "Pantry"]

    var body: some View {
        List {
            addSection
            ForEach(store.state.appliancesByPlace, id: \.place) { group in
                ForEach(group.appliances) { appliance in
                    ApplianceSection(appliance: appliance)
                }
            }
            if !store.state.looseLocations.isEmpty {
                Section("Other places · 其他位置") {
                    ForEach(store.state.looseLocations) { location in LocationRow(location: location) }
                }
            }
            byHandSection
            Section {
                Text("Removing a place never deletes the food in it — whatever was stored there simply goes back to having no confirmed place.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Where food lives").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $adding) { kind in NavigationStack { NewApplianceSheet(kind: kind) } }
    }

    @ViewBuilder private var addSection: some View {
        Section("Add · 添加") {
            ForEach(ApplianceKind.allCases, id: \.self) { kind in
                Button { adding = kind } label: {
                    HStack {
                        Label("Add a \(kind.en.lowercased()) · \(kind.zh)", systemImage: kind.symbol)
                        Spacer()
                        Text("\(store.state.applianceCount(of: kind))/\(FamilyState.maxAppliancesPerKind)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .disabled(store.state.applianceCount(of: kind) >= FamilyState.maxAppliancesPerKind)
                .accessibilityIdentifier("addAppliance-\(kind.rawValue)")
            }
            Text("Name each one and say which room it is in — “Garage fridge” is how a family with two of them actually talks. The shelves inside are yours to rename, remove or add to.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var byHandSection: some View {
        Section("A place that is not in an appliance · 单独的位置") {
            TextField("Place name, e.g. Fruit bowl", text: $name)
            Picker("Temperature zone", selection: $zone) { ForEach(zones, id: \.self) { Text($0).tag($0) } }
            Button {
                store.update { $0.locations.append(Location(name: name.trimmingCharacters(in: .whitespaces), zone: zone)) }
                name = ""
            } label: { Label("Add place", systemImage: "plus").frame(maxWidth: .infinity) }
            .buttonStyle(.bordered)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

extension ApplianceKind: Identifiable { public var id: String { rawValue } }

/// One appliance: what it is called, where it stands, and what is inside it.
struct ApplianceSection: View {
    @EnvironmentObject var store: FamilyStore
    let appliance: Appliance
    @State private var newCompartment = ""
    @State private var confirmRemoval = false

    private var compartments: [Location] { store.state.compartments(of: appliance.id) }

    var body: some View {
        Section {
            InlineTextField(prompt: "Name", value: store.state.appliance(appliance.id)?.name ?? "") { name in
                store.update { $0.renameAppliance(appliance.id, to: name) }
            }.font(.headline)
            HStack {
                Text("Room").foregroundStyle(.secondary)
                Spacer()
                InlineTextField(prompt: "Kitchen, garage…",
                                value: store.state.appliance(appliance.id)?.place ?? "") { place in
                    store.update { $0.setPlace(place, forAppliance: appliance.id) }
                }.multilineTextAlignment(.trailing)
            }
            if (store.state.appliance(appliance.id)?.place ?? "").isEmpty {
                // Suggestions, not a fixed list: plenty of homes keep a fridge
                // somewhere none of these words describe.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Appliance.suggestedPlaces, id: \.self) { place in
                            Button(place) { store.update { $0.setPlace(place, forAppliance: appliance.id) } }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }.padding(.vertical, 2)
                }
            }
            ForEach(compartments) { location in LocationRow(location: location) }
            HStack {
                TextField("Add a shelf or drawer", text: $newCompartment)
                Button {
                    store.update { $0.addCompartment(to: appliance.id, named: newCompartment) }
                    newCompartment = ""
                } label: { Image(systemName: "plus.circle.fill") }
                .buttonStyle(.borderless)
                .disabled(newCompartment.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if compartments.isEmpty {
                Text("Nothing inside yet. Add at least one place, or food here cannot be given a home.")
                    .font(.caption).foregroundStyle(Brand.clay)
            }
            Button(role: .destructive) { confirmRemoval = true } label: {
                Label("Remove this \(appliance.kind.en.lowercased())", systemImage: "trash")
            }.buttonStyle(.borderless).font(.footnote)
        } header: {
            HStack {
                Label(appliance.name, systemImage: appliance.kind.symbol)
                Spacer()
                Text(appliance.place.isEmpty ? appliance.kind.en : appliance.place)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .alert("Remove \(appliance.name)?", isPresented: $confirmRemoval) {
            Button("Remove", role: .destructive) { store.update { $0.removeAppliance(appliance.id) } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Its shelves go too. Anything stored there stays in your kitchen list, marked as having no confirmed place.")
        }
    }
}

/// Naming a new appliance before it exists, so a second fridge is never just
/// "Fridge 2" unless that is what the family wanted.
struct NewApplianceSheet: View {
    @EnvironmentObject var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    let kind: ApplianceKind
    @State private var name = ""
    @State private var place = ""
    @State private var detailed = true

    var body: some View {
        Form {
            Section("What to call it · 名称") {
                TextField(kind.defaultName, text: $name).accessibilityIdentifier("newApplianceName")
                Text("Leave it empty to just call it “\(kind.defaultName)”.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Which room · 在哪个房间") {
                TextField("Kitchen, garage…", text: $place).accessibilityIdentifier("newAppliancePlace")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Appliance.suggestedPlaces, id: \.self) { suggestion in
                            Button(suggestion) { place = suggestion }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }.padding(.vertical, 2)
                }
            }
            Section("How much detail · 分多细") {
                Picker("Inside", selection: $detailed) {
                    Text("Shelf by shelf").tag(true)
                    Text("Keep it simple").tag(false)
                }.pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(kind.startingCompartments(detailed: detailed), id: \.name) { compartment in
                        Text("· \(compartment.name)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Either way you can rename these, delete the ones you do not have, and add your own later.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button {
                store.update { $0.addAppliance(kind, named: name, place: place, detailed: detailed) }
                dismiss()
            } label: {
                Label("Add this \(kind.en.lowercased())", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("confirmAddAppliance")
        }
        .navigationTitle("Add a \(kind.en.lowercased())")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Cancel") { dismiss() } }
    }
}

struct DisplaySettingsView: View {
    @EnvironmentObject var store: FamilyStore
    /// Hours shown the way the reader's own clock shows them, 24h or am/pm.
    static func hourLabel(_ hour: Int) -> String {
        var components = DateComponents(); components.hour = hour; components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }
    var body: some View {
        List {
            Section("Recipe language · 菜谱语言") {
                Picker("Show recipes in", selection: Binding(
                    get: { store.state.recipeLanguage },
                    set: { v in store.update { $0.recipeLanguage = v } })) {
                    ForEach(RecipeLanguage.allCases, id: \.self) { Text($0.en).tag($0) }
                }.pickerStyle(.segmented)
                Text("Every built-in dish is written in both languages — the same steps, the same temperatures. Ingredient names and the shopping list stay bilingual whatever you choose, so whoever is shopping can read them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Day & night · 白天与夜间") {
                Picker("View", selection: Binding(
                    get: { store.state.appearance },
                    set: { v in store.update { $0.appearance = v } })) {
                    ForEach(Appearance.allCases, id: \.self) { Text("\($0.en) · \($0.zh)").tag($0) }
                }.pickerStyle(.segmented)
                Text(store.state.appearance.detail).font(.caption).foregroundStyle(.secondary)

                if store.state.appearance == .automatic {
                    Picker("Night from", selection: Binding(
                        get: { store.state.nightStartHour },
                        set: { h in store.update { $0.nightStartHour = h } })) {
                        ForEach(0..<24, id: \.self) { Text(Self.hourLabel($0)).tag($0) }
                    }
                    Picker("Back to day at", selection: Binding(
                        get: { store.state.nightEndHour },
                        set: { h in store.update { $0.nightEndHour = h } })) {
                        ForEach(0..<24, id: \.self) { Text(Self.hourLabel($0)).tag($0) }
                    }
                    Label(store.state.isNightHour() ? "Night view right now" : "Day view right now",
                          systemImage: store.state.isNightHour() ? "moon.stars" : "sun.max")
                        .font(.footnote).foregroundStyle(.secondary)
                    if store.state.nightStartHour == store.state.nightEndHour {
                        Text("Both times are the same, so it stays on the day view. Choose different hours.")
                            .font(.caption).foregroundStyle(Brand.clay)
                    }
                }
                InfoNote(title: "Which setting does what · 各项含义", lines: [
                    "Match phone follows iOS — including the Automatic setting in iOS Display & Brightness, which switches at sunrise and sunset.",
                    "By time switches on the hours you pick here, even when the phone stays in Light mode. The app has no location, so it works off the clock rather than your real sunset.",
                    "Either way the change happens on its own: the view turns over on the hour and again whenever you reopen the app.",
                    "Night view keeps the same colours, stepped for a dark screen — easier on the eyes when cooking late or checking tomorrow's menu in bed."
                ])
            }
        }.navigationTitle("Language & appearance").navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutSettingsView: View {
    @EnvironmentObject var store: FamilyStore
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    BrandMark(size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Brand.appName).font(.headline)
                        Text("\(Brand.appNameZh) · \(Brand.version)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                LabeledContent("Dishes", value: "\(Catalog.recipes.count)")
                LabeledContent("Your own dishes", value: "\(store.state.customRecipes.count)")
                LabeledContent("Meals recorded", value: "\(store.state.history.count)")
            }
            Section {
                InfoNote(title: "What this edition is · 这一版是什么", lines: [
                    "Everything lives on this iPhone: no account, no cloud sync, no analytics.",
                    "The one exception is importing a dish from a link, which opens the page you paste — and only then.",
                    "Parent and child roles are an agreement on a shared device, not password-protected accounts.",
                    "Recipe pictures are AI-generated illustrations made for this app, not photographs of tested cooking.",
                    "Cooking times and nutrition figures are estimates, not kitchen-tested or laboratory-measured."
                ])
            }
        }.navigationTitle("About").navigationBarTitleDisplayMode(.inline)
    }
}

/// One shelf, drawer or cupboard space.
/// One shelf, drawer or door. Renaming it, changing how cold it is, and removing it
/// are all one tap away, because no two kitchens are laid out the same.
/// A text field that saves when you finish, not on every letter.
///
/// Writing through to the store on each keystroke rewrites the whole family file and
/// redraws the list underneath the keyboard. Names are typed rarely and read often,
/// so the field keeps its own text while it is being edited and hands it over once —
/// on return, or when the cursor moves elsewhere. A change made somewhere else still
/// lands here, because the field re-reads the stored value whenever it is not the
/// one being edited.
struct InlineTextField: View {
    let prompt: String
    let value: String
    let commit: (String) -> Void
    @State private var draft: String = ""
    @FocusState private var editing: Bool

    var body: some View {
        TextField(prompt, text: $draft)
            .focused($editing)
            .submitLabel(.done)
            .onSubmit { commit(draft) }
            .onChange(of: editing) { _, nowEditing in if !nowEditing { commit(draft) } }
            .onChange(of: value) { _, latest in if !editing { draft = latest } }
            .onAppear { draft = value }
    }
}

struct LocationRow: View {
    @EnvironmentObject var store: FamilyStore
    let location: Location
    private let zones = ["Refrigerated", "Frozen", "Pantry"]
    private var zoneLabel: String {
        switch store.state.locations.first(where: { $0.id == location.id })?.zone {
        case "Frozen": return "Frozen · 冷冻"
        case "Refrigerated": return "Fridge · 冷藏"
        default: return "Room · 常温"
        }
    }
    var body: some View {
        HStack {
            InlineTextField(prompt: "Place name",
                            value: store.state.locations.first { $0.id == location.id }?.name ?? "") { name in
                store.update { $0.renameLocation(location.id, to: name) }
            }
            Spacer()
            Menu(zoneLabel) {
                ForEach(zones, id: \.self) { zone in
                    Button(zone) { store.update { state in
                        if let index = state.locations.firstIndex(where: { $0.id == location.id }) {
                            state.locations[index].zone = zone
                        }
                    } }
                }
            }.font(.caption).foregroundStyle(.secondary)
            Button(role: .destructive) {
                store.update { $0.removeLocation(location.id) }
            } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
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
