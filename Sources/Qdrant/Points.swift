import Foundation

extension QdrantPointId {
    /// The id as Qdrant stores a UUID: lowercase text.
    public init(_ id: UUID) {
        self.init()
        uuid = id.uuidString.lowercased()
    }
}

extension QdrantPointStruct {
    /// A point with one unnamed dense vector. `payload` is encoded with ``QdrantPayloadEncoder``.
    public init(id: UUID, vector: [Float], payload: some Encodable) throws {
        self.init()
        self.id = QdrantPointId(id)
        self.vectors.vector.dense.data = vector
        self.payload = try QdrantPayloadEncoder().encode(payload)
    }
}

extension QdrantPointsSelector {
    /// The points with these ids.
    public static func ids(_ ids: [UUID]) -> QdrantPointsSelector {
        .with { $0.points.ids = ids.map(QdrantPointId.init) }
    }
}

extension QdrantQuery {
    /// The points nearest to a dense vector.
    public static func nearest(_ vector: [Float]) -> QdrantQuery {
        .with { $0.nearest.dense.data = vector }
    }
}
