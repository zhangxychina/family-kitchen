import Foundation

/// A recipe read off a web page, before the family has checked it.
///
/// Nothing here is trusted: it is what the page claimed, kept as text, for a person
/// to review and correct before it becomes a dish in their kitchen.
public struct ImportedRecipe: Sendable, Equatable {
    public var name: String
    public var ingredientLines: [String]
    public var steps: [String]
    public var minutes: Int?
    public var yieldText: String?
    public var sourceURL: String
    public init(name: String, ingredientLines: [String], steps: [String],
                minutes: Int? = nil, yieldText: String? = nil, sourceURL: String) {
        self.name = name; self.ingredientLines = ingredientLines; self.steps = steps
        self.minutes = minutes; self.yieldText = yieldText; self.sourceURL = sourceURL
    }
}

public enum ImportError: Error, Equatable {
    case badURL
    case notHTTPS
    case network(String)
    case noRecipeFound
    case emptyRecipe
    public var message: String {
        switch self {
        case .badURL: return "That does not look like a web address."
        case .notHTTPS: return "Only https links can be opened, for safety."
        case .network(let detail): return "Could not reach that page. \(detail)"
        case .noRecipeFound: return "This page does not publish a recipe the app can read. You can still type the dish in by hand."
        case .emptyRecipe: return "That page lists a recipe but no ingredients or steps the app could read."
        }
    }
}

/// Reads a recipe from a web page that publishes schema.org Recipe data, which most
/// recipe sites do. Everything else is left to the family to type in.
public enum RecipeImport {

    /// Fetches a page and reads the recipe out of it.
    ///
    /// This is the only part of the app that uses the network, and it only runs when
    /// someone pastes a link and asks for it.
    public static func fetch(_ address: String, session: URLSession = .shared) async throws -> ImportedRecipe {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), url.host != nil else {
            throw ImportError.badURL
        }
        guard scheme == "https" else { throw ImportError.notHTTPS }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        // Some sites serve a different page to clients that do not look like browsers.
        request.setValue("Mozilla/5.0 (compatible; FamilyKitchen/1.0)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let data: Data
        do {
            let (body, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw ImportError.network("The site answered \(http.statusCode).")
            }
            data = body
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.network(error.localizedDescription)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.noRecipeFound
        }
        return try parse(html: html, sourceURL: url.absoluteString)
    }

    /// Pulls a recipe out of a page's JSON-LD. Kept separate from fetching so it can
    /// be tested without a network.
    public static func parse(html: String, sourceURL: String) throws -> ImportedRecipe {
        var found: [String: Any]?
        for block in jsonLDBlocks(in: html) {
            guard let data = block.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let recipe = findRecipe(in: object) { found = recipe; break }
        }
        guard let recipe = found else { throw ImportError.noRecipeFound }

        let name = string(recipe["name"]) ?? "Imported dish"
        let ingredients = stringList(recipe["recipeIngredient"] ?? recipe["ingredients"])
        let steps = instructions(recipe["recipeInstructions"])
        guard !ingredients.isEmpty || !steps.isEmpty else { throw ImportError.emptyRecipe }

        let minutes = [recipe["totalTime"], recipe["cookTime"], recipe["performTime"]]
            .compactMap { string($0) }.compactMap(durationMinutes).first
        return ImportedRecipe(name: decodeEntities(name),
                              ingredientLines: ingredients.map(decodeEntities),
                              steps: steps.map(decodeEntities),
                              minutes: minutes,
                              yieldText: string(recipe["recipeYield"]).map(decodeEntities),
                              sourceURL: sourceURL)
    }

    // MARK: - Reading the page

    /// The contents of every <script type="application/ld+json"> block.
    static func jsonLDBlocks(in html: String) -> [String] {
        var blocks: [String] = []
        var remainder = Substring(html)
        while let scriptStart = remainder.range(of: "<script", options: .caseInsensitive) {
            remainder = remainder[scriptStart.upperBound...]
            guard let headEnd = remainder.firstIndex(of: ">") else { break }
            let attributes = remainder[..<headEnd].lowercased()
            let body = remainder[remainder.index(after: headEnd)...]
            guard let closing = body.range(of: "</script", options: .caseInsensitive) else { break }
            if attributes.contains("application/ld+json") {
                blocks.append(String(body[..<closing.lowerBound]))
            }
            remainder = body[closing.upperBound...]
        }
        return blocks
    }

    /// Finds the Recipe object inside JSON-LD, which may be a bare object, a list,
    /// or wrapped in an @graph.
    static func findRecipe(in object: Any) -> [String: Any]? {
        if let list = object as? [Any] {
            for element in list { if let recipe = findRecipe(in: element) { return recipe } }
            return nil
        }
        guard let dictionary = object as? [String: Any] else { return nil }
        let types = stringList(dictionary["@type"]).map { $0.lowercased() }
        if types.contains("recipe") { return dictionary }
        if let graph = dictionary["@graph"] { return findRecipe(in: graph) }
        return nil
    }

    static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let number = value as? NSNumber { return number.stringValue }
        if let list = value as? [Any] { return list.compactMap { string($0) }.first }
        return nil
    }

    static func stringList(_ value: Any?) -> [String] {
        if let text = value as? String { return [text.trimmingCharacters(in: .whitespacesAndNewlines)] }
        if let list = value as? [Any] { return list.compactMap { string($0) } }
        return []
    }

    /// Instructions come as plain text, a list of steps, or sections of steps.
    static func instructions(_ value: Any?) -> [String] {
        if let text = value as? String {
            return stripTags(text)
                .components(separatedBy: CharacterSet.newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 2 }
        }
        guard let list = value as? [Any] else { return [] }
        var steps: [String] = []
        for element in list {
            if let text = element as? String {
                let cleaned = stripTags(text).trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { steps.append(cleaned) }
            } else if let step = element as? [String: Any] {
                let types = stringList(step["@type"]).map { $0.lowercased() }
                if types.contains("howtosection"), let inner = step["itemListElement"] {
                    steps.append(contentsOf: instructions(inner))
                } else if let text = string(step["text"]) ?? string(step["name"]) {
                    let cleaned = stripTags(text).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty { steps.append(cleaned) }
                }
            }
        }
        return steps
    }

    /// ISO 8601 durations, as used by `totalTime`: PT1H15M, PT45M, PT2H.
    static func durationMinutes(_ text: String) -> Int? {
        guard text.hasPrefix("P") else { return nil }
        guard let timePart = text.split(separator: "T").last, text.contains("T") else { return nil }
        var minutes = 0
        var number = ""
        for character in timePart {
            if character.isNumber { number.append(character); continue }
            let value = Int(number) ?? 0
            switch character {
            case "H", "h": minutes += value * 60
            case "M", "m": minutes += value
            default: break
            }
            number = ""
        }
        return minutes > 0 ? minutes : nil
    }

    static func stripTags(_ text: String) -> String {
        var result = ""
        var insideTag = false
        for character in text {
            if character == "<" { insideTag = true }
            else if character == ">" { insideTag = false; result.append(" ") }
            else if !insideTag { result.append(character) }
        }
        return decodeEntities(result).replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ text: String) -> String {
        var result = text
        for (entity, character) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
                                    ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&frac12;", "½"),
                                    ("&frac14;", "¼"), ("&frac34;", "¾"), ("&deg;", "°")] {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }

    // MARK: - Matching what was imported to what the kitchen knows

    /// Guesses which of the app's ingredients an imported line refers to.
    ///
    /// It is deliberately conservative: a wrong guess puts the wrong thing on a
    /// shopping list, so anything uncertain is left for the family to decide.
    public static func matchIngredient(_ line: String) -> Ingredient? {
        let text = line.lowercased()
        var best: (ingredient: Ingredient, score: Int)?
        for ingredient in Catalog.ingredients {
            // Match against the ingredient's own words, longest first, so "chicken
            // breast" beats a bare "chicken" and "peanut butter" beats "peanut".
            let words = ingredient.en.lowercased()
                .components(separatedBy: CharacterSet(charactersIn: " ,-()"))
                .filter { $0.count > 2 }
            guard !words.isEmpty else { continue }
            let matched = words.filter { text.contains($0) }
            guard matched.count == words.count || (matched.count >= 1 && words.count == 1) else { continue }
            let score = matched.joined().count
            if score > (best?.score ?? 0) { best = (ingredient, score) }
        }
        return best?.ingredient
    }
}
