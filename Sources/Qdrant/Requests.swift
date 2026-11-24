import Foundation

// Initializers for the requests, so one reads as a single expression:
// `QdrantDeletePoints(collection: "products", points: .ids(ids), wait: true)`.
// A parameter left out stays unset, and Qdrant applies its default.

// MARK: - Collections

extension QdrantGetCollectionInfoRequest {
    public init(collection: String) {
        self.init()
        collectionName = collection
    }
}

extension QdrantCreateCollection {
    /// A collection whose points have one unnamed vector.
    public init(
        collection: String,
        vectors: QdrantVectorParams,
        hnsw: QdrantHnswConfigDiff? = nil,
        quantization: QdrantQuantizationConfig? = nil
    ) {
        self.init()
        collectionName = collection
        vectorsConfig.params = vectors
        if let hnsw { hnswConfig = hnsw }
        if let quantization { quantizationConfig = quantization }
    }
}

extension QdrantVectorParams {
    public init(size: UInt64, distance: QdrantDistance, memory: QdrantMemory? = nil) {
        self.init()
        self.size = size
        self.distance = distance
        if let memory { self.memory = memory }
    }
}

extension QdrantHnswConfigDiff {
    public init(memory: QdrantMemory) {
        self.init()
        self.memory = memory
    }
}

extension QdrantQuantizationConfig {
    /// Scalar quantization to 8-bit integers.
    public static func scalar(quantile: Float? = nil, memory: QdrantMemory? = nil) -> QdrantQuantizationConfig {
        var config = QdrantQuantizationConfig()
        config.scalar.type = .int8
        if let quantile { config.scalar.quantile = quantile }
        if let memory { config.scalar.memory = memory }
        return config
    }
}

extension QdrantUpdateCollection {
    public init(collection: String, optimizers: QdrantOptimizersConfigDiff? = nil, hnsw: QdrantHnswConfigDiff? = nil) {
        self.init()
        collectionName = collection
        if let optimizers { optimizersConfig = optimizers }
        if let hnsw { hnswConfig = hnsw }
    }
}

extension QdrantDeleteCollection {
    public init(collection: String) {
        self.init()
        collectionName = collection
    }
}

extension QdrantOptimizersConfigDiff {
    /// - Parameter maxOptimizationThreads: How many optimizations may run at once; `0` turns them off.
    public init(
        defaultSegmentNumber: UInt64? = nil,
        maxSegmentSize: UInt64? = nil,
        indexingThreshold: UInt64? = nil,
        maxOptimizationThreads: UInt64? = nil
    ) {
        self.init()
        if let defaultSegmentNumber { self.defaultSegmentNumber = defaultSegmentNumber }
        if let maxSegmentSize { self.maxSegmentSize = maxSegmentSize }
        if let indexingThreshold { self.indexingThreshold = indexingThreshold }
        if let maxOptimizationThreads { self.maxOptimizationThreads.value = maxOptimizationThreads }
    }
}

extension QdrantCreateFieldIndexCollection {
    /// - Parameter textIndex: The settings of a text index, when `type` is `.text`.
    public init(
        collection: String,
        field: String,
        type: QdrantFieldType,
        textIndex: QdrantTextIndexParams? = nil,
        wait: Bool? = nil
    ) {
        self.init()
        collectionName = collection
        fieldName = field
        fieldType = type
        if let textIndex { fieldIndexParams.textIndexParams = textIndex }
        if let wait { self.wait = wait }
    }
}

extension QdrantTextIndexParams {
    public init(tokenizer: QdrantTokenizerType, lowercase: Bool? = nil, phraseMatching: Bool? = nil, memory: QdrantMemory? = nil) {
        self.init()
        self.tokenizer = tokenizer
        if let lowercase { self.lowercase = lowercase }
        if let phraseMatching { self.phraseMatching = phraseMatching }
        if let memory { self.memory = memory }
    }
}

// MARK: - Points

extension QdrantQueryPoints {
    public init(
        collection: String,
        query: QdrantQuery,
        filter: QdrantFilter? = nil,
        limit: Int? = nil,
        withPayload: QdrantWithPayloadSelector? = nil,
        withVectors: QdrantWithVectorsSelector? = nil
    ) {
        self.init()
        collectionName = collection
        self.query = query
        if let filter { self.filter = filter }
        if let limit { self.limit = UInt64(limit) }
        if let withPayload { self.withPayload = withPayload }
        if let withVectors { self.withVectors = withVectors }
    }
}

extension QdrantGetPoints {
    public init(
        collection: String,
        ids: [UUID],
        withPayload: QdrantWithPayloadSelector? = nil,
        withVectors: QdrantWithVectorsSelector? = nil
    ) {
        self.init()
        collectionName = collection
        self.ids = ids.map(QdrantPointId.init)
        if let withPayload { self.withPayload = withPayload }
        if let withVectors { self.withVectors = withVectors }
    }
}

extension QdrantUpsertPoints {
    public init(collection: String, points: [QdrantPointStruct], wait: Bool? = nil) {
        self.init()
        collectionName = collection
        self.points = points
        if let wait { self.wait = wait }
    }
}

extension QdrantUpdateBatchPoints {
    public init(collection: String, operations: [QdrantPointsUpdateOperation], wait: Bool? = nil) {
        self.init()
        collectionName = collection
        self.operations = operations
        if let wait { self.wait = wait }
    }
}

extension QdrantPointsUpdateOperation {
    /// Replaces the whole payload of the selected points and keeps their vectors. `payload` is encoded with
    /// ``QdrantPayloadEncoder``.
    public static func overwritePayload(of points: QdrantPointsSelector, with payload: some Encodable) throws -> QdrantPointsUpdateOperation
    {
        var operation = QdrantPointsUpdateOperation()
        operation.overwritePayload.pointsSelector = points
        operation.overwritePayload.payload = try QdrantPayloadEncoder().encode(payload)
        return operation
    }
}

extension QdrantDeletePoints {
    public init(collection: String, points: QdrantPointsSelector, wait: Bool? = nil) {
        self.init()
        collectionName = collection
        self.points = points
        if let wait { self.wait = wait }
    }
}

/// `true` returns the whole payload and `false` none; ``fields(_:)`` returns only the named fields.
extension QdrantWithPayloadSelector: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init()
        enable = value
    }

    public static func fields(_ fields: [String]) -> QdrantWithPayloadSelector {
        var selector = QdrantWithPayloadSelector()
        selector.include.fields = fields
        return selector
    }
}

/// `true` returns the vectors and `false` leaves them out.
extension QdrantWithVectorsSelector: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init()
        enable = value
    }
}
