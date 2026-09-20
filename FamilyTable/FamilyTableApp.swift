import SwiftUI
import PhotosUI
import UIKit
import ImageIO

@MainActor final class FamilyStore: ObservableObject {
    @Published var state: FamilyState
    @Published var error: String?
    /// Selected tab, so one screen can send the family to the next step.
    @Published var tab: Int = 0
    private var loadBlocked = false
    let directory: URL
    let file: URL
    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(ProcessInfo.processInfo.arguments.contains("--ui-testing") ? "FamilyTableUITests" : "FamilyTable")
        file = directory.appendingPathComponent("family.json")
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--reset-ui-tests") {
            try? FileManager.default.removeItem(at: directory)
        }
        do { state = try StateFile.load(from: file) }
        catch { state = FamilyState(); if FileManager.default.fileExists(atPath: file.path) { loadBlocked = true; self.error = "Saved data could not be read. Original file is preserved. Restart before making changes or restore your backup." } }
    }
    @discardableResult func update(_ action: (inout FamilyState) -> Void) -> Bool {
        guard !loadBlocked else { return false }
        var next = state; action(&next)
        do { try StateFile.save(next, to: file); state = next; error = nil; return true } catch { self.error = "Could not save changes: \(error.localizedDescription). Please try again."; return false }
    }
    func location(_ id: UUID?) -> String { state.locations.first { $0.id == id }?.name ?? "Location unconfirmed · 位置待确认" }
    func importPhoto(_ data: Data) async {
        guard !loadBlocked else { return }
        let name = UUID().uuidString + ".jpg"
        let url = directory.appendingPathComponent(name)
        do {
            try await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1600
                      ] as CFDictionary),
                      let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.8) else { throw PhotoError.unreadable }
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try jpeg.write(to: url, options: .atomic)
            }.value
            if !update({ $0.photoFiles.append(name) }) { try? FileManager.default.removeItem(at: url) }
        } catch { self.error = "Could not import photo. Please try another image. " + error.localizedDescription }
    }
    enum PhotoError: Error { case unreadable }

}
@main struct FamilyTableApp: App {
    @StateObject private var store = FamilyStore()
    var body: some Scene { WindowGroup { RootView().environmentObject(store).tint(Brand.green).preferredColorScheme(.light) } }
}
struct RootView: View {
    @EnvironmentObject var store: FamilyStore
    var body: some View {
        TabView(selection:$store.tab) {
            NavigationStack { TodayView() }.tabItem { Label("Today", systemImage:"sun.max") }.tag(0)
            NavigationStack { WeekView() }.tabItem { Label("Week", systemImage:"calendar") }.tag(1)
            NavigationStack { RecipesView() }.tabItem { Label("Recipes", systemImage:"book.closed") }.tag(2)
            NavigationStack { ShoppingView() }.tabItem { Label("Shopping", systemImage:"basket") }.tag(3)
            NavigationStack { PantryView() }.tabItem { Label("Pantry", systemImage:"cabinet") }.tag(4)
        }.safeAreaInset(edge:.top) { if let error = store.error { Text(error).font(.caption).foregroundStyle(.red).padding().background(.white) } }
    }
}
struct RecipeArtwork: View {
    let recipe: Recipe
    var height: CGFloat = 190
    var body: some View {
        Group {
            if let image = UIImage(named: recipe.id) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(red: 0.94, green: 0.92, blue: 0.87)
                    VStack(spacing: 5) {
                        Image(systemName: "fork.knife").font(.title2)
                        Text(recipe.isSpicy ? recipe.flavor : "Image pending").font(.caption)
                    }.foregroundStyle(.secondary)
                }
            }
        }.frame(height: height).clipped().accessibilityLabel(recipe.name)
    }
}
struct RecipeCard: View {
    let recipe: Recipe
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            RecipeArtwork(recipe: recipe)
            VStack(alignment:.leading,spacing:5) {
                Text(recipe.en).font(.title3.bold()).foregroundStyle(.primary)
                Text(recipe.zh).foregroundStyle(.secondary)
                Text(recipe.flavor).font(.caption).foregroundStyle(recipe.isSpicy ? Color.orange : Color.secondary)
                Label("\(recipe.minutes) min · whole meal",systemImage:"clock").font(.caption).foregroundStyle(.secondary)
            }.padding([.horizontal,.bottom])
        }.background(.white).clipShape(RoundedRectangle(cornerRadius:20)).overlay(RoundedRectangle(cornerRadius:20).stroke(.black.opacity(0.04)))
    }
}
struct TodayView: View {
    @EnvironmentObject var store: FamilyStore
    @State private var finishMeal: Meal?
    var today: [Meal] { store.state.meals.filter { Calendar.current.isDateInToday($0.date) } }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                BrandHeader()
                Text("A little less planning.\nA little more together.").font(.system(.largeTitle, design:.serif).bold())
                Text(Date.now.formatted(date:.complete,time:.omitted)).foregroundStyle(.secondary)
                if store.state.locations.isEmpty { NavigationLink("Start here: set up your pantry",destination:SettingsView()).buttonStyle(.borderedProminent) }
                if today.isEmpty {
                    ContentUnavailableView {
                        Label(store.state.isPlanned ? "Nothing scheduled today" : "Let's plan a week",systemImage:"fork.knife")
                    } description: {
                        Text(store.state.isPlanned ? "This week's menu doesn't cover today. Open Week to plan another stretch of days." : "Pick a start date and get seven days of breakfast and dinner, then a shopping list for exactly what's missing.")
                    } actions: {
                        Button { store.tab = 1 } label: { Label(store.state.isPlanned ? "Open the week" : "Plan next week's menu",systemImage:"calendar").frame(maxWidth:.infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("todayPlanWeek")
                    }
                }
                ForEach(today) { meal in
                    if let r = Catalog.recipe(meal.recipe) {
                        Text(meal.breakfast ? "BREAKFAST" : "DINNER").font(.caption.bold()).tracking(2)
                        NavigationLink { RecipeDetail(recipe:r) } label: { RecipeCard(recipe:r) }.buttonStyle(.plain)
                        Text(meal.approved ? "Parent confirmed" : "Waiting for parent review").font(.caption).foregroundStyle(.secondary)
                        Button(meal.cooked ? "Meal completed" : "We cooked this") { finishMeal = meal }.buttonStyle(.borderedProminent).disabled(meal.cooked)
                    }
                }
                Text("Breakfast + dinner only. Portions are a starting point, not age-specific nutrition advice. Lunch and individual needs are not included.").font(.footnote).foregroundStyle(.secondary)
            }.padding(20)
        }.background(Brand.paper).navigationTitle(Brand.appName).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Update confirmed pantry quantities? Adjust leftovers in Pantry afterward.",isPresented:Binding(get:{ finishMeal != nil },set:{ if !$0 { finishMeal = nil } }),titleVisibility:.visible) {
            Button("Complete & deduct recipe amounts") { if let m = finishMeal { store.update { $0.finish(m.id,consume:true) } }; finishMeal = nil }
            Button("Complete without deducting") { if let m = finishMeal { store.update { $0.finish(m.id,consume:false) } }; finishMeal = nil }
        }
    }
}
struct WeekView: View {
    @EnvironmentObject var store: FamilyStore
    @State private var start = FamilyState.nextMonday(after: .now)
    @State private var replacePlan = false
    var dates: [Date] { Array(Set(store.state.meals.map(\.date))).sorted() }
    var progress: (approved: Int, total: Int) { store.state.approvalProgress }
    var body: some View {
        List {
            if store.state.isPlanned { plannedHeader } else { starter }
            ForEach(dates,id:\.self) { date in
                Section(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
                    ForEach(store.state.meals.filter { $0.date == date }) { meal in
                        NavigationLink { MealReview(mealID:meal.id) } label: {
                            if let r = Catalog.recipe(meal.recipe) {
                                HStack(spacing:12) {
                                    RecipeArtwork(recipe:r, height:76).frame(width:76).clipShape(RoundedRectangle(cornerRadius:12))
                                    VStack(alignment:.leading,spacing:4) {
                                        Text(meal.breakfast ? "Breakfast" : "Dinner").font(.caption).foregroundStyle(.secondary)
                                        Text(r.en).font(.headline); Text(r.zh).font(.subheadline)
                                        Text("\(r.minutes) min · \(meal.cooked ? "Completed" : meal.approved ? "Confirmed ✓" : "Tap to confirm or swap")").font(.caption).foregroundStyle(meal.approved || meal.cooked ? .secondary : Color.orange)
                                        if !store.state.warnings(for:meal).isEmpty { Label("Review balance",systemImage:"exclamationmark.circle").font(.caption).foregroundStyle(.orange) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if store.state.isPlanned { checkout }
        }.navigationTitle("Our week")
        .confirmationDialog("Replace the current menu? Purchased groceries and pantry stock will be kept.",isPresented:$replacePlan,titleVisibility:.visible) { Button("Replace menu") { generate() } }
    }

    /// Step 1 when nothing is planned: the single obvious way into next week's menu.
    @ViewBuilder private var starter: some View {
        Section {
            VStack(alignment:.leading,spacing:14) {
                Text("Plan next week's menu").font(.system(.title2, design:.serif).bold())
                Text("一周早餐和晚餐，一次排好").foregroundStyle(.secondary)
                Text("Pick the first day, and Zhang Family Kitchen fills seven days of breakfast and dinner for \(store.state.people) people. Nothing is ordered until you confirm each meal.").font(.footnote).foregroundStyle(.secondary)
                DatePicker("Week starting",selection:$start,displayedComponents:.date)
                Button { generate() } label: { Label("Plan this week's menu · 生成一周菜单",systemImage:"wand.and.stars").frame(maxWidth:.infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("planWeek")
            }.padding(.vertical,6)
        } footer: {
            Text("Mild meals · rice and noodles alternate · confirmed pantry items come first. Breakfast preferences are not yet known; review them together. Dinner estimates assume 5–6 people, quick-cooking rice, thawed ingredients and two burners. No lunch planning.")
        }
    }

    /// Step 2 once a plan exists: where the week stands, and what is left to confirm.
    @ViewBuilder private var plannedHeader: some View {
        Section {
            VStack(alignment:.leading,spacing:10) {
                if let first = store.state.planStart, let last = store.state.planEnd {
                    Text("\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))").font(.system(.title2, design:.serif).bold())
                }
                Text("\(progress.approved) of \(progress.total) meals confirmed · 已确认 \(progress.approved)/\(progress.total)").font(.subheadline).foregroundStyle(.secondary)
                ProgressView(value:Double(progress.approved),total:Double(max(1,progress.total))).tint(Brand.green)
                Text(progress.approved == progress.total ? "Everything is confirmed. Your shopping list below is final." : "Tap any meal to swap it or confirm it. Swapping updates the shopping list right away.").font(.footnote).foregroundStyle(.secondary)
            }.padding(.vertical,4)
            Button { store.update { $0.approveAll() } } label: { Label("Confirm all \(progress.total) meals",systemImage:"checkmark.seal") }
                .disabled(progress.approved == progress.total).accessibilityIdentifier("confirmAllMeals")
            Button(role:.destructive) { replacePlan = true } label: { Label("Plan a different week",systemImage:"arrow.triangle.2.circlepath") }
        }
    }

    /// Step 3: the hand-off from the menu to the groceries it needs.
    @ViewBuilder private var checkout: some View {
        Section("Next: the groceries this menu needs") {
            Button { store.tab = 3 } label: {
                HStack {
                    Label(store.state.itemsToBuy > 0 ? "Build my shopping list · \(store.state.itemsToBuy) items to buy" : "Shopping list — nothing left to buy",systemImage:"basket")
                    Spacer(); Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary)
                }
            }.accessibilityIdentifier("goShopping")
            if !store.state.awaitingApproval.isEmpty {
                Text("\(store.state.awaitingApproval.count) meals are still unconfirmed, so the list may still change.").font(.footnote).foregroundStyle(.orange)
            }
            Text("Amounts are combined across meals, scaled to \(store.state.people) people, and reduced by pantry items you confirmed.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    func generate() { store.update { $0.plan(start:start) } }
}
struct MealReview: View {
    @EnvironmentObject var store: FamilyStore
    let mealID: UUID
    @State private var showAllSwaps = false
    @State private var includeSpicy = false
    var meal: Meal? { store.state.meals.first { $0.id == mealID } }
    var body: some View {
        List {
            if let m = meal, let r = Catalog.recipe(m.recipe) {
                Section { NavigationLink { RecipeDetail(recipe:r) } label: { RecipeCard(recipe:r) } }
                Section("Why this meal") {
                    Text("\(r.starch) + \(r.protein)\(r.vegetable ? " + vegetables" : " + fruit / grain") · \(r.flavor) · \(r.minutes) minutes including preparation.")
                    if store.state.preferred.contains(r.id) { Text("A family favorite") }
                    ForEach(store.state.warnings(for:m),id:\.self) { Text($0).foregroundStyle(.orange) }
                }
                Section("Everyone gets a say") {
                    ForEach(1...3,id:\.self) { child in
                        let key = "Child \(child)"
                        Picker(key,selection:Binding(get:{ m.votes[key] ?? "Not yet" },set:{ value in store.update { s in if let i = s.meals.firstIndex(where:{$0.id == mealID}) { s.meals[i].votes[key] = value; s.meals[i].approved = false } } })) {
                            Text("Not yet").tag("Not yet"); Text("Looks good").tag("Looks good"); Text("Prefer a swap").tag("Prefer a swap")
                        }.disabled(m.cooked)
                    }
                    Text("Different votes? Parent makes the final choice. This is a shared-device review, not a PIN-protected parent account.").font(.caption)
                    Button { store.update { s in if let i = s.meals.firstIndex(where:{$0.id == mealID}) { s.meals[i].approved = true } } } label: {
                        Label(m.approved ? "Confirmed for this day ✓" : "Confirm this meal · 确认这一餐",systemImage:m.approved ? "checkmark.seal.fill" : "checkmark.seal").frame(maxWidth:.infinity)
                    }.buttonStyle(.borderedProminent).disabled(m.cooked || m.approved)
                }
                if !m.cooked { swapSection(for:m) }
            }
        }.navigationTitle("Choose together").navigationBarTitleDisplayMode(.inline)
    }

    /// Suggested alternatives first; the full catalog stays one tap away.
    @ViewBuilder private func swapSection(for m: Meal) -> some View {
        let suggestions = store.state.swapOptions(for:m,includeSpicy:includeSpicy,limit:showAllSwaps ? nil : 6)
        let total = store.state.swapOptions(for:m,includeSpicy:includeSpicy).count
        Section {
            Text(showAllSwaps ? "All \(m.breakfast ? "breakfasts" : "dinners") in the catalog." : "Closest matches for this day: mild, quick, and not already on this week's plan.").font(.footnote).foregroundStyle(.secondary)
            ForEach(suggestions) { alternative in
                Button { store.update { $0.replace(mealID,with:alternative.id) } } label: {
                    HStack {
                        RecipeArtwork(recipe:alternative, height:65).frame(width:65).clipped().cornerRadius(10)
                        VStack(alignment:.leading,spacing:2) {
                            Text(alternative.en); Text(alternative.zh).font(.caption)
                            Text(alternative.flavor).font(.caption).foregroundStyle(alternative.isSpicy ? Color.orange : Color.secondary)
                            Text("\(alternative.minutes) min").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Button(showAllSwaps ? "Show suggestions only" : "Show all \(total) options") { showAllSwaps.toggle() }
            Toggle("Include spicy meals · 含辣味",isOn:$includeSpicy)
        } header: { Text("Swap this meal · 换一道") }
        footer: { Text("Swapping clears the votes and the approval for this day, and the shopping list is recalculated.") }
    }
}
struct RecipesView: View {
    @State private var search = ""
    @State private var category = "All"
    @State private var flavor = "All"
    private var filtered: [Recipe] {
        Catalog.recipes.filter { recipe in
            (category == "All" || (category == "Breakfast" ? recipe.breakfast : !recipe.breakfast)) &&
            (flavor == "All" || (flavor == "Mild" ? !recipe.isSpicy : recipe.cuisine == flavor)) &&
            (search.isEmpty || (recipe.name + " " + recipe.flavor).localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(spacing:18) {
                Picker("Meal type", selection:$category) {
                    Text("All (76)").tag("All")
                    Text("Dinner (56)").tag("Dinner")
                    Text("Breakfast (20)").tag("Breakfast")
                }.pickerStyle(.segmented).accessibilityIdentifier("recipeCategory")
                Text("\(filtered.count) meals · 56 dinners + 20 breakfasts").font(.caption).foregroundStyle(.secondary)
                Picker("Flavor", selection:$flavor) {
                    Text("All flavors").tag("All")
                    Text("Mild · 不辣").tag("Mild")
                    Text("Hunan · 湘菜").tag("Hunan · 湘菜")
                    Text("Sichuan · 川菜").tag("Sichuan · 川菜")
                }.pickerStyle(.menu).accessibilityIdentifier("recipeFlavor")
                Text("Spicy meals are optional swaps; weekly recommendations stay mild.").font(.caption).foregroundStyle(.secondary)
                if filtered.isEmpty { ContentUnavailableView.search(text:search) }
                ForEach(filtered) { recipe in
                    NavigationLink { RecipeDetail(recipe:recipe) } label: { RecipeCard(recipe:recipe) }.buttonStyle(.plain)
                }
            }.padding()
        }.background(Brand.paper)
        .navigationTitle("Made for home").searchable(text:$search,prompt:"English or 中文")
    }
}
struct RecipeDetail: View {
    @EnvironmentObject var store: FamilyStore
    let recipe: Recipe
    @State private var previewPeople: Int? = nil
    private var servings: Int { previewPeople ?? store.state.people }
    var body: some View {
        List {
            Section { RecipeArtwork(recipe:recipe, height:280).listRowInsets(EdgeInsets()); Text(recipe.name).font(.title2.bold()); Text(UIImage(named:recipe.id) == nil ? (recipe.isSpicy ? "Recipe illustration unavailable · 暂无菜品示意图" : "Image pending · 配图待完成") : "AI-generated serving illustration · AI 成品示意图，非实拍").font(.caption).foregroundStyle(.secondary)
                Text(recipe.flavor).font(.headline)
                Stepper("View portions: \(servings)", value:Binding(get:{ servings },set:{ previewPeople = $0 }), in:1...12)
                Text("Portion preview only. Weekly shopping uses the family size. · 此处可查看单人用量；周计划采购仍按家庭人数计算。").font(.caption)
                Text("\(servings) servings · \(recipe.minutes) min including prep\n用量按上方所选人数缩放；整餐时间以五人为参考，大份量或未解冻需额外时间。")
                Button(store.state.preferred.contains(recipe.id) ? "♥ Family favorite" : "♡ Add to favorites") { store.update { s in if s.preferred.contains(recipe.id) { s.preferred.remove(recipe.id) } else { s.preferred.insert(recipe.id) } } }
            }
            Section("Ingredients & locations · 食材与位置") {
                ForEach(recipe.scaled(servings),id:\.ingredient) { portion in
                    let item = Catalog.ingredient(portion.ingredient)
                    VStack(alignment:.leading,spacing:6) {
                        Text(item.name).font(.headline); Text(quantityText(portion.quantity,unit:item.unit))
                        let stock = store.state.stock.filter { $0.ingredient == item.id && $0.confirmed && $0.quantity > 0 }
                        if stock.isEmpty { Text("No confirmed stock · 库存待确认").font(.caption).foregroundStyle(.secondary) }
                        ForEach(stock) { entry in Text("\(store.location(entry.location)) · \(quantityText(entry.quantity,unit:item.unit))").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            Section("做法 · Whole meal timing") { ForEach(Array(recipe.steps.enumerated()),id:\.offset) { i, step in Text("\(i+1). \(step)").padding(.vertical,4) } }
            Section { Link("Food safety guidance · FDA",destination:URL(string:"https://www.fda.gov/food/buy-store-serve-safe-food/safe-food-handling")!) }
        }.navigationTitle(recipe.zh).navigationBarTitleDisplayMode(.inline)
    }
}
