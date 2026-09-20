import SwiftUI
import PhotosUI
import UIKit
import ImageIO

@MainActor final class FamilyStore: ObservableObject {
    @Published var state: FamilyState
    @Published var error: String?
    /// Selected tab, so one screen can send the family to the next step.
    @Published var tab: Int = 0
    /// Whether to show the night view right now, or nil to let iOS decide.
    ///
    /// This lives here rather than in the view because the switching has to be driven
    /// by a timer, and a timer owned by a `View` is rebuilt — and so restarted — every
    /// time anything republishes. A store is made once and kept.
    @Published private(set) var prefersNight: Bool?
    private var appearanceTimer: Timer?
    private var loadBlocked = false
    let directory: URL
    let file: URL
    init() {
        let uiTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent(uiTesting ? "FamilyKitchenUITests" : "FamilyKitchen")
        file = directory.appendingPathComponent("family.json")
        // Up to 0.3 the app stored everything under its old internal name. Move that
        // folder across once, so renaming the project never loses someone's kitchen.
        let legacy = support.appendingPathComponent(uiTesting ? "FamilyTableUITests" : "FamilyTable")
        if !FileManager.default.fileExists(atPath: directory.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: directory)
        }
        if uiTesting && ProcessInfo.processInfo.arguments.contains("--reset-ui-tests") {
            try? FileManager.default.removeItem(at: directory)
        }
        defer { Catalog.setCustomRecipes(state.customRecipes) }
        do { state = try StateFile.load(from: file) }
        catch {
            state = FamilyState()
            if FileManager.default.fileExists(atPath: file.path) {
                loadBlocked = true
                self.error = (error as? StateError) == .newerVersion
                    ? "This kitchen was saved by a newer version of \(Brand.appName). Update the app to open it. Your data is untouched."
                    : "Saved data could not be read. Original file is preserved. Restart before making changes or restore your backup."
            }
        }
        refreshAppearance()
        // A phone that was asleep at 7am, or whose clock moved, gets the same answer
        // as one that was awake for it.
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshAppearance() }
        }
    }

    /// Works out which view to show, and wakes up exactly when it next changes.
    ///
    /// The old version asked the clock every sixty seconds. It never got there: the
    /// timer was a property of the root view, so every tab tap and every saved change
    /// rebuilt the view, replaced the timer, and started the minute again. "By time"
    /// therefore only ever switched on launch. This schedules the one moment that
    /// matters — `nextAppearanceChange` — which is an absolute time, so rescheduling
    /// it cannot push it away.
    func refreshAppearance() {
        prefersNight = state.prefersNight()
        appearanceTimer?.invalidate()
        appearanceTimer = nil
        guard let next = state.nextAppearanceChange() else { return }
        appearanceTimer = Timer.scheduledTimer(
            withTimeInterval: max(1, next.timeIntervalSinceNow), repeats: false
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshAppearance() }
        }
    }
    @discardableResult func update(_ action: (inout FamilyState) -> Void) -> Bool {
        guard !loadBlocked else { return false }
        var next = state; action(&next)
        do {
            try StateFile.save(next, to: file); state = next; error = nil
            refreshAppearance()
            return true
        } catch {
            // A dish that could not be saved must not linger in the catalogue.
            Catalog.setCustomRecipes(state.customRecipes)
            self.error = "Could not save changes: \(error.localizedDescription). Please try again."
            return false
        }
    }
    /// Where something is, in words worth reading: the appliance and the shelf, not
    /// the shelf alone. With two fridges in the house, "Top shelf" answers nothing.
    func location(_ id: UUID?) -> String { state.locationLabel(id) }
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
@main struct FamilyKitchenApp: App {
    @StateObject private var store = FamilyStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).tint(Brand.green) }
    }
}
struct RootView: View {
    @EnvironmentObject var store: FamilyStore
    @Environment(\.scenePhase) private var scenePhase

    /// nil hands the choice to iOS, which has its own sunrise-to-sunset switching.
    private var scheme: ColorScheme? {
        store.prefersNight.map { $0 ? .dark : .light }
    }

    var body: some View {
        TabView(selection:$store.tab) {
            NavigationStack { TodayView() }.tabItem { Label("Today", systemImage:"sun.max") }.tag(0)
            NavigationStack { WeekView() }.tabItem { Label("Week", systemImage:"calendar") }.tag(1)
            NavigationStack { RecipesView() }.tabItem { Label("Recipes", systemImage:"book.closed") }.tag(2)
            NavigationStack { ShoppingView() }.tabItem { Label("Shopping", systemImage:"basket") }.tag(3)
            NavigationStack { KitchenView() }.tabItem { Label("Kitchen", systemImage:"refrigerator") }.tag(4)
        }.safeAreaInset(edge:.top) { if let error = store.error { Text(error).font(.caption).foregroundStyle(.red).padding().background(Brand.card) } }
        .preferredColorScheme(scheme)
        // Timers do not fire while the app is in the background, so the evening it
        // spent in a pocket is caught up with here.
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshAppearance() } }
        .animation(.easeInOut(duration: 0.35), value: scheme)
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
                    Brand.placeholder
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
    @EnvironmentObject var store: FamilyStore
    let recipe: Recipe
    private var month: Int { Calendar.current.component(.month,from:Date()) }
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            RecipeArtwork(recipe: recipe)
            VStack(alignment:.leading,spacing:5) {
                switch store.state.recipeLanguage {
                case .both:
                    Text(recipe.en).font(.title3.bold()).foregroundStyle(.primary)
                    Text(recipe.zh).foregroundStyle(.secondary)
                case .english:
                    Text(recipe.en).font(.title3.bold()).foregroundStyle(.primary)
                case .chinese:
                    Text(recipe.zh).font(.title3.bold()).foregroundStyle(.primary)
                }
                Text(recipe.flavor).font(.caption).foregroundStyle(recipe.isSpicy ? Color.orange : Color.secondary)
                Label("\(recipe.minutes) min · whole meal",systemImage:"clock").font(.caption).foregroundStyle(.secondary)
                let conflicts = recipe.conflicts(with:store.state.excludedAllergens)
                HStack(spacing: 8) {
                    if !conflicts.isEmpty {
                        Label("Contains \(conflicts.map(\.en).sorted().joined(separator: ", "))",systemImage:"exclamationmark.triangle.fill")
                            .font(.caption2.weight(.medium)).foregroundStyle(Brand.clay)
                            .padding(.horizontal,8).padding(.vertical,4)
                            .background(Brand.clay.opacity(0.1),in:Capsule())
                    }
                    if recipe.isInSeason(month:month) {
                        Label("In season · 应季",systemImage:"leaf.fill")
                            .font(.caption2.weight(.medium)).foregroundStyle(Brand.protein)
                            .padding(.horizontal,8).padding(.vertical,4)
                            .background(Brand.protein.opacity(0.1),in:Capsule())
                    }
                }
            }.padding([.horizontal,.bottom])
        }.background(Brand.card).clipShape(RoundedRectangle(cornerRadius:20)).overlay(RoundedRectangle(cornerRadius:20).stroke(.primary.opacity(0.06)))
    }
}
struct TodayView: View {
    @EnvironmentObject var store: FamilyStore
    @State private var finishMeal: Meal?
    var today: [Meal] { store.state.meals.filter { Calendar.current.isDateInToday($0.date) } }
    private var dayNutrition: Nutrition { store.state.nutrition(on: .now) }

    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                BrandHeader(kitchenName: store.state.kitchenName,
                            subtitle: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                SectionHeading(en:"A little less planning.\nA little more together.",zh:"少一点操心，多一点一起吃饭")
                if store.state.locations.isEmpty { setupCard }
                if today.isEmpty { emptyDayCard } else { mealCards; nutritionCard }
                JourneyStrip(steps:journey) { store.tab = $0 }.kitchenCard()
                InfoNote(title:"What this app does not do · 这个应用不做什么",lines:[
                    "Breakfast and dinner only — lunch, snacks and what each person actually eats are not counted.",
                    "Portions are a starting point for the whole family, not age-specific nutrition advice.",
                    "Nutrition figures are reference values for ingredients as bought, not measurements of the finished dish."
                ]).kitchenCard()
            }.padding(20)
        }.background(Brand.paper).navigationTitle(store.state.kitchenName.isEmpty ? Brand.appName : store.state.kitchenName).navigationBarTitleDisplayMode(.inline).kitchenChat()
        .confirmationDialog("Update what you have at home? Adjust leftovers in Kitchen afterward.",isPresented:Binding(get:{ finishMeal != nil },set:{ if !$0 { finishMeal = nil } }),titleVisibility:.visible) {
            Button("Complete & deduct recipe amounts") { if let m = finishMeal { store.update { $0.finish(m.id,consume:true) } }; finishMeal = nil }
            Button("Complete without deducting") { if let m = finishMeal { store.update { $0.finish(m.id,consume:false) } }; finishMeal = nil }
        }
    }

    @ViewBuilder private var setupCard: some View {
        VStack(alignment:.leading,spacing:10) {
            SectionHeading(en:"First, where does food live?",zh:"先告诉我食物放在哪里")
            Text("Add your real fridge shelves, drawers and cupboards once. After that the app can tell everyone where each ingredient is.").font(.footnote).foregroundStyle(.secondary)
            NavigationLink { StorageSettingsView() } label: { Label("Set up our kitchen",systemImage:"refrigerator").frame(maxWidth:.infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }.kitchenCard()
    }

    @ViewBuilder private var emptyDayCard: some View {
        VStack(alignment:.leading,spacing:12) {
            SectionHeading(en:store.state.isPlanned ? "Nothing scheduled today" : "Let's plan a week",
                           zh:store.state.isPlanned ? "今天没有安排" : "来排一周的饭")
            Text(store.state.isPlanned
                 ? "This week's menu doesn't cover today. Open Week to plan another stretch of days."
                 : "Pick a start date and get seven days of breakfast and dinner — then a shopping list for exactly what's missing.")
                .font(.footnote).foregroundStyle(.secondary)
            Button { store.tab = 1 } label: {
                Label(store.state.isPlanned ? "Open the week" : "Plan next week's menu",systemImage:"calendar").frame(maxWidth:.infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("todayPlanWeek")
        }.kitchenCard()
    }

    @ViewBuilder private var mealCards: some View {
        ForEach(today) { meal in
            if let r = Catalog.recipe(meal.recipe) {
                VStack(alignment:.leading,spacing:12) {
                    HStack {
                        Text(meal.breakfast ? "BREAKFAST · 早餐" : "DINNER · 晚餐").font(.caption.bold()).tracking(1.5).foregroundStyle(.secondary)
                        Spacer()
                        StatusPill(text: meal.cooked ? "Cooked" : meal.approved ? "Confirmed" : "Needs review",
                                   state: meal.cooked ? .done : meal.approved ? .done : .active)
                    }
                    NavigationLink { RecipeDetail(recipe:r) } label: { RecipeCard(recipe:r) }.buttonStyle(.plain)
                    Button(meal.cooked ? "Meal completed" : "We cooked this") { finishMeal = meal }
                        .buttonStyle(.borderedProminent).disabled(meal.cooked).frame(maxWidth:.infinity)
                }.kitchenCard()
            }
        }
    }

    @ViewBuilder private var nutritionCard: some View {
        NutritionCard(title:"Today, per person",zh:"今天每人（早餐+晚餐）",nutrition:dayNutrition,
                      note:"Breakfast and dinner only. Lunch and snacks are not part of this plan, so this is not a whole day of eating.",
                      complete:today.compactMap { Catalog.recipe($0.recipe) }.allSatisfy(\.nutritionIsComplete))
            .kitchenCard()
    }

    /// The whole app, described as the five things a week actually involves.
    private var journey: [JourneyStep] {
        let progress = store.state.approvalProgress
        let planned = store.state.isPlanned
        let allConfirmed = planned && progress.approved == progress.total
        let toBuy = store.state.itemsToBuy
        let waitingToStore = store.state.purchases.filter { !$0.stored }.count
        let cookedToday = !today.isEmpty && today.allSatisfy(\.cooked)
        return [
            JourneyStep(title:"Plan the week",zh:"排菜单",
                        detail: planned ? "Seven days of breakfast and dinner are on the calendar." : "Pick a start date and get a week of meals.",
                        symbol:"calendar",state: planned ? .done : .active,tab:1),
            JourneyStep(title:"Everyone chooses",zh:"一起点餐",
                        detail: !planned ? "The children vote and swap once a menu exists." : allConfirmed ? "All \(progress.total) meals are confirmed." : "\(progress.total - progress.approved) meals still need a swap or a confirmation.",
                        symbol:"hand.thumbsup",state: !planned ? .waiting : allConfirmed ? .done : .active,tab:1),
            JourneyStep(title:"Shop once",zh:"一次买齐",
                        detail: !planned ? "The list builds itself from the menu." : toBuy > 0 ? "\(toBuy) items are missing from your kitchen." : "Nothing left to buy for this menu.",
                        symbol:"basket",state: !planned ? .waiting : toBuy > 0 ? .active : .done,tab:3),
            JourneyStep(title:"Put it away",zh:"收纳归位",
                        detail: waitingToStore > 0 ? "\(waitingToStore) bought items are waiting for a shelf." : "Everything bought has a confirmed place.",
                        symbol:"shippingbox",state: waitingToStore > 0 ? .active : planned ? .done : .waiting,tab:3),
            JourneyStep(title:"Cook tonight",zh:"照着做饭",
                        detail: today.isEmpty ? "Today's meals appear here once the week covers today." : cookedToday ? "Today's meals are done. Nice work." : "Today's recipe, amounts and where each ingredient is.",
                        symbol:"flame",state: today.isEmpty ? .waiting : cookedToday ? .done : .active,tab:0)
        ]
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
                Section {
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
                } header: {
                    HStack {
                        Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        Spacer()
                        Text("\(Int(store.state.nutrition(on:date).kcal.rounded())) kcal / person")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if store.state.isPlanned { checkout }
        }.navigationTitle("Our week").kitchenChat()
        .confirmationDialog("Replace the current menu? Purchased groceries and what you have at home will be kept.",isPresented:$replacePlan,titleVisibility:.visible) { Button("Replace menu") { generate() } }
    }

    /// Step 1 when nothing is planned: the single obvious way into next week's menu.
    @ViewBuilder private var starter: some View {
        Section {
            VStack(alignment:.leading,spacing:14) {
                Text("Plan next week's menu").font(.system(.title2, design:.serif).bold())
                Text("一周早餐和晚餐，一次排好").foregroundStyle(.secondary)
                Text("Pick the first day, and you get seven days of breakfast and dinner, cooked for \(store.state.servingsExplanation). Nothing is ordered until you confirm each meal.").font(.footnote).foregroundStyle(.secondary)
                DatePicker("Week starting",selection:$start,displayedComponents:.date)
                Button { generate() } label: { Label("Plan this week's menu · 生成一周菜单",systemImage:"wand.and.stars").frame(maxWidth:.infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("planWeek")
                NavigationLink { HistoryView() } label: { Label("What we've eaten · 吃过什么",systemImage:"clock.arrow.circlepath") }
            }.padding(.vertical,6)
        } footer: {
            InfoNote(title:"How the week is chosen · 菜单怎么排出来的",lines:[
                "Mild meals only; spicy dishes are never recommended, though you can swap one in.",
                "Rice and noodles alternate, and no dinner repeats within the week.",
                "Produce at its seasonal peak is favoured, so the week follows the calendar — tomatoes and zucchini in summer, cabbage and broccoli in winter.",
                "Anything eaten recently is pushed down the list; the last fortnight counts most.",
                "Allergens your household excludes are never recommended or offered as a swap.",
                "Ingredients you have already confirmed at home raise a meal's chances, so less is bought twice.",
                "Dinner times assume 5–6 people, quick-cooking rice, thawed ingredients and two burners.",
                "Breakfast preferences are not known yet — review the first week together and swap freely."
            ])
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
            NutritionCard(title:"Average day, per person",zh:"本周平均每天每人（早餐+晚餐）",
                          nutrition:store.state.averagePlannedDay,
                          note:"Breakfast and dinner only, so this is not a full day of eating. Useful for comparing one week with another.")
                .padding(.vertical,6)
            Button { store.update { $0.approveAll() } } label: { Label("Confirm all \(progress.total) meals",systemImage:"checkmark.seal") }
                .disabled(progress.approved == progress.total).accessibilityIdentifier("confirmAllMeals")
            NavigationLink { HistoryView() } label: { Label("What we've eaten · 吃过什么",systemImage:"clock.arrow.circlepath") }
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
            Text("Amounts are combined across meals, scaled to \(store.state.servingsExplanation), and reduced by what you have confirmed at home.").font(.footnote).foregroundStyle(.secondary)
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
                    let month = Calendar.current.component(.month,from:m.date)
                    let seasonal = r.seasonalIngredients(month:month).inSeason
                    if !seasonal.isEmpty {
                        Label("In season now: \(seasonal.map(\.en).joined(separator: ", ")) · 应季",systemImage:"leaf")
                            .font(.footnote).foregroundStyle(Brand.protein)
                    }
                    if let days = store.state.daysSinceLastEaten(r.id,asOf:m.date) {
                        Text("Last eaten \(days) day\(days == 1 ? "" : "s") before this meal · \(store.state.timesEaten(r.id,asOf:m.date)) time(s) in 90 days")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("New to the family · 还没吃过").font(.footnote).foregroundStyle(.secondary)
                    }
                    let perPerson = r.nutrition(per:store.state.servings)
                    Text("About \(Int(perPerson.kcal.rounded())) kcal and \(Int(perPerson.protein.rounded()))g protein per person · 每人约 \(Int(perPerson.kcal.rounded())) 千卡")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(store.state.warnings(for:m),id:\.self) { Text($0).foregroundStyle(.orange) }
                }
                Section("Everyone gets a say") {
                    let voters = store.state.members.filter(\.isChild)
                    if voters.isEmpty {
                        NavigationLink { FamilySettingsView() } label: {
                            Label("Add your family to vote · 添加家庭成员",systemImage:"person.2.badge.plus")
                        }
                        Text("Once the children are listed in settings, each of them gets a vote here.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(voters) { member in
                        let key = member.id.uuidString
                        Picker(member.name,selection:Binding(get:{ m.votes[key] ?? "Not yet" },set:{ value in store.update { s in if let i = s.meals.firstIndex(where:{$0.id == mealID}) { s.meals[i].votes[key] = value; s.meals[i].approved = false } } })) {
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
    @EnvironmentObject var store: FamilyStore
    @State private var search = ""
    @State private var seasonalOnly = false
    @State private var addingDish = false
    @State private var category = "All"
    @State private var flavor = "All"
    private var filtered: [Recipe] {
        Catalog.recipes.filter { recipe in
            (category == "All" || (category == "Breakfast" ? recipe.breakfast : !recipe.breakfast)) &&
            (flavor == "All" || (flavor == "Mild" ? !recipe.isSpicy : recipe.cuisine == flavor)) &&
            (!seasonalOnly || recipe.isInSeason(month: Calendar.current.component(.month, from: Date()))) &&
            (search.isEmpty || (recipe.name + " " + recipe.flavor).localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(spacing:18) {
                Picker("Meal type", selection:$category) {
                    Text("All").tag("All")
                    Text("Dinner").tag("Dinner")
                    Text("Breakfast").tag("Breakfast")
                }.pickerStyle(.segmented).accessibilityIdentifier("recipeCategory")
                Text("\(filtered.count) of \(Catalog.recipes.count) dishes · \(Catalog.recipes.filter{ !$0.breakfast }.count) dinners + \(Catalog.recipes.filter(\.breakfast).count) breakfasts\(store.state.customRecipes.isEmpty ? "" : " · \(store.state.customRecipes.count) of your own")")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Flavor", selection:$flavor) {
                    Text("All flavors").tag("All")
                    Text("Mild · 不辣").tag("Mild")
                    Text("Hunan · 湘菜").tag("Hunan · 湘菜")
                    Text("Sichuan · 川菜").tag("Sichuan · 川菜")
                }.pickerStyle(.menu).accessibilityIdentifier("recipeFlavor")
                Text("Spicy meals are optional swaps; weekly recommendations stay mild.").font(.caption).foregroundStyle(.secondary)
                Toggle("In season this month · 只看应季",isOn:$seasonalOnly).font(.subheadline)
                let produce = Catalog.produceInSeason(month:Calendar.current.component(.month,from:Date()))
                if !produce.isEmpty {
                    Text("At its peak right now: \(produce.map(\.en).joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
                }
                if filtered.isEmpty { ContentUnavailableView.search(text:search) }
                ForEach(filtered) { recipe in
                    NavigationLink { RecipeDetail(recipe:recipe) } label: { RecipeCard(recipe:recipe) }.buttonStyle(.plain)
                }
            }.padding()
        }.background(Brand.paper)
        .navigationTitle("Made for home").searchable(text:$search,prompt:"English or 中文")
        .toolbar {
            Button { addingDish = true } label: { Label("Add a dish",systemImage:"plus") }
                .accessibilityIdentifier("addDish")
        }
        .sheet(isPresented:$addingDish) { NavigationStack { AddDishView() } }
    }
}
struct RecipeDetail: View {
    @EnvironmentObject var store: FamilyStore
    let recipe: Recipe
    @State private var previewPeople: Int? = nil
    private var servings: Double { previewPeople.map(Double.init) ?? store.state.servings }
    var body: some View {
        List {
            Section { RecipeArtwork(recipe:recipe, height:280).listRowInsets(EdgeInsets()); Text(recipe.name).font(.title2.bold()); Text(UIImage(named:recipe.id) == nil ? (recipe.isSpicy ? "Recipe illustration unavailable · 暂无菜品示意图" : "Image pending · 配图待完成") : "AI-generated serving illustration · AI 成品示意图，非实拍").font(.caption).foregroundStyle(.secondary)
                Text(recipe.flavor).font(.headline)
                Stepper("View portions: \(servings.formatted(.number.precision(.fractionLength(0...2))))",
                        value:Binding(get:{ previewPeople ?? Int(servings.rounded()) },set:{ previewPeople = $0 }), in:1...12)
                Text("Portion preview only. Weekly shopping uses the family size. · 此处可查看单人用量；周计划采购仍按家庭人数计算。").font(.caption)
                Text("\(servings.formatted(.number.precision(.fractionLength(0...2)))) adult portions · \(recipe.minutes) min including prep\n用量按上方份数缩放；整餐时间以五份为参考，大份量或未解冻需额外时间。")
                Button(store.state.preferred.contains(recipe.id) ? "♥ Family favorite" : "♡ Add to favorites") { store.update { s in if s.preferred.contains(recipe.id) { s.preferred.remove(recipe.id) } else { s.preferred.insert(recipe.id) } } }
            }
            Section {
                NutritionCard(title:"Per adult portion",zh:"每份成人量（共 \(servings.formatted(.number.precision(.fractionLength(0...2)))) 份）",
                              nutrition:recipe.nutrition(per:servings),
                              note:"Estimated from ingredients as bought, before cooking. Oil and seasoning are counted only in the amounts this recipe lists.",
                              complete:recipe.nutritionIsComplete)
                    .listRowInsets(EdgeInsets(top:14,leading:16,bottom:14,trailing:16))
            } header: { Text("Nutrition estimate · 营养估算") }
            if recipe.isFamilyAdded {
                Section("Your dish · 自建菜品") {
                    if let source = recipe.sourceURL, let url = URL(string:source) {
                        Link("Imported from this page · 来自网页",destination:url).font(.footnote)
                    }
                    if let extras = recipe.unmatchedIngredients, !extras.isEmpty {
                        Text("Not counted in shopping or nutrition · 不计入采购与营养：").font(.footnote)
                        ForEach(extras,id:\.self) { Text("• \($0)").font(.footnote).foregroundStyle(.secondary) }
                    }
                    NavigationLink { AddDishView(existing:recipe) } label: { Label("Edit this dish",systemImage:"pencil") }
                    Button(role:.destructive) { store.update { $0.deleteCustomRecipe(recipe.id) } } label: {
                        Label("Delete this dish",systemImage:"trash")
                    }
                    Text("Deleting also removes it from any week it was planned into.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Allergens & season · 过敏原与时令") {
                let conflicts = recipe.conflicts(with:store.state.excludedAllergens)
                if !conflicts.isEmpty {
                    Label("Contains \(conflicts.map(\.name).sorted().joined(separator: ", ")), which your household avoids.",systemImage:"exclamationmark.triangle.fill")
                        .font(.subheadline).foregroundStyle(Brand.clay)
                }
                if recipe.allergens.isEmpty {
                    Text("No major allergens among these ingredients · 无主要过敏原").font(.footnote).foregroundStyle(.secondary)
                } else {
                    ForEach(recipe.allergens.sorted { $0.rawValue < $1.rawValue },id:\.self) { allergen in
                        Text("\(allergen.name) — from \(recipe.ingredients(carrying:allergen).map(\.en).joined(separator: ", "))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("Based on ingredients, not on the label in your hand. Check packaging for the brands you buy.").font(.caption).foregroundStyle(.secondary)
                }
                let month = Calendar.current.component(.month,from:Date())
                let season = recipe.seasonalIngredients(month:month)
                if !season.inSeason.isEmpty {
                    Label("At its peak this month: \(season.inSeason.map(\.en).joined(separator: ", "))",systemImage:"leaf")
                        .font(.footnote).foregroundStyle(Brand.protein)
                }
                if !season.outOfSeason.isEmpty {
                    Text("Out of season now: \(season.outOfSeason.map(\.en).joined(separator: ", ")) — fine to buy, usually shipped and dearer.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
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
            Section {
                ForEach(Array(recipe.steps(in:store.state.recipeLanguage).enumerated()),id:\.offset) { index, step in
                    VStack(alignment:.leading,spacing:6) {
                        if let zh = step.zh { Text("\(index + 1). \(zh)") }
                        if let en = step.en {
                            Text(step.zh == nil ? "\(index + 1). \(en)" : en)
                                .foregroundStyle(step.zh == nil ? Color.primary : Color.secondary)
                        }
                    }.padding(.vertical,4)
                }
                if recipe.englishSteps == nil {
                    Text("This dish has no English steps yet, so its own wording is shown.").font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("做法 · How to cook it") }
            Section { Link("Food safety guidance · FDA",destination:URL(string:"https://www.fda.gov/food/buy-store-serve-safe-food/safe-food-handling")!) }
        }.navigationTitle(recipe.zh).navigationBarTitleDisplayMode(.inline)
    }
}
