import Foundation

enum FuzzyMatch {
    private static let startBonus = 12
    private static let boundaryBonus = 10
    private static let consecutiveBonus = 8
    private static let characterScore = 1
    private static let lengthPenaltyDivisor = 4

    static func score(query: [UInt8], candidate: [UInt8]) -> Int? {
        guard !query.isEmpty else { return 0 }
        guard query.count <= candidate.count else { return nil }

        var total = 0
        var queryIndex = 0
        var previousMatch = -1

        for (index, byte) in candidate.enumerated() {
            guard queryIndex < query.count else { break }
            guard byte == query[queryIndex] else { continue }

            total += characterScore
            if index == 0 {
                total += startBonus
            } else if isBoundary(candidate[index - 1]) {
                total += boundaryBonus
            }
            if previousMatch == index - 1 {
                total += consecutiveBonus
            }

            previousMatch = index
            queryIndex += 1
        }

        guard queryIndex == query.count else { return nil }
        return total - (candidate.count - query.count) / lengthPenaltyDivisor
    }

    private static func isBoundary(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: " "), UInt8(ascii: "-"), UInt8(ascii: "_"), UInt8(ascii: "."),
             UInt8(ascii: "/"), UInt8(ascii: ":"), UInt8(ascii: "("), UInt8(ascii: "["),
             UInt8(ascii: ","), UInt8(ascii: "|"):
            return true
        default:
            return false
        }
    }
}
