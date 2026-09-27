import Foundation

enum LibraryDisk {
    static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Shiyin", isDirectory: true)
    }()

    static let documentURL = supportDirectory.appendingPathComponent("library.json")

    static var defaultAudioDirectory: URL {
        FileManager.default.urls(for: .musicDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("拾音", isDirectory: true)
    }

    static func load() -> LibraryDocument {
        guard let data = try? Data(contentsOf: documentURL),
              let document = try? JSONDecoder().decode(LibraryDocument.self, from: data)
        else { return LibraryDocument() }
        return document
    }

    static func save(_ document: LibraryDocument) throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(document)
        try data.write(to: documentURL, options: .atomic)
    }
}
