import Foundation

/// A versioned JSON file in Application Support, written atomically and readable by this user only.
/// A file that cannot be decoded is moved aside as `<name>.corrupt` and the store starts empty.
public final class JSONFileStore<Item: Codable> {
    struct Envelope: Codable {
        let version: Int
        let items: [Item]
    }

    public let url: URL
    public let version: Int

    public init(url: URL, version: Int = 1) {
        self.url = url
        self.version = version
    }

    public static func applicationSupportURL(fileName: String, fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(AppInfo.name, isDirectory: true).appendingPathComponent(fileName)
    }

    public func load() -> [Item] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let envelope = try? decoder.decode(Envelope.self, from: data), envelope.version == version {
            return envelope.items
        }
        try? FileManager.default.removeItem(at: url.appendingPathExtension("corrupt"))
        try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt"))
        return []
    }

    public func save(_ items: [Item]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(version: version, items: items))
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
