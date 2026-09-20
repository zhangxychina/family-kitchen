import SwiftUI

/// One ingredient line while a dish is being written: either matched to something the
/// kitchen knows, or kept as plain text that the shopping list will not count.
struct DraftIngredient: Identifiable {
    let id = UUID()
    var sourceText: String? = nil
    var ingredient: String? = nil
    var amount: String = ""
    var matched: Bool { ingredient != nil && Double(amount) ?? 0 > 0 }
}

/// Add a dish of your own, by hand or from a link.
///
/// Whatever arrives from the web is a draft: the family reads it, matches the
/// ingredients it recognises, and decides what to keep.
struct AddDishView: View {
    @EnvironmentObject var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    /// Set when editing a dish the family already saved.
    var existing: Recipe? = nil

    @State private var link = ""
    @State private var importing = false
    @State private var importMessage: String?
    @State private var importFailed = false

    @State private var en = ""
    @State private var zh = ""
    @State private var breakfast = false
    @State private var minutes = 30
    @State private var starch = "Rice"
    @State private var protein = "Chicken"
    @State private var vegetable = true
    @State private var basePortions = 5.0
    @State private var drafts: [DraftIngredient] = [DraftIngredient()]
    @State private var stepsZh: [String] = [""]
    @State private var stepsEn: [String] = [""]
    @State private var sourceURL: String?

    private let starches = ["Rice", "Noodles", "Bread", "Oats", "Couscous", "Other"]
    private let proteins = ["Chicken", "Beef", "Pork", "Turkey", "Fish", "Shellfish",
                            "Tofu", "Egg", "Dairy", "Legumes", "Other"]

    private var canSave: Bool {
        !(en.trimmingCharacters(in: .whitespaces).isEmpty && zh.trimmingCharacters(in: .whitespaces).isEmpty)
            && !cleanedSteps(stepsZh).isEmpty || !cleanedSteps(stepsEn).isEmpty
    }

    var body: some View {
        Form {
            if existing == nil { importSection }
            detailsSection
            ingredientsSection
            stepsSection
            Section {
                Button { save() } label: { Label("Save this dish", systemImage: "tray.and.arrow.down").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).disabled(!canSave)
                if let sourceURL, let url = URL(string: sourceURL) {
                    Link("Original page · 原始网页", destination: url).font(.footnote)
                }
            } footer: {
                Text("Saved dishes join the weekly plan, the shopping list and the nutrition estimate like any other. They stay on this iPhone.")
            }
        }
        .navigationTitle(existing == nil ? "Add a dish" : "Edit dish")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .alert("Could not import", isPresented: $importFailed) {
            Button("OK", role: .cancel) {}
        } message: { Text(importMessage ?? "") }
        .onAppear(perform: loadExisting)
    }

    // MARK: - Import

    @ViewBuilder private var importSection: some View {
        Section("Start from a link · 从网页导入") {
            TextField("https://…", text: $link)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.URL)
            Button { Task { await runImport() } } label: {
                HStack {
                    Label("Fetch this recipe", systemImage: "arrow.down.doc")
                    if importing { Spacer(); ProgressView() }
                }
            }.disabled(link.trimmingCharacters(in: .whitespaces).isEmpty || importing)
            if let importMessage, !importFailed {
                Text(importMessage).font(.footnote).foregroundStyle(Brand.protein)
            }
            InfoNote(title: "What importing does · 导入会做什么", lines: [
                "This is the only time the app uses the internet: it opens the page you paste and reads the recipe data published on it.",
                "Most recipe sites publish this; some do not, and then the dish has to be typed in by hand.",
                "Everything imported is a draft for you to check. Ingredients the app recognises can be matched below; the rest are kept as notes and left out of the shopping list.",
                "Imported text is stored on this iPhone for your own kitchen. The wording of someone else's recipe belongs to them — keep the link, and don't republish it."
            ])
        }
    }

    private func runImport() async {
        importing = true; importMessage = nil; importFailed = false
        defer { importing = false }
        do {
            let imported = try await RecipeImport.fetch(link)
            apply(imported)
            importMessage = "Imported \(imported.ingredientLines.count) ingredient lines and \(imported.steps.count) steps. Check them below."
        } catch let error as ImportError {
            importMessage = error.message; importFailed = true
        } catch {
            importMessage = error.localizedDescription; importFailed = true
        }
    }

    /// Fills the form from an imported draft, guessing only what can be guessed safely.
    private func apply(_ imported: ImportedRecipe) {
        en = imported.name
        sourceURL = imported.sourceURL
        if let minutes = imported.minutes { self.minutes = min(180, max(5, minutes)) }
        if let yieldText = imported.yieldText,
           let number = yieldText.split(whereSeparator: { !$0.isNumber }).first,
           let value = Double(number), value >= 1, value <= 20 {
            basePortions = value
        }
        drafts = imported.ingredientLines.map { line in
            let match = RecipeImport.matchIngredient(line)
            return DraftIngredient(sourceText: line, ingredient: match?.id, amount: "")
        }
        if drafts.isEmpty { drafts = [DraftIngredient()] }
        stepsEn = imported.steps.isEmpty ? [""] : imported.steps
        stepsZh = [""]
    }

    // MARK: - The dish itself

    @ViewBuilder private var detailsSection: some View {
        Section("The dish · 菜品") {
            TextField("English name", text: $en)
            TextField("中文名称", text: $zh)
            Picker("Meal", selection: $breakfast) { Text("Dinner").tag(true == false); Text("Breakfast").tag(true) }
                .pickerStyle(.segmented)
            Stepper("About \(minutes) minutes, whole meal", value: $minutes, in: 5...180, step: 5)
            Picker("Main starch", selection: $starch) { ForEach(starches, id: \.self) { Text($0) } }
            Picker("Main protein", selection: $protein) { ForEach(proteins, id: \.self) { Text($0) } }
            Toggle("Includes vegetables", isOn: $vegetable)
            Text("The starch and protein are how the planner keeps a week varied — rice after noodles, fish after chicken.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var ingredientsSection: some View {
        Section("Ingredients · 食材") {
            Stepper("Amounts below serve \(basePortions.formatted(.number.precision(.fractionLength(0...1)))) adult portions",
                    value: $basePortions, in: 1...20, step: 1)
            ForEach($drafts) { $draft in
                VStack(alignment: .leading, spacing: 6) {
                    if let text = draft.sourceText {
                        Text(text).font(.footnote).foregroundStyle(.secondary)
                    }
                    Picker("Ingredient", selection: Binding(
                        get: { draft.ingredient ?? "" },
                        set: { draft.ingredient = $0.isEmpty ? nil : $0 })) {
                        Text("Not counted").tag("")
                        ForEach(Catalog.ingredients) { Text($0.name).tag($0.id) }
                    }
                    if let id = draft.ingredient {
                        TextField("Amount in \(Catalog.ingredient(id).unit)", text: $draft.amount)
                            .keyboardType(.decimalPad)
                    }
                }
            }.onDelete { drafts.remove(atOffsets: $0) }
            Button { drafts.append(DraftIngredient()) } label: { Label("Add an ingredient", systemImage: "plus") }
            Text("Anything left as \"Not counted\" still shows with the recipe, but is left out of the shopping list and the nutrition estimate, which will say so.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var stepsSection: some View {
        Section("Steps · 做法") {
            ForEach(stepsZh.indices, id: \.self) { index in
                TextField("中文步骤 \(index + 1)", text: $stepsZh[index], axis: .vertical).lineLimit(1...6)
            }
            Button { stepsZh.append("") } label: { Label("Add a Chinese step", systemImage: "plus") }.font(.footnote)
            Divider()
            ForEach(stepsEn.indices, id: \.self) { index in
                TextField("English step \(index + 1)", text: $stepsEn[index], axis: .vertical).lineLimit(1...6)
            }
            Button { stepsEn.append("") } label: { Label("Add an English step", systemImage: "plus") }.font(.footnote)
            Text("One language is enough. Whichever you write is what everyone sees for this dish.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Saving

    private func cleanedSteps(_ steps: [String]) -> [String] {
        steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func save() {
        let chinese = cleanedSteps(stepsZh)
        let english = cleanedSteps(stepsEn)
        let englishName = en.trimmingCharacters(in: .whitespaces)
        let chineseName = zh.trimmingCharacters(in: .whitespaces)
        // Amounts are stored against five adult portions, the scale the catalogue uses.
        let factor = 5 / max(1, basePortions)
        let portions = drafts.compactMap { draft -> Portion? in
            guard let id = draft.ingredient, let amount = Double(draft.amount), amount > 0 else { return nil }
            return Portion(id, amount * factor)
        }
        let notes = drafts.compactMap { draft -> String? in
            guard draft.ingredient == nil, let text = draft.sourceText?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
            return text
        }
        let recipe = Recipe(id: existing?.id ?? "family-\(UUID().uuidString)",
                            en: englishName.isEmpty ? chineseName : englishName,
                            zh: chineseName.isEmpty ? englishName : chineseName,
                            breakfast: breakfast,
                            minutes: minutes,
                            starch: starch,
                            protein: protein,
                            vegetable: vegetable,
                            ingredients: portions,
                            steps: chinese.isEmpty ? english : chinese,
                            favorite: false,
                            stepsEnglish: english.isEmpty ? nil : english,
                            sourceURL: sourceURL,
                            unmatchedIngredients: notes.isEmpty ? nil : notes)
        if store.update({ $0.saveCustomRecipe(recipe) }) { dismiss() }
    }

    private func loadExisting() {
        guard let existing, en.isEmpty, zh.isEmpty else { return }
        en = existing.en; zh = existing.zh
        breakfast = existing.breakfast; minutes = existing.minutes
        starch = existing.starch; protein = existing.protein; vegetable = existing.vegetable
        sourceURL = existing.sourceURL
        basePortions = 5
        drafts = existing.ingredients.map {
            DraftIngredient(ingredient: $0.ingredient,
                            amount: $0.quantity.formatted(.number.precision(.fractionLength(0...2))))
        }
        drafts += (existing.unmatchedIngredients ?? []).map { DraftIngredient(sourceText: $0) }
        if drafts.isEmpty { drafts = [DraftIngredient()] }
        stepsZh = existing.steps.isEmpty ? [""] : existing.steps
        stepsEn = existing.stepsEnglish ?? [""]
    }
}
