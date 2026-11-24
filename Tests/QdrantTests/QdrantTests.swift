import Foundation
import Qdrant
import Testing

@Test func clientRejectsAURLWithoutAnHTTPScheme() {
    #expect(throws: QdrantClientError.self) { try QdrantClient(url: "localhost:6334") }
    #expect(throws: QdrantClientError.self) { try QdrantClient(url: "grpc://localhost:6334") }
    #expect(throws: Never.self) { try QdrantClient(url: "http://localhost:6334") }
}

@Test func payloadEncoderKeepsQdrantsValueKinds() throws {
    struct Size: Encodable {
        let width: Float
        let height: Float
    }
    struct Payload: Encodable {
        let id: UUID
        let name: String
        let inStock: Bool
        let brandID: Int64
        let missing: String?
        let score: Float
        let whole: Double
        let huge: UInt64
        let notANumber: Double
        let tags: [String]
        let size: Size?
        let addedAt: Date
    }
    let payload = try QdrantPayloadEncoder().encode(
        Payload(
            id: UUID(uuidString: "01234567-89AB-4DEF-8123-456789ABCDEF")!, name: "Desk Lamp", inStock: true,
            brandID: 1_234_567, missing: nil, score: 8.55, whole: 47, huge: .max, notANumber: .nan, tags: ["a", "b"],
            size: Size(width: 47.5, height: 8.5), addedAt: Date(timeIntervalSince1970: 1_794_659_696.789)))

    #expect(payload.count == 12)
    #expect(payload["id"]?.kind == .stringValue("01234567-89ab-4def-8123-456789abcdef"))
    #expect(payload["name"]?.kind == .stringValue("Desk Lamp"))
    #expect(payload["inStock"]?.kind == .boolValue(true))
    #expect(payload["brandID"]?.kind == .integerValue(1_234_567))
    #expect(payload["missing"]?.kind == .nullValue(.nullValue))
    // A `Float` is stored as the double it widens to, and a whole `Double` stays a double.
    #expect(payload["score"]?.kind == .doubleValue(Double(Float(8.55))))
    #expect(payload["whole"]?.kind == .doubleValue(47))
    #expect(payload["huge"]?.kind == .doubleValue(Double(UInt64.max)))
    #expect(payload["notANumber"]?.kind == .nullValue(.nullValue))
    #expect(payload["tags"]?.listValue.values.map(\.stringValue) == ["a", "b"])
    #expect(payload["size"]?.structValue.fields == ["width": .with { $0.doubleValue = 47.5 }, "height": .with { $0.doubleValue = 8.5 }])
    #expect(payload["addedAt"]?.kind == .stringValue("2026-11-14T12:34:56.789Z"))

    #expect(throws: EncodingError.self) { try QdrantPayloadEncoder().encode(["not", "an", "object"]) }
}

private class Product: Encodable {
    let name = "Desk Lamp"
}

// Encodes its superclass the way Swift's docs recommend: into `superEncoder()`, which nests it under the key "super".
private final class Lamp: Product {
    let watts = 40

    private enum CodingKeys: String, CodingKey {
        case watts
    }

    override func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(watts, forKey: .watts)
        try super.encode(to: container.superEncoder())
    }
}

@Test func payloadEncoderEncodesASubclassThroughItsSuperclass() throws {
    let payload = try QdrantPayloadEncoder().encode(Lamp())

    #expect(payload["watts"]?.kind == .integerValue(40))
    #expect(payload["super"]?.structValue.fields["name"]?.kind == .stringValue("Desk Lamp"))
}

@Test func filterHelpersBuildTheConditionsQdrantExpects() throws {
    let id = UUID(uuidString: "01234567-89AB-4DEF-8123-456789ABCDEF")!
    let filter = QdrantFilter(
        must: [
            .matches("in_stock", false),
            .range("weight", atLeast: 47.1),
            .filter(QdrantFilter(should: [.matchesText("name", "desk lamp"), .matchesPhrase("name", "floor lamp")])),
            // 2026-11-14T12:34:56.789123Z, which a `Date` holds only approximately.
            .dateRange("added_at", atLeast: Date(timeIntervalSince1970: 1_794_659_696.789123)),
        ],
        mustNot: [.hasID([id])])

    #expect(filter.must[0].field.match.boolean == false)
    #expect(filter.must[1].field.range.gte == 47.1)
    #expect(!filter.must[1].field.range.hasLte)
    #expect(filter.must[2].filter.should.map(\.field.match.matchValue) == [.text("desk lamp"), .phrase("floor lamp")])
    #expect(filter.must[3].field.datetimeRange.gte.seconds == 1_794_659_696)
    #expect(filter.must[3].field.datetimeRange.gte.nanos == 789_123_000)
    #expect(filter.mustNot[0].hasID_p.hasID_p.map(\.uuid) == ["01234567-89ab-4def-8123-456789abcdef"])
    #expect(QdrantPointsSelector.ids([id]).points.ids == [QdrantPointId(id)])
    #expect(QdrantQuery.nearest([0.5, 1]).nearest.dense.data == [0.5, 1])
}
