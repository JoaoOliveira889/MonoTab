import CoreGraphics
import Foundation

struct WindowInfo: Identifiable, Hashable, Sendable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let bounds: CGRect
    let isMinimized: Bool
    let displayIndex: Int?

    private static let appNameWeight = 20

    private let appNameBytes: ContiguousArray<UInt8>
    private let titleBytes: ContiguousArray<UInt8>

    init(
        id: CGWindowID,
        pid: pid_t,
        appName: String,
        title: String,
        bounds: CGRect,
        isMinimized: Bool = false,
        displayIndex: Int? = nil
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.title = title
        self.bounds = bounds
        self.isMinimized = isMinimized
        self.displayIndex = displayIndex
        self.appNameBytes = ContiguousArray(appName.lowercased().utf8)
        self.titleBytes = ContiguousArray(title.lowercased().utf8)
    }

    var displayTitle: String {
        title.allSatisfy(\.isWhitespace) ? appName : title
    }

    func matchScore(normalizedQuery query: [UInt8]) -> Int? {
        matchScore(normalizedQuery: ContiguousArray(query))
    }

    func matchScore(normalizedQuery query: ContiguousArray<UInt8>) -> Int? {
        guard !query.isEmpty else { return 0 }

        let appScore = FuzzyMatch.score(query: query, candidate: appNameBytes).map { $0 + Self.appNameWeight }
        let titleScore = FuzzyMatch.score(query: query, candidate: titleBytes)

        switch (appScore, titleScore) {
        case let (app?, title?): return max(app, title)
        case let (app?, nil): return app
        case let (nil, title?): return title
        case (nil, nil): return nil
        }
    }

    func matches(query: String) -> Bool {
        matchScore(normalizedQuery: WindowInfo.normalize(query)) != nil
    }

    static func normalize(_ query: String) -> [UInt8] {
        Array(query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8)
    }

    static func normalizeBytes(_ query: String) -> ContiguousArray<UInt8> {
        ContiguousArray(query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
