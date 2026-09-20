import Foundation

/// One thing a photo appears to show, matched to something this kitchen knows about.
///
/// A finding is a suggestion and nothing more. Nothing it says reaches the shopping
/// list until someone looks at it and confirms — a misread must never be able to
/// send a family home without the eggs.
public struct ScanFinding: Identifiable, Sendable, Hashable {
    public var id: String { ingredient }
    public var ingredient: String
    /// The words the recogniser actually used, kept so the family can judge it
    /// instead of taking the app's word for it.
    public var label: String
    /// 0–1, as reported by the recogniser.
    public var confidence: Double
    /// True when this week's shopping list is currently asking for this.
    public var onList: Bool

    public init(ingredient: String, label: String, confidence: Double, onList: Bool) {
        self.ingredient = ingredient; self.label = label
        self.confidence = confidence; self.onList = onList
    }
    /// Findings above this are ticked for you; below it you decide. Photo recognisers
    /// are confident about a banana and hesitant about a bag of frozen peas.
    public static let trustedConfidence = 0.3
    public var confidenceText: String {
        confidence >= 0.6 ? "Clear" : confidence >= ScanFinding.trustedConfidence ? "Likely" : "Possible"
    }
}

/// What the family confirmed after looking at the findings.
public struct ScanConfirmation: Sendable {
    public var ingredient: String
    /// The total now present at this place, not an amount to add.
    public var quantity: Double
    public var location: UUID?
    public init(ingredient: String, quantity: Double, location: UUID?) {
        self.ingredient = ingredient; self.quantity = quantity; self.location = location
    }
}

/// Turns the words an image recogniser produces into ingredients this app stocks.
///
/// The vocabulary of an on-device recogniser is general — "banana", "bell pepper",
/// "carton" — so the mapping is written out by hand rather than guessed from the
/// ingredient names, which would make "whole wheat bread" answer to "wheat" and
/// quietly match the noodles.
public enum PantryMatcher {
    /// Labels too general to mean anything in a kitchen. Matching these would tick
    /// half the list off a photo of a shelf.
    static let ignored: Set<String> = [
        "food", "foods", "vegetable", "vegetables", "fruit", "fruits", "meat", "produce",
        "dish", "meal", "plate", "bowl", "cup", "container", "bottle", "jar", "can", "tin",
        "box", "carton", "package", "packaging", "bag", "refrigerator", "fridge", "freezer",
        "kitchen", "shelf", "pantry", "grocery", "groceries", "ingredient", "drink",
        "beverage", "snack", "dessert", "sauce", "spice", "seasoning", "condiment",
        "grain", "cereal", "legume", "bean", "beans", "nut", "nuts", "seed", "seeds",
        "seafood", "fish", "poultry", "dairy", "cheese board", "black pepper", "pepper mill"
    ]

    /// Words a recogniser is likely to use for each ingredient, in both languages.
    /// Longer phrases win over shorter ones, so "chili bean paste" never lands on
    /// "bean" and "peanut butter" never lands on "peanut".
    static let synonyms: [String: [String]] = [
        "chicken": ["chicken", "chicken breast", "chicken fillet", "鸡肉", "鸡胸"],
        "beef": ["beef", "steak", "sirloin", "牛肉", "牛排", "牛里脊"],
        "salmon": ["salmon", "salmon fillet", "三文鱼", "鲑鱼"],
        "tofu": ["tofu", "bean curd", "豆腐"],
        "egg": ["egg", "eggs", "egg carton", "鸡蛋"],
        "milk": ["milk", "milk carton", "milk jug", "牛奶"],
        "yogurt": ["yogurt", "yoghurt", "酸奶"],
        "broccoli": ["broccoli", "西兰花"],
        "carrot": ["carrot", "carrots", "胡萝卜"],
        "potato": ["potato", "potatoes", "土豆", "马铃薯"],
        "spinach": ["spinach", "菠菜"],
        "bokchoy": ["bok choy", "pak choi", "小白菜", "青菜"],
        "peas": ["peas", "green peas", "frozen peas", "豌豆"],
        "banana": ["banana", "bananas", "香蕉"],
        "berries": ["blueberry", "blueberries", "蓝莓"],
        "orange": ["orange", "oranges", "mandarin", "tangerine", "橙子", "橘子"],
        "lemon": ["lemon", "lemons", "柠檬"],
        "rice": ["rice", "white rice", "大米", "米饭"],
        "spaghetti": ["spaghetti", "意面", "意大利面"],
        "penne": ["penne", "macaroni", "通心粉"],
        "noodles": ["wheat noodles", "instant noodles", "挂面", "面条"],
        "oats": ["oats", "oatmeal", "rolled oats", "燕麦"],
        "bread": ["bread", "loaf", "toast", "面包"],
        "tomato": ["canned tomatoes", "crushed tomatoes", "tomato sauce", "tomato paste", "番茄罐头"],
        "soy": ["soy sauce", "生抽", "酱油"],
        "oil": ["olive oil", "cooking oil", "vegetable oil", "橄榄油", "食用油"],
        "sesame": ["sesame", "sesame seeds", "芝麻"],
        "curry": ["curry powder", "curry", "咖喱"],
        "salt": ["salt", "食盐"],
        "ginger": ["ginger", "ginger root", "生姜", "鲜姜"],
        "garlic": ["garlic", "大蒜"],
        "mushroom": ["mushroom", "mushrooms", "button mushroom", "蘑菇"],
        "pineapple": ["pineapple", "菠萝"],
        "pepper": ["bell pepper", "red pepper", "sweet pepper", "capsicum", "甜椒", "彩椒"],
        "maple": ["maple syrup", "syrup", "枫糖浆"],
        "celery": ["celery", "芹菜"],
        "pork": ["pork", "pork loin", "pork tenderloin", "猪肉", "猪里脊"],
        "cabbage": ["cabbage", "圆白菜", "卷心菜", "包菜"],
        "zucchini": ["zucchini", "courgette", "西葫芦"],
        "shrimp": ["shrimp", "prawn", "prawns", "虾仁", "大虾"],
        "corn": ["corn", "sweet corn", "corn kernels", "玉米"],
        "cod": ["cod", "white fish", "fish fillet", "鳕鱼"],
        "chickpea": ["chickpeas", "chickpea", "garbanzo", "鹰嘴豆"],
        "udon": ["udon", "udon noodles", "乌冬面"],
        "vermicelli": ["vermicelli", "rice vermicelli", "rice noodles", "米粉"],
        "soba": ["soba", "buckwheat noodles", "荞麦面"],
        "orzo": ["orzo", "米粒面"],
        "tuna": ["tuna", "canned tuna", "金枪鱼"],
        "turkey": ["turkey", "ground turkey", "火鸡"],
        "blackbean": ["black beans", "black bean", "黑豆"],
        "tortilla": ["tortilla", "tortillas", "wrap", "卷饼"],
        "freshtomato": ["tomato", "tomatoes", "cherry tomato", "番茄", "西红柿"],
        "lettuce": ["lettuce", "romaine", "salad greens", "生菜"],
        "cucumber": ["cucumber", "黄瓜"],
        "cheddar": ["cheddar", "shredded cheese", "cheese", "奶酪", "芝士"],
        "pita": ["pita", "pita bread", "皮塔饼"],
        "couscous": ["couscous", "库斯库斯"],
        "lentil": ["lentils", "lentil", "扁豆"],
        "apple": ["apple", "apples", "苹果"],
        "cinnamon": ["cinnamon", "肉桂"],
        "pumpkin": ["pumpkin", "pumpkin puree", "canned pumpkin", "南瓜"],
        "strawberry": ["strawberry", "strawberries", "草莓"],
        "pear": ["pear", "pears", "梨"],
        "peach": ["peach", "peaches", "nectarine", "桃子"],
        "avocado": ["avocado", "avocados", "牛油果", "鳄梨"],
        "peanutbutter": ["peanut butter", "花生酱"],
        "cottage": ["cottage cheese", "茅屋奶酪"],
        "englishmuffin": ["english muffin", "muffin", "英式松饼"],
        "freshchili": ["green chili", "chili pepper", "jalapeno", "serrano", "青辣椒"],
        "choppedchili": ["chopped chili", "chili sauce", "剁椒"],
        "douban": ["chili bean paste", "doubanjiang", "豆瓣酱"],
        "peppercorn": ["sichuan pepper", "peppercorn", "peppercorns", "花椒"],
        "driedchili": ["dried chili", "dried chilies", "dried chillies", "干辣椒"],
        "vinegar": ["vinegar", "black vinegar", "陈醋"],
        "sugar": ["sugar", "白糖"],
        "cornstarch": ["cornstarch", "corn starch", "玉米淀粉"],
        "peanut": ["peanut", "peanuts", "花生"],
        "scallion": ["scallion", "scallions", "green onion", "spring onion", "小葱"],
        "groundpork": ["ground pork", "minced pork", "猪肉末"]
    ]

    /// Every phrase that can be looked up, longest first so the most specific match
    /// is the one that counts.
    static let phrases: [(phrase: String, ingredient: String)] = {
        var all: [(String, String)] = []
        for (ingredient, words) in synonyms {
            for word in words where !ignored.contains(word) { all.append((word, ingredient)) }
        }
        return all.sorted { $0.0.count > $1.0.count }
    }()

    /// Reduces a recogniser's label to plain lowercase words.
    static func normalize(_ label: String) -> String {
        let simplified = label.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let kept = simplified.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) || scalar == " " ? Character(scalar) : " "
        }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// Whether one word in a photo's label is the word being looked for, allowing for
    /// the plural a recogniser is as likely to use as the singular — "green onions"
    /// must find the scallions.
    static func sameWord(_ word: String, _ needle: String) -> Bool {
        word == needle || word == needle + "s" || word == needle + "es"
    }

    /// Whether `phrase` occurs in `label` as whole words. Chinese is matched as plain
    /// text, since it is not written with spaces between words.
    static func contains(_ label: String, phrase: String) -> Bool {
        guard phrase.unicodeScalars.allSatisfy({ $0.isASCII }) else { return label.contains(phrase) }
        let words = label.split(separator: " ").map(String.init)
        let needle = phrase.split(separator: " ").map(String.init)
        guard !needle.isEmpty, words.count >= needle.count else { return false }
        for start in 0...(words.count - needle.count) {
            if zip(words[start..<(start + needle.count)], needle).allSatisfy(sameWord) { return true }
        }
        return false
    }

    /// The ingredient one label refers to, or nil when it refers to nothing this
    /// kitchen stocks — which is most of what a camera sees.
    public static func ingredient(forLabel label: String) -> String? {
        let normalized = normalize(label)
        guard !normalized.isEmpty, !ignored.contains(normalized) else { return nil }
        return phrases.first { contains(normalized, phrase: $0.phrase) }?.ingredient
    }

    /// Collapses a pile of labels from several photos into one finding per
    /// ingredient, keeping the most confident sighting of each.
    ///
    /// `onList` is what makes a general-purpose recogniser useful here: the question
    /// being asked is not "what is in this fridge" but "of the things I was about to
    /// buy, which are already at home", and that is a much smaller question.
    public static func findings(from labels: [(label: String, confidence: Double)],
                                shoppingList: Set<String>,
                                minimumConfidence: Double = 0.05) -> [ScanFinding] {
        var best: [String: ScanFinding] = [:]
        for entry in labels where entry.confidence >= minimumConfidence {
            guard let ingredient = ingredient(forLabel: entry.label) else { continue }
            let finding = ScanFinding(ingredient: ingredient, label: entry.label,
                                      confidence: min(1, max(0, entry.confidence)),
                                      onList: shoppingList.contains(ingredient))
            if let existing = best[ingredient], existing.confidence >= finding.confidence { continue }
            best[ingredient] = finding
        }
        // On the list first, then by how sure the recogniser was.
        return best.values.sorted {
            $0.onList == $1.onList
                ? ($0.confidence == $1.confidence ? $0.ingredient < $1.ingredient : $0.confidence > $1.confidence)
                : $0.onList
        }
    }
}

public extension FamilyState {
    /// The ingredients this week's list is still asking the family to buy.
    var shoppingListIngredients: Set<String> {
        Set(shopping().filter { $0.shortage > 0 }.map(\.ingredient))
    }

    /// How much to record for something spotted in a photo: whatever is already
    /// confirmed in that same place, plus the shortfall the list still shows.
    ///
    /// A photo cannot say how much of something there is, so the app does not
    /// pretend to know. Recording exactly enough closes the line without inventing
    /// food on any other shelf, and the family can correct the number on the spot.
    func suggestedScanQuantity(_ ingredient: String, at location: UUID?) -> Double {
        let here = stock.first { $0.ingredient == ingredient && $0.location == location }?.quantity ?? 0
        let shortage = shopping().first { $0.ingredient == ingredient }?.shortage ?? 0
        return here + shortage
    }

    /// Records what the family confirmed after a photo check. Same rules as typing it
    /// in by hand: an amount at a place, replacing any earlier amount at that place.
    mutating func applyScan(_ confirmations: [ScanConfirmation]) {
        for item in confirmations where item.quantity.isFinite && item.quantity > 0 {
            confirmStock(Stock(ingredient: item.ingredient, quantity: item.quantity,
                               confirmed: true, location: item.location))
        }
    }
}
