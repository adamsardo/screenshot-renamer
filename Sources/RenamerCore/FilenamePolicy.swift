import Foundation

public struct CaptureDate: Codable, Sendable, Equatable {
    public let value: String
    public let source: String
    public init(value: String, source: String) { self.value = value; self.source = source }

    public static func resolve(filename: String, metadata: String? = nil, created: Date? = nil) -> CaptureDate? {
        if filename.hasPrefix("CleanShot ") || filename.hasPrefix("Screenshot ") || filename.hasPrefix("Screen Shot ") {
            if let value = extract(filename) { return .init(value: value, source: "Capture filename") }
        }
        if let range = filename.range(of: #" — \d{4}-\d{2}-\d{2}( \(\d+\))?\.[A-Za-z0-9]+$"#, options: .regularExpression),
           let value = extract(String(filename[range])) { return .init(value: value, source: "Previously named capture date") }
        if let metadata, let value = extract(metadata.replacingOccurrences(of: ":", with: "-")) {
            return .init(value: value, source: "Image capture metadata")
        }
        if let created {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = "yyyy-MM-dd"
            return .init(value: formatter.string(from: created), source: "File creation date (fallback)")
        }
        return nil
    }

    private static func extract(_ text: String) -> String? {
        guard let range = text.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) else { return nil }
        let value = String(text[range])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return value
    }
}

public enum FilenamePolicy {
    public static func key(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    public static func cleanTitle(_ title: String) -> String {
        let parts = title.components(separatedBy: CharacterSet.controlCharacters.union(.init(charactersIn: "/\\:")))
        return parts.joined(separator: " ").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .trimmingCharacters(in: .init(charactersIn: ". \"“”")).precomposedStringWithCanonicalMapping
    }

    public static func compose(title: String, date: CaptureDate, extension ext: String, suffix: Int? = nil) throws -> String {
        var title = cleanTitle(title)
        guard !title.isEmpty else { throw RenameError.invalidName("Enter a description.") }
        guard !ext.isEmpty, ext.allSatisfy({ $0.isLetter || $0.isNumber }) else { throw RenameError.invalidName("Unsupported extension.") }
        let ending = " — \(date.value)" + (suffix.map { " (\($0))" } ?? "") + ".\(ext)"
        while (title + ending).utf8.count > 240, !title.isEmpty { title.removeLast() }
        guard !title.isEmpty else { throw RenameError.invalidName("The filename is too long.") }
        return title.trimmingCharacters(in: .whitespaces) + ending
    }

    public static func propose(title: String, date: CaptureDate, extension ext: String, occupied: Set<String>) throws -> String {
        var index: Int? = nil
        while true {
            let name = try compose(title: title, date: date, extension: ext, suffix: index)
            if !occupied.contains(key(name)) { return name }
            index = (index ?? 1) + 1
        }
    }

    public static func validate(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", !name.hasPrefix("."), name.utf8.count <= 255,
              name.rangeOfCharacter(from: .controlCharacters.union(.init(charactersIn: "/\\:"))) == nil else {
            throw RenameError.invalidName("Invalid filename. Use a visible name without separators or control characters.")
        }
    }
}

public enum RenameError: LocalizedError, Sendable {
    case invalidName(String), changed, occupied, unsupported, journal(String)
    public var errorDescription: String? {
        switch self {
        case .invalidName(let reason): reason
        case .changed: "The file has moved or changed. Add it again before renaming."
        case .occupied: "The destination name is occupied. Review the name and try again."
        case .unsupported: "Only regular files in the same folder can be renamed."
        case .journal(let reason): "History could not be saved. No further changes were attempted. \(reason)"
        }
    }
}
