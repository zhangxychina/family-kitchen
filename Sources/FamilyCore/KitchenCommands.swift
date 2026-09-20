import Foundation

// MARK: - What a sentence can ask for

/// One change to this kitchen that a spoken or typed sentence asked for.
///
/// Nothing here happens on its own. A sentence is turned into actions, the actions
/// are described back to the family in both languages, and only a tap performs them —
/// the same rule the photo check follows, and for the same reason: a recogniser that
/// hears "melons" for "lemons" must not be able to change the menu by itself.
public enum KitchenAction: Sendable, Equatable {
    /// Record an amount as already at home, place not confirmed. The shopping line
    /// then reads as covered and drops to "Nothing to buy" at the bottom of the list.
    case haveAtHome(ingredient: String, quantity: Double)
    /// Forget what was recorded at home, so the list asks for it again.
    case ranOut(ingredient: String)
    /// Tick a line off the list, exactly as tapping it would.
    case bought(ingredient: String)
    /// Put a ticked line back on the list.
    case putBack(ingredient: String)
    /// Change one planned meal to another dish.
    case swap(meal: UUID, to: String)
}

/// One action, with the sentence the family gets to read before it happens.
public struct KitchenStep: Sendable, Equatable, Identifiable {
    public var id = UUID()
    public var action: KitchenAction
    public var en: String
    public var zh: String
    public init(action: KitchenAction, en: String, zh: String) {
        self.action = action; self.en = en; self.zh = zh
    }
}

/// Everything one sentence asked for, ready to be confirmed.
public struct KitchenCommand: Sendable, Equatable, Identifiable {
    public var id = UUID()
    public var steps: [KitchenStep]
    /// Things worth saying out loud before confirming — an allergen, a dish that is
    /// spicy, an item the week was not asking for anyway.
    public var notes: [String]
    public init(steps: [KitchenStep], notes: [String] = []) {
        self.steps = steps; self.notes = notes
    }
}

/// One recogniser's reading of a single breath.
///
/// Two of these arrive together — an English ear and a Mandarin one hearing the same
/// person — and one of them has to be chosen. That choice is here rather than in the
/// screen so it can be tested without a microphone.
public struct SpokenReading: Sendable, Equatable, Identifiable {
    public var id: String { locale }
    /// "en-US" or "zh-CN", kept so the family can see which ear heard what.
    public var locale: String
    public var text: String
    /// 0–1, averaged over the words the recogniser returned.
    public var confidence: Double
    public init(locale: String, text: String, confidence: Double) {
        self.locale = locale; self.text = text; self.confidence = confidence
    }
    public var languageEN: String { locale.hasPrefix("zh") ? "Mandarin" : "English" }
    public var languageZH: String { locale.hasPrefix("zh") ? "中文" : "英文" }
    public var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// What the app made of a sentence.
public enum KitchenAnswer: Sendable {
    /// One clear reading, waiting for a tap.
    case command(KitchenCommand)
    /// The dish was not clear enough to guess at. These are the closest readings,
    /// for the family to pick from rather than for the app to choose between.
    case chooseDish(meal: UUID, slotEN: String, slotZH: String, options: [String])
    /// Nothing usable, said plainly and in both languages, with any per-item
    /// reasons — each already bilingual — for what could not be done.
    case unsure(en: String, zh: String, notes: [String] = [])
}

// MARK: - Reading a sentence

/// Turns a sentence — said out loud or typed — into changes this kitchen can make.
///
/// The whole of it runs on this iPhone with no model and no network: a table of the
/// words a family actually uses, in English and Mandarin, matched the same way the
/// photo check matches what a camera saw. It understands the handful of things the
/// week is made of, and says so plainly when a sentence is not one of them.
public enum KitchenTalk {

    // MARK: Atoms

    /// Lowercases and strips punctuation, keeping the decimal point inside a number.
    /// Chinese survives untouched, because it is matched as characters rather than
    /// as words.
    static func flatten(_ text: String) -> String {
        let scalars = Array(text.lowercased().unicodeScalars)
        var out = String.UnicodeScalarView()
        for (index, scalar) in scalars.enumerated() {
            if CharacterSet.alphanumerics.contains(scalar) { out.append(scalar) }
            else if scalar == "." , index > 0, index + 1 < scalars.count,
                    CharacterSet.decimalDigits.contains(scalars[index - 1]),
                    CharacterSet.decimalDigits.contains(scalars[index + 1]) { out.append(scalar) }
            else { out.append(" ") }
        }
        return String(String.UnicodeScalarView(out)).split(separator: " ").joined(separator: " ")
    }

    /// Breaks flattened text into the smallest pieces both languages can be compared
    /// in: one English word or number per atom, one Chinese character per atom.
    /// "500克鸡肉" becomes ["500", "克", "鸡", "肉"], so a number, a unit and a food
    /// are separable without the language needing spaces.
    static func atoms(_ flat: String) -> [String] {
        var out: [String] = []
        var current = ""
        var kind = 0                                   // 0 nothing, 1 number, 2 word
        func flush() { if !current.isEmpty { out.append(current) }; current = ""; kind = 0 }
        for character in flat {
            if character == " " { flush(); continue }
            guard character.isASCII else { flush(); out.append(String(character)); continue }
            let next = (character.isNumber || (character == "." && kind == 1)) ? 1 : 2
            if next != kind { flush() }
            current.append(character); kind = next
        }
        flush()
        return out
    }

    static func atomize(_ text: String) -> [String] { atoms(flatten(text)) }

    /// Whether two atoms are the same word, allowing for the plural a person is as
    /// likely to say as the singular — "carrots" must find the carrot.
    static func sameAtom(_ said: String, _ wanted: String) -> Bool {
        said == wanted || said == wanted + "s" || said == wanted + "es"
    }

    /// Where a phrase begins in a sentence, or nil when it is not there.
    static func index(of needle: [String], in hay: [String], from start: Int = 0) -> Int? {
        guard !needle.isEmpty, hay.count >= needle.count else { return nil }
        var position = max(0, start)
        while position + needle.count <= hay.count {
            if zip(hay[position..<(position + needle.count)], needle).allSatisfy(sameAtom) { return position }
            position += 1
        }
        return nil
    }

    static func contains(_ hay: [String], _ phrase: String) -> Bool {
        index(of: atomize(phrase), in: hay) != nil
    }

    // MARK: What the sentence is asking for

    /// The kind of change a sentence is about.
    enum Mood { case ranOut, putBack, haveAtHome, bought, swap }

    /// The words families actually use, in both languages. The longest phrase found
    /// wins, which is what keeps "we don't have milk" away from "have" and
    /// "不用买了" away from "买了".
    static let markers: [(phrase: String, mood: Mood)] = [
        ("don t have", .ranOut), ("do not have", .ranOut), ("dont have", .ranOut),
        ("out of", .ranOut), ("ran out", .ranOut), ("run out", .ranOut), ("no more", .ranOut),
        ("all gone", .ranOut), ("used up", .ranOut), ("need more", .ranOut), ("we need", .ranOut),
        ("没有了", .ranOut), ("没了", .ranOut), ("用完了", .ranOut), ("用完", .ranOut),
        ("吃完了", .ranOut), ("吃完", .ranOut), ("用光", .ranOut), ("不够了", .ranOut),
        ("不够", .ranOut), ("没有", .ranOut), ("缺", .ranOut),

        ("put back", .putBack), ("back on the list", .putBack), ("still need to buy", .putBack),
        ("didn t buy", .putBack), ("did not buy", .putBack), ("forgot to buy", .putBack),
        ("还要买", .putBack), ("还需要买", .putBack), ("忘了买", .putBack), ("没买", .putBack),
        ("放回清单", .putBack), ("重新买", .putBack),

        ("already have", .haveAtHome), ("already got", .haveAtHome), ("still have", .haveAtHome),
        ("have got", .haveAtHome), ("we have", .haveAtHome), ("i have", .haveAtHome),
        ("i ve got", .haveAtHome), ("we ve got", .haveAtHome), ("at home", .haveAtHome),
        ("in the fridge", .haveAtHome), ("in the freezer", .haveAtHome), ("in the pantry", .haveAtHome),
        ("no need to buy", .haveAtHome), ("don t need", .haveAtHome), ("do not need", .haveAtHome),
        ("不用买", .haveAtHome), ("不需要买", .haveAtHome), ("已经有", .haveAtHome),
        ("家里有", .haveAtHome), ("冰箱里有", .haveAtHome), ("柜子里有", .haveAtHome),
        ("还有", .haveAtHome), ("有了", .haveAtHome),

        ("bought", .bought), ("purchased", .bought), ("picked up", .bought),
        ("in the basket", .bought), ("in the cart", .bought), ("in the trolley", .bought),
        ("买了", .bought), ("买好了", .bought), ("买到了", .bought), ("已经买", .bought),
        ("买齐了", .bought),

        ("swap", .swap), ("change", .swap), ("replace", .swap), ("switch", .swap),
        ("instead", .swap), ("something else", .swap), ("don t want", .swap), ("do not want", .swap),
        ("换成", .swap), ("改成", .swap), ("换为", .swap), ("改为", .swap), ("换一个", .swap),
        ("换掉", .swap), ("换", .swap), ("不想吃", .swap), ("想吃", .swap), ("改一下", .swap)
    ]

    /// The longest marker present, so the more specific reading of a sentence wins.
    /// Ties keep the order above, which puts "we have run out" on the right side.
    static func mood(in sentence: [String]) -> Mood? {
        var best: (length: Int, mood: Mood)?
        for entry in markers {
            let phrase = atomize(entry.phrase)
            guard index(of: phrase, in: sentence) != nil else { continue }
            if let current = best, current.length >= phrase.count { continue }
            best = (phrase.count, entry.mood)
        }
        return best?.mood
    }

    static func hasSwapMarker(_ sentence: [String]) -> Bool {
        markers.contains { $0.mood == .swap && index(of: atomize($0.phrase), in: sentence) != nil }
    }

    // MARK: Food

    /// Every ingredient named in a sentence, in the order they were said. Longer
    /// phrases are taken first and then struck out, so "peanut butter" never also
    /// counts as peanuts.
    static func ingredients(in sentence: [String]) -> [String] {
        var remaining = sentence
        var found: [(position: Int, ingredient: String)] = []
        for entry in PantryMatcher.phrases {
            let phrase = atomize(entry.phrase)
            guard !phrase.isEmpty, let at = index(of: phrase, in: remaining) else { continue }
            if !found.contains(where: { $0.ingredient == entry.ingredient }) {
                found.append((at, entry.ingredient))
            }
            for offset in at..<(at + phrase.count) { remaining[offset] = "\u{0}" }
        }
        return found.sorted { $0.position < $1.position }.map(\.ingredient)
    }

    // MARK: Amounts

    enum Measure: Equatable { case mass(Double), volume(Double), count }

    static let units: [(word: String, measure: Measure)] = [
        ("kilograms", .mass(1000)), ("kilogram", .mass(1000)), ("kilos", .mass(1000)),
        ("kilo", .mass(1000)), ("kg", .mass(1000)),
        ("grams", .mass(1)), ("gram", .mass(1)), ("g", .mass(1)),
        ("公斤", .mass(1000)), ("千克", .mass(1000)), ("克", .mass(1)), ("斤", .mass(500)),
        ("millilitres", .volume(1)), ("milliliters", .volume(1)), ("millilitre", .volume(1)),
        ("milliliter", .volume(1)), ("ml", .volume(1)),
        ("litres", .volume(1000)), ("liters", .volume(1000)), ("litre", .volume(1000)),
        ("liter", .volume(1000)), ("l", .volume(1000)),
        ("毫升", .volume(1)), ("升", .volume(1000)),
        ("slices", .count), ("slice", .count), ("pieces", .count), ("piece", .count), ("each", .count),
        ("个", .count), ("只", .count), ("颗", .count), ("根", .count), ("瓣", .count),
        ("片", .count), ("把", .count), ("块", .count)
    ]

    static let numberWords: [String: Double] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "half": 0.5,
        "dozen": 12
    ]

    static let chineseDigits: [String: Double] = [
        "零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5,
        "六": 6, "七": 7, "八": 8, "九": 9
    ]

    /// Reads 半, 两, 十五, 二十, 三百 and the rest of the numbers a kitchen uses.
    static func chineseNumber(_ characters: [String]) -> Double? {
        if characters == ["半"] { return 0.5 }
        var total = 0.0, section = 0.0, seen = false
        for character in characters {
            if let digit = chineseDigits[character] { section = digit; seen = true }
            else if character == "十" { section = (section == 0 ? 1 : section) * 10; total += section; section = 0; seen = true }
            else if character == "百" { total += (section == 0 ? 1 : section) * 100; section = 0; seen = true }
            else if character == "千" { total += (section == 0 ? 1 : section) * 1000; section = 0; seen = true }
            else { return nil }
        }
        return seen ? total + section : nil
    }

    static func isNumeral(_ atom: String) -> Bool {
        chineseDigits[atom] != nil || ["十", "百", "千", "半"].contains(atom)
    }

    /// A number said somewhere in a sentence, with whatever unit followed it.
    struct SpokenAmount { var value: Double; var measure: Measure?; var end: Int }

    /// Words that may sit between a number and its unit, or a unit and its food:
    /// "half a kilo of pork".
    static let fillers: Set<String> = ["a", "an", "of", "the"]

    static func amounts(in sentence: [String]) -> [SpokenAmount] {
        var results: [SpokenAmount] = []
        var position = 0
        while position < sentence.count {
            var value: Double?
            var after = position
            let atom = sentence[position]
            if let digits = Double(atom), atom.first?.isNumber == true { value = digits; after = position + 1 }
            else if let word = numberWords[atom] { value = word; after = position + 1 }
            else if isNumeral(atom) {
                var run: [String] = []
                var scan = position
                while scan < sentence.count, isNumeral(sentence[scan]) { run.append(sentence[scan]); scan += 1 }
                if let number = chineseNumber(run) { value = number; after = scan }
            }
            guard let number = value else { position += 1; continue }
            var cursor = after
            while cursor < sentence.count, fillers.contains(sentence[cursor]) { cursor += 1 }
            var measure: Measure?
            var end = after
            for unit in units {
                let phrase = atomize(unit.word)
                guard !phrase.isEmpty, cursor + phrase.count <= sentence.count,
                      Array(sentence[cursor..<(cursor + phrase.count)]) == phrase else { continue }
                measure = unit.measure; end = cursor + phrase.count; break
            }
            results.append(SpokenAmount(value: number, measure: measure, end: end))
            position = max(after, end)
        }
        return results
    }

    /// The amount meant for one ingredient, in that ingredient's own unit.
    ///
    /// An amount counts when it carries a unit, or when the food follows it straight
    /// away — "two eggs", "500 g of chicken". A bare number floating elsewhere in the
    /// sentence is left alone, because "周三" is a Wednesday and not three of anything.
    ///
    /// Returns nil when nothing was said, and `.mismatch` when a number was said in
    /// units this ingredient is not measured in — two carrots cannot become grams.
    enum AmountReading: Equatable { case none, mismatch, amount(Double) }

    static func amount(for ingredient: String, in sentence: [String], allowUnitAlone: Bool) -> AmountReading {
        let unit = Catalog.ingredient(ingredient).unit
        let phrases = (PantryMatcher.synonyms[ingredient] ?? []).map(atomize).filter { !$0.isEmpty }
        var sawNumber = false
        for spoken in amounts(in: sentence) {
            var cursor = spoken.end
            while cursor < sentence.count, fillers.contains(sentence[cursor]) { cursor += 1 }
            let namesTheFood = phrases.contains { phrase in
                cursor + phrase.count <= sentence.count
                    && zip(sentence[cursor..<(cursor + phrase.count)], phrase).allSatisfy(sameAtom)
            }
            // "500 g of chicken" is about the chicken. "500 g of chicken and carrots"
            // is not about the carrots, so a unit on its own only speaks for one food.
            guard namesTheFood || (allowUnitAlone && spoken.measure != nil) else { continue }
            sawNumber = true
            switch (spoken.measure, unit) {
            case (.some(.mass(let scale)), "g"): return .amount(spoken.value * scale)
            case (.some(.volume(let scale)), "mL"): return .amount(spoken.value * scale)
            case (.some(.count), "each"), (.some(.count), "slice"): return .amount(spoken.value)
            case (nil, "each"), (nil, "slice"): return .amount(spoken.value)
            default: continue
            }
        }
        return sawNumber ? .mismatch : .none
    }

    // MARK: Days and meals

    struct SlotWords { var offset: Int?; var weekday: Int?; var breakfast: Bool?; var spans: [[String]] }

    /// Weekday numbers follow Calendar: Sunday is 1.
    static let dayPhrases: [(phrase: String, offset: Int?, weekday: Int?, breakfast: Bool?)] = [
        ("the day after tomorrow", 2, nil, nil), ("day after tomorrow", 2, nil, nil),
        ("tomorrow morning", 1, nil, true), ("tomorrow evening", 1, nil, false),
        ("tomorrow night", 1, nil, false), ("tomorrow", 1, nil, nil),
        ("this evening", 0, nil, false), ("this morning", 0, nil, true),
        ("tonight", 0, nil, false), ("today", 0, nil, nil),
        ("monday", nil, 2, nil), ("tuesday", nil, 3, nil), ("wednesday", nil, 4, nil),
        ("thursday", nil, 5, nil), ("friday", nil, 6, nil), ("saturday", nil, 7, nil),
        ("sunday", nil, 1, nil),
        ("今天晚上", 0, nil, false), ("今天早上", 0, nil, true), ("明天晚上", 1, nil, false),
        ("明天早上", 1, nil, true), ("今晚", 0, nil, false), ("明晚", 1, nil, false),
        ("今天", 0, nil, nil), ("今日", 0, nil, nil), ("明天", 1, nil, nil), ("明日", 1, nil, nil),
        ("后天", 2, nil, nil),
        ("星期一", nil, 2, nil), ("星期二", nil, 3, nil), ("星期三", nil, 4, nil),
        ("星期四", nil, 5, nil), ("星期五", nil, 6, nil), ("星期六", nil, 7, nil),
        ("星期日", nil, 1, nil), ("星期天", nil, 1, nil),
        ("礼拜一", nil, 2, nil), ("礼拜二", nil, 3, nil), ("礼拜三", nil, 4, nil),
        ("礼拜四", nil, 5, nil), ("礼拜五", nil, 6, nil), ("礼拜六", nil, 7, nil),
        ("礼拜天", nil, 1, nil), ("礼拜日", nil, 1, nil),
        ("周一", nil, 2, nil), ("周二", nil, 3, nil), ("周三", nil, 4, nil),
        ("周四", nil, 5, nil), ("周五", nil, 6, nil), ("周六", nil, 7, nil),
        ("周日", nil, 1, nil), ("周天", nil, 1, nil)
    ]

    static let mealPhrases: [(phrase: String, breakfast: Bool)] = [
        ("breakfast", true), ("morning meal", true), ("早餐", true), ("早饭", true), ("早上", true),
        ("dinner", false), ("supper", false), ("evening meal", false),
        ("晚餐", false), ("晚饭", false), ("晚上", false), ("夜饭", false)
    ]

    /// Which day and which meal a sentence named, and the words it used to do it —
    /// kept so they can be struck out before the dish is looked for.
    static func slot(in sentence: [String]) -> SlotWords {
        var found = SlotWords(offset: nil, weekday: nil, breakfast: nil, spans: [])
        let days = dayPhrases.map { (atomize($0.phrase), $0) }.sorted { $0.0.count > $1.0.count }
        for (phrase, entry) in days where !phrase.isEmpty {
            guard index(of: phrase, in: sentence) != nil else { continue }
            found.offset = entry.offset; found.weekday = entry.weekday
            found.breakfast = entry.breakfast; found.spans.append(phrase)
            break
        }
        let meals = mealPhrases.map { (atomize($0.phrase), $0.breakfast) }.sorted { $0.0.count > $1.0.count }
        for (phrase, breakfast) in meals where !phrase.isEmpty {
            guard index(of: phrase, in: sentence) != nil else { continue }
            found.breakfast = breakfast; found.spans.append(phrase)
            break
        }
        return found
    }

    static let weekdayEN = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let weekdayZH = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    // MARK: The dish being asked for

    /// Where the dish starts: everything said after "to", "换成" and the like.
    static let dishLeadIns: [[String]] = ["换一个", "换成", "改成", "换为", "改为", "换到", "换掉",
                                          "想吃", "改吃", "换", "to", "into", "for", "with"]
        .map(atomize).sorted { $0.count > $1.count }

    static let stopWords: Set<String> = [
        "a", "an", "the", "and", "with", "of", "our", "my", "please", "some", "s",
        "let", "want", "wants", "make", "have", "put", "on", "in", "it", "to", "for",
        "i", "we", "you", "me", "us", "they", "them", "do", "don", "not", "t", "ve",
        "re", "ll", "d", "m", "is", "are", "be", "can", "could", "would", "will",
        "just", "that", "this", "something", "else", "eat", "eating", "tonight",
        "的", "了", "吧", "把", "我", "们", "想", "要", "吃", "个", "一", "下", "再", "来", "给"
    ]

    /// The words that name the dish, with the scaffolding taken out.
    static func dishQuery(in sentence: [String]) -> [String] {
        var tail = sentence
        for phrase in dishLeadIns {
            var search = 0
            var last: Int?
            while let at = index(of: phrase, in: sentence, from: search) { last = at + phrase.count; search = at + 1 }
            if let last, last <= sentence.count, last > 0 { tail = Array(sentence[last...]); break }
        }
        var cleaned = tail
        for span in slot(in: cleaned).spans {
            while let at = index(of: span, in: cleaned) { cleaned.removeSubrange(at..<(at + span.count)) }
        }
        for entry in markers {
            let phrase = atomize(entry.phrase)
            while let at = index(of: phrase, in: cleaned), !phrase.isEmpty { cleaned.removeSubrange(at..<(at + phrase.count)) }
        }
        return cleaned.filter { !stopWords.contains($0) }
    }

    static func stem(_ word: String) -> String {
        if word.count >= 5, word.hasSuffix("es") { return String(word.dropLast(2)) }
        if word.count >= 4, word.hasSuffix("s") { return String(word.dropLast()) }
        return word
    }

    static func bigrams(_ characters: [String]) -> Set<String> {
        guard characters.count > 1 else { return Set(characters) }
        return Set((0..<(characters.count - 1)).map { characters[$0] + characters[$0 + 1] })
    }

    /// How much of what was said the name accounts for, and how much of the name that
    /// leaves over. Coverage carries most of the weight — "咖喱" really does name the
    /// curry — while the overlap of the whole name keeps a two-word query from
    /// settling on the shortest title that happens to contain one of them.
    static func overlap(_ query: Set<String>, _ name: Set<String>) -> Double {
        guard !query.isEmpty, !name.isEmpty else { return 0 }
        let shared = Double(query.intersection(name).count)
        return 0.7 * (shared / Double(query.count))
             + 0.3 * (2 * shared / Double(query.count + name.count))
    }

    /// How well a dish's name answers what was said, in whichever language it was said.
    ///
    /// English compares words. Chinese compares both single characters and the pairs
    /// they form: 牛肉面 shares no pair with 牛肉圆白菜炒面, and every one of its
    /// characters, which is how a family's shorthand for a dish actually works.
    static func similarity(query: [String], name: [String]) -> Double {
        guard !query.isEmpty, !name.isEmpty else { return 0 }
        var best = 0.0
        let queryWords = Set(query.filter { $0.allSatisfy(\.isASCII) }.map(stem)).subtracting(stopWords)
        let nameWords = Set(name.filter { $0.allSatisfy(\.isASCII) }.map(stem)).subtracting(stopWords)
        best = max(best, overlap(queryWords, nameWords))
        let queryHan = query.filter { !($0.first?.isASCII ?? true) }
        let nameHan = name.filter { !($0.first?.isASCII ?? true) }
        // One character does not name a dish — 鱼 is in half the fish recipes — so it
        // is left to be a question rather than turned into a match.
        if queryHan.count >= 2, nameHan.count >= 2 {
            best = max(best, (overlap(Set(queryHan), Set(nameHan))
                              + overlap(bigrams(queryHan), bigrams(nameHan))) / 2)
        }
        return best
    }

    /// Good enough to act on, and far enough ahead of the runner-up to be the only
    /// sensible reading. Below the first, the app says it did not catch the dish;
    /// between the two, it offers the choices instead of picking one.
    static let dishThreshold = 0.40
    static let dishMargin = 0.10

    static func rankDishes(_ query: [String], breakfast: Bool?) -> [(id: String, score: Double)] {
        Catalog.recipes
            .filter { breakfast == nil || $0.breakfast == breakfast }
            .map { recipe -> (id: String, score: Double) in
                let en = similarity(query: query, name: atomize(recipe.en))
                let zh = similarity(query: query, name: atomize(recipe.zh))
                return (recipe.id, max(en, zh))
            }
            .filter { $0.score >= dishThreshold }
            .sorted { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }
    }

    /// Example sentences, shown where the family might not know what to say.
    public static let examples: [(en: String, zh: String)] = [
        ("We already have carrots at home", "家里已经有胡萝卜了"),
        ("I have 500 g of chicken in the fridge", "冰箱里还有500克鸡肉"),
        ("We're out of milk", "牛奶没有了"),
        ("I bought the eggs", "鸡蛋买好了"),
        ("Change tomorrow's dinner to beef noodles", "把明天的晚餐换成牛肉面"),
        ("Swap tonight's dinner", "今晚的晚餐换一个")
    ]
}

// MARK: - Binding a sentence to this kitchen

public extension FamilyState {

    /// Reads one sentence against this kitchen as it stands, and answers with
    /// something to confirm, a question, or a plain admission that it did not follow.
    ///
    /// Nothing here changes anything. `perform` does that, once a person has read
    /// what was understood and tapped.
    func interpret(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> KitchenAnswer {
        let sentence = KitchenTalk.atomize(text)
        guard !sentence.isEmpty else { return KitchenTalk.help }
        let mood = KitchenTalk.mood(in: sentence)
        let slot = KitchenTalk.slot(in: sentence)
        let namedADay = slot.offset != nil || slot.weekday != nil || slot.breakfast != nil
        let query = KitchenTalk.dishQuery(in: sentence)

        let wantsSwap = mood == .swap
            || (mood == nil && namedADay && !KitchenTalk.rankDishes(query, breakfast: slot.breakfast).isEmpty)
        if wantsSwap { return swapAnswer(query: query, slot: slot, now: now, calendar: calendar) }

        guard let mood else {
            if !KitchenTalk.ingredients(in: sentence).isEmpty {
                return .unsure(
                    en: "I caught the food but not what to do with it. Say whether you already have it, have run out, or have bought it.",
                    zh: "我听出了食材，但不知道要做什么。请说明是家里已经有、已经用完，还是已经买了。")
            }
            return KitchenTalk.help
        }
        return shoppingAnswer(mood: mood, sentence: sentence)
    }

    /// How usable one reading is: something to do beats something to ask, and both
    /// beat a shrug.
    func usefulness(of text: String, now: Date = Date()) -> Int {
        switch interpret(text, now: now) {
        case .command: return 2
        case .chooseDish: return 1
        case .unsure: return 0
        }
    }

    /// Picks between the English and the Mandarin reading of the same breath.
    ///
    /// The better reading is the one this kitchen can act on — not the one the phone
    /// was more sure of, because a recogniser listening to the wrong language is
    /// often very sure indeed. Confidence only settles a tie, and the reading that
    /// lost is still shown to the family, so a sentence heard by the wrong ear costs
    /// one tap rather than a repeat.
    func bestReading(among readings: [SpokenReading], now: Date = Date()) -> SpokenReading? {
        var best: (reading: SpokenReading, rank: Int)?
        for reading in readings where !reading.isEmpty {
            let rank = usefulness(of: reading.text, now: now)
            guard let current = best else { best = (reading, rank); continue }
            if rank > current.rank || (rank == current.rank && reading.confidence > current.reading.confidence) {
                best = (reading, rank)
            }
        }
        return best?.reading
    }

    /// The command for a dish the family picked from a list of possibilities.
    func swapCommand(meal id: UUID, to recipeID: String) -> KitchenAnswer {
        guard let meal = meals.first(where: { $0.id == id }), !meal.cooked else {
            return .unsure(en: "That meal is no longer on the plan.", zh: "这一餐已经不在计划里了。")
        }
        guard let recipe = Catalog.recipe(recipeID) else {
            return .unsure(en: "That dish is not in the catalogue.", zh: "菜品库里没有这道菜。")
        }
        guard recipe.breakfast == meal.breakfast else {
            return .unsure(
                en: "\(recipe.en) is a \(recipe.breakfast ? "breakfast" : "dinner") — it cannot take a \(meal.breakfast ? "breakfast" : "dinner") place.",
                zh: "\(recipe.zh) 是\(recipe.breakfast ? "早餐" : "晚餐")，不能放在\(meal.breakfast ? "早餐" : "晚餐")的位置。")
        }
        let (en, zh) = slotLabel(meal)
        var notes: [String] = []
        let conflicts = recipe.conflicts(with: excludedAllergens)
        if !conflicts.isEmpty {
            notes.append("Contains \(conflicts.map(\.name).sorted().joined(separator: ", ")) — an allergen this household avoids. 含家庭需回避的过敏原。")
        }
        if recipe.isSpicy { notes.append("This is a spicy dish. 这是辣味菜。") }
        // Asking for it by name is allowed to repeat the week; it is just said out loud.
        if meals.contains(where: { $0.id != id && $0.recipe == recipeID }) {
            notes.append("\(recipe.en) is already on this week's menu on another day. 本周另有一天已经安排了这道菜。")
        }
        if let days = daysSinceLastEaten(recipe.id, asOf: meal.date), days <= 14 {
            notes.append("Eaten \(days) day\(days == 1 ? "" : "s") ago. \(days) 天前刚吃过。")
        }
        let step = KitchenStep(action: .swap(meal: id, to: recipeID),
                               en: "Change \(en) to \(recipe.en). Votes on that meal are cleared and it needs confirming again.",
                               zh: "把\(zh)换成\(recipe.zh)。该餐的投票会清空，需要重新确认。")
        return .command(KitchenCommand(steps: [step], notes: notes))
    }

    /// Carries out what the family confirmed.
    mutating func perform(_ command: KitchenCommand) {
        for step in command.steps { perform(step.action) }
    }

    mutating func perform(_ action: KitchenAction) {
        switch action {
        case .haveAtHome(let ingredient, let quantity):
            guard quantity.isFinite, quantity > 0 else { return }
            // Recorded with no place, exactly as typing it in by hand would: a sentence
            // cannot say which shelf, and the app does not invent one.
            confirmStock(Stock(ingredient: ingredient, quantity: quantity, confirmed: true, location: nil))
        case .ranOut(let ingredient):
            stock.removeAll { $0.ingredient == ingredient && $0.confirmed }
        case .bought(let ingredient):
            buy(ingredient)
        case .putBack(let ingredient):
            unbuy(ingredient)
        case .swap(let meal, let recipe):
            replace(meal, with: recipe)
        }
    }

    // MARK: Swapping a dish

    private func swapAnswer(query: [String], slot: KitchenTalk.SlotWords,
                            now: Date, calendar: Calendar) -> KitchenAnswer {
        guard isPlanned else {
            return .unsure(en: "There is no menu yet. Plan a week first, then a dish can be swapped.",
                           zh: "还没有菜单。先排一周的饭，再换菜。")
        }
        var ranked = KitchenTalk.rankDishes(query, breakfast: slot.breakfast)
        // When nobody said breakfast or dinner, the dish itself says which it is.
        var kind = slot.breakfast
        if kind == nil, let top = ranked.first, let recipe = Catalog.recipe(top.id) { kind = recipe.breakfast }
        if slot.breakfast != nil, ranked.isEmpty {
            let anywhere = KitchenTalk.rankDishes(query, breakfast: nil)
            if let top = anywhere.first, let recipe = Catalog.recipe(top.id) {
                return .unsure(
                    en: "\(recipe.en) is a \(recipe.breakfast ? "breakfast" : "dinner") — it cannot go on a \(slot.breakfast! ? "breakfast" : "dinner").",
                    zh: "\(recipe.zh) 是\(recipe.breakfast ? "早餐" : "晚餐")，不能安排到\(slot.breakfast! ? "早餐" : "晚餐")。")
            }
        }
        let breakfast = kind ?? false
        guard let meal = meal(on: slot, breakfast: breakfast, now: now, calendar: calendar) else {
            let day = slot.weekday.map { KitchenTalk.weekdayEN[$0] } ?? (slot.offset == 0 ? "today" : slot.offset == 1 ? "tomorrow" : "that day")
            let dayZH = slot.weekday.map { KitchenTalk.weekdayZH[$0] } ?? (slot.offset == 0 ? "今天" : slot.offset == 1 ? "明天" : "那天")
            return .unsure(en: "There is no \(breakfast ? "breakfast" : "dinner") planned for \(day) that is still to cook.",
                           zh: "\(dayZH)没有还没做的\(breakfast ? "早餐" : "晚餐")。")
        }
        let (en, zh) = slotLabel(meal)
        guard !ranked.isEmpty else {
            // A dish was named and not recognised. Guessing here would put a dish on
            // the table that nobody asked for, so the app says what it heard instead.
            guard query.isEmpty else {
                return .unsure(
                    en: "I did not catch which dish you meant for \(en). Say the name as it appears on the menu, or just say “swap \(en)” and I will suggest one.",
                    zh: "没听清\(zh)要换成哪道菜。请按菜单上的名字说，或者直接说“\(zh)换一个”，我来推荐。")
            }
            // Nothing named: offer the alternative the swap screen would put first.
            guard let suggestion = swapOptions(for: meal, limit: 1).first else {
                return .unsure(en: "No alternative fits \(en) without repeating the week.",
                               zh: "\(zh)暂时没有不重复的备选菜。")
            }
            return swapCommand(meal: meal.id, to: suggestion.id)
        }
        ranked = ranked.filter { Catalog.recipe($0.id)?.breakfast == breakfast }
        guard let best = ranked.first else {
            return .unsure(en: "I did not catch which dish you meant for \(en).", zh: "没听清\(zh)要换成哪道菜。")
        }
        if best.id == meal.recipe {
            return .unsure(en: "\(en) is already \(Catalog.recipe(best.id)?.en ?? best.id).",
                           zh: "\(zh)已经是\(Catalog.recipe(best.id)?.zh ?? best.id)了。")
        }
        let second = ranked.dropFirst().first?.score ?? 0
        if best.score - second < KitchenTalk.dishMargin {
            return .chooseDish(meal: meal.id, slotEN: en, slotZH: zh,
                               options: Array(ranked.prefix(4).map(\.id)))
        }
        return swapCommand(meal: meal.id, to: best.id)
    }

    /// The meal a sentence pointed at: the named day when there was one, otherwise
    /// the next one of that kind still to cook.
    private func meal(on slot: KitchenTalk.SlotWords, breakfast: Bool,
                      now: Date, calendar: Calendar) -> Meal? {
        let today = calendar.startOfDay(for: now)
        let candidates = meals.filter { !$0.cooked && $0.breakfast == breakfast }
            .sorted { $0.date < $1.date }
        // A named day is a date: "tomorrow" is tomorrow, and nothing else will do.
        if let offset = slot.offset {
            guard let target = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return candidates.first { calendar.isDate($0.date, inSameDayAs: target) }
        }
        // A named weekday is whichever of those the menu actually covers. A family
        // planning next week says "Wednesday" and means the Wednesday on the plan,
        // which may well be eight days away.
        if let weekday = slot.weekday {
            func isNamed(_ meal: Meal) -> Bool { calendar.component(.weekday, from: meal.date) == weekday }
            return candidates.first { $0.date >= today && isNamed($0) } ?? candidates.first(where: isNamed)
        }
        return candidates.first { $0.date >= today } ?? candidates.first
    }

    private func slotLabel(_ meal: Meal) -> (en: String, zh: String) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: meal.date)
        let kindEN = meal.breakfast ? "breakfast" : "dinner"
        let kindZH = meal.breakfast ? "早餐" : "晚餐"
        if calendar.isDateInToday(meal.date) { return ("today's \(kindEN)", "今天的\(kindZH)") }
        if calendar.isDateInTomorrow(meal.date) { return ("tomorrow's \(kindEN)", "明天的\(kindZH)") }
        return ("\(KitchenTalk.weekdayEN[weekday]) \(kindEN)", "\(KitchenTalk.weekdayZH[weekday])\(kindZH)")
    }

    // MARK: Changing the shopping list

    private func shoppingAnswer(mood: KitchenTalk.Mood, sentence: [String]) -> KitchenAnswer {
        let foods = Array(KitchenTalk.ingredients(in: sentence).prefix(6))
        guard !foods.isEmpty else {
            return .unsure(en: "I did not catch which food you meant. Name it and I will look it up.",
                           zh: "没听清是哪种食材。说出名字，我来查。")
        }
        var steps: [KitchenStep] = []
        var notes: [String] = []
        let lines = shopping()
        for food in foods {
            let item = Catalog.ingredient(food)
            let line = lines.first { $0.ingredient == food }
            switch mood {
            case .haveAtHome:
                let reading = KitchenTalk.amount(for: food, in: sentence, allowUnitAlone: foods.count == 1)
                var quantity = suggestedScanQuantity(food, at: nil)
                switch reading {
                case .amount(let said) where said > 0:
                    quantity = said
                case .mismatch:
                    notes.append("\(item.en) · \(item.zh) is kept in \(item.unit), so that number was not used — what the week is short of is recorded instead. 该食材以 \(item.unit) 计量，所说数量未采用，改用本周所缺的量。")
                case .none, .amount:
                    break
                }
                guard quantity > 0 else {
                    notes.append("\(item.en) · \(item.zh): this week's list is not asking for it. Say an amount to record it anyway. 本周清单没有这一项；说出数量即可照样记录。")
                    continue
                }
                if (line?.shortage ?? 0) <= 0 {
                    notes.append("\(item.en) · \(item.zh): this week's list was not asking for it, so this only records what is at home. 本周清单本来就没有这一项，这里只是记录家中库存。")
                }
                let amount = quantityText(quantity, unit: item.unit)
                steps.append(KitchenStep(
                    action: .haveAtHome(ingredient: food, quantity: quantity),
                    en: "Record \(amount) of \(item.en) as already at home, place unconfirmed."
                        + ((line?.shortage ?? 0) > 0 ? " It is ticked off the shopping list and moves down to Nothing to buy." : ""),
                    zh: "记录家里已有 \(amount) \(item.zh)（位置待确认）。"
                        + ((line?.shortage ?? 0) > 0 ? "采购清单上这一项会打勾，并移到底部的“已有，无需购买”。" : "")))
            case .ranOut:
                let held = stock.filter { $0.ingredient == food && $0.confirmed }
                guard !held.isEmpty else {
                    notes.append("\(item.en) · \(item.zh): nothing is recorded at home, so there is nothing to clear. 家里没有记录，无需清除。")
                    continue
                }
                let total = quantityText(held.reduce(0) { $0 + $1.quantity }, unit: item.unit)
                let places = held.map { locationLabel($0.location) }.joined(separator: ", ")
                steps.append(KitchenStep(
                    action: .ranOut(ingredient: food),
                    en: "Clear the \(total) of \(item.en) recorded at home (\(places)). It goes back on the shopping list.",
                    zh: "清除家中记录的 \(total) \(item.zh)（\(places)），该项会回到采购清单。"))
            case .bought:
                guard let line, line.shortage > 0 else {
                    notes.append("\(item.en) · \(item.zh): the list is not asking for it, so there is nothing to tick off. 清单没有这一项，无需打勾。")
                    continue
                }
                let amount = quantityText(line.shortage, unit: item.unit)
                steps.append(KitchenStep(
                    action: .bought(ingredient: food),
                    en: "Tick \(amount) of \(item.en) off the list as bought. It moves down to Nothing to buy, and Put away will ask where it went.",
                    zh: "把 \(amount) \(item.zh) 标记为已买，移到底部的“已有，无需购买”；收纳步骤会问放到哪里。"))
            case .putBack:
                guard canUnbuy(food) else {
                    notes.append("\(item.en) · \(item.zh): nothing ticked off here can still be undone. Correct it in the Kitchen instead. 这一项已无法撤销，请在 Kitchen 中更正。")
                    continue
                }
                steps.append(KitchenStep(
                    action: .putBack(ingredient: food),
                    en: "Put \(item.en) back on the shopping list.",
                    zh: "把\(item.zh)放回采购清单。"))
            case .swap:
                continue
            }
        }
        guard !steps.isEmpty else {
            return .unsure(en: "Nothing there needs changing.", zh: "这句话没有需要改动的地方。", notes: notes)
        }
        return .command(KitchenCommand(steps: steps, notes: notes))
    }
}

extension KitchenTalk {
    static let help = KitchenAnswer.unsure(
        en: "I did not follow that. I can record what you already have at home, tick something off as bought, put it back on the list, or change a dish on the menu.",
        zh: "这句话我没听懂。我可以记录家里已有的食材、把某项标记为已买、把它放回清单，或更换菜单上的某道菜。")
}
