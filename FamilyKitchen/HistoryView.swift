import SwiftUI

/// What the family has actually eaten, so next week's menu can be different.
///
/// Two kinds of entry live here, and they are never blurred together: meals someone
/// confirmed cooking, and meals that were planned and then passed without confirmation.
/// The app does not claim to know whether the second kind was eaten.
struct HistoryView: View {
    @EnvironmentObject var store: FamilyStore
    @State private var showPlannedOnly = false

    private var records: [MealRecord] {
        store.state.history.filter { !showPlannedOnly || $0.cooked }.sorted { $0.date > $1.date }
    }
    private var weeks: [Date] {
        var seen: [Date] = []
        for record in records {
            let week = Calendar.current.dateInterval(of: .weekOfYear, for: record.date)?.start ?? record.date
            if !seen.contains(week) { seen.append(week) }
        }
        return seen
    }
    /// The dishes that have come round most often lately — the honest answer to
    /// "are we eating the same thing all the time?"
    private var frequent: [(recipe: Recipe, count: Int, days: Int?)] {
        let counts = Dictionary(grouping: store.state.history.filter { $0.date >= Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast },
                                by: \.recipe).mapValues(\.count)
        return counts.compactMap { id, count in
            guard let recipe = Catalog.recipe(id), count > 1 else { return nil }
            return (recipe, count, store.state.daysSinceLastEaten(id))
        }.sorted { $0.count == $1.count ? $0.recipe.en < $1.recipe.en : $0.count > $1.count }
    }

    var body: some View {
        List {
            if store.state.history.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeading(en: "Nothing recorded yet", zh: "还没有记录")
                        Text("Meals appear here once you mark them cooked, and whenever a planned week is replaced by a new one. After a few weeks this becomes the memory the planner uses to keep menus varied.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
            } else {
                Section {
                    Toggle("Confirmed meals only · 只看已确认", isOn: $showPlannedOnly)
                    Text("\(store.state.history.filter(\.cooked).count) cooked · \(store.state.history.count) recorded in total")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !frequent.isEmpty {
                    Section("Most often, last 90 days · 近三个月最常吃") {
                        ForEach(frequent.prefix(5), id: \.recipe.id) { entry in
                            HStack(spacing: 12) {
                                RecipeArtwork(recipe: entry.recipe, height: 46).frame(width: 46).clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.recipe.en).font(.subheadline)
                                    Text(entry.recipe.zh).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(entry.count)×").font(.subheadline.weight(.semibold))
                                    if let days = entry.days {
                                        Text(days == 0 ? "today" : "\(days)d ago").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                ForEach(weeks, id: \.self) { week in
                    Section(week.formatted(.dateTime.month(.abbreviated).day()) + " · week of") {
                        ForEach(records.filter { Calendar.current.dateInterval(of: .weekOfYear, for: $0.date)?.start == week }) { record in
                            if let recipe = Catalog.recipe(record.recipe) {
                                HStack(spacing: 12) {
                                    RecipeArtwork(recipe: recipe, height: 52).frame(width: 52).clipShape(RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(recipe.en).font(.subheadline)
                                        Text(recipe.zh).font(.caption).foregroundStyle(.secondary)
                                        Text("\(record.date.formatted(.dateTime.weekday(.abbreviated))) · \(record.breakfast ? "Breakfast" : "Dinner") · \(record.people) people")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusPill(text: record.cooked ? "Cooked" : "Planned", state: record.cooked ? .done : .waiting)
                                }
                            }
                        }
                    }
                }
                Section {
                    InfoNote(title: "How this record is kept · 记录怎么来的", lines: [
                        "\"Cooked\" means someone confirmed it on the day. \"Planned\" means it was on the menu and the week moved on — the app does not assume it was eaten.",
                        "Planning next week uses this: a dish eaten in the last fortnight is pushed well down the list, and one that keeps reappearing within three months is nudged down too.",
                        "About two years of meals are kept, on this iPhone only."
                    ])
                }
            }
        }.navigationTitle("What we've eaten").navigationBarTitleDisplayMode(.inline)
    }
}
