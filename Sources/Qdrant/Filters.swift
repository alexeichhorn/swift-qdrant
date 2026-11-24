import Foundation
import SwiftProtobuf

extension QdrantFilter {
    /// A point passes when every `must` condition matches, at least one `should` condition matches if there are any,
    /// and no `mustNot` condition matches.
    public init(must: [QdrantCondition] = [], should: [QdrantCondition] = [], mustNot: [QdrantCondition] = []) {
        self.init()
        self.must = must
        self.should = should
        self.mustNot = mustNot
    }
}

extension QdrantCondition {
    /// The payload field equals `value`.
    public static func matches(_ field: String, _ value: Bool) -> QdrantCondition {
        .with {
            $0.field.key = field
            $0.field.match.boolean = value
        }
    }

    /// The payload field, which needs a text index, contains every word of `text`, in any order.
    public static func matchesText(_ field: String, _ text: String) -> QdrantCondition {
        .with {
            $0.field.key = field
            $0.field.match.text = text
        }
    }

    /// The payload field, which needs a text index with phrase matching, contains the words of `phrase` next to each
    /// other and in order.
    public static func matchesPhrase(_ field: String, _ phrase: String) -> QdrantCondition {
        .with {
            $0.field.key = field
            $0.field.match.phrase = phrase
        }
    }

    /// The numeric payload field lies within the given bounds, each of them inclusive.
    public static func range(_ field: String, atLeast: Double? = nil, atMost: Double? = nil) -> QdrantCondition {
        .with {
            $0.field.key = field
            if let atLeast { $0.field.range.gte = atLeast }
            if let atMost { $0.field.range.lte = atMost }
        }
    }

    /// The date payload field lies within the given bounds, each of them inclusive. A bound is sent to the microsecond.
    public static func dateRange(_ field: String, atLeast: Date? = nil, atMost: Date? = nil) -> QdrantCondition {
        .with {
            $0.field.key = field
            if let atLeast { $0.field.datetimeRange.gte = timestamp(atLeast) }
            if let atMost { $0.field.datetimeRange.lte = timestamp(atMost) }
        }
    }

    /// The point's id is one of `ids`.
    public static func hasID(_ ids: [UUID]) -> QdrantCondition {
        .with { $0.hasID_p.hasID_p = ids.map(QdrantPointId.init) }
    }

    /// A whole filter as one condition, to nest `should` inside `must` and the like.
    public static func filter(_ filter: QdrantFilter) -> QdrantCondition {
        .with { $0.filter = filter }
    }
}

/// `date` rounded to the microsecond. A `Date` cannot hold a nanosecond exactly, so more digits would be noise.
private func timestamp(_ date: Date) -> Google_Protobuf_Timestamp {
    let microseconds = Int64((date.timeIntervalSince1970 * 1_000_000).rounded())
    var (seconds, fraction) = microseconds.quotientAndRemainder(dividingBy: 1_000_000)
    // Before 1970 the remainder is negative, and nanos count forward from the second below.
    if fraction < 0 {
        seconds -= 1
        fraction += 1_000_000
    }
    return .with {
        $0.seconds = seconds
        $0.nanos = Int32(fraction) * 1000
    }
}
