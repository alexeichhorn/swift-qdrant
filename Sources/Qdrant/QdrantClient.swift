import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

// What a failed call throws, so callers can catch it without depending on gRPC themselves.
@_exported import struct GRPCCore.RPCError

/// A client for Qdrant's gRPC API. Requests and responses are the generated `Qdrant…` messages.
///
/// ```swift
/// let qdrant = try QdrantClient(url: "http://localhost:6334", apiKey: nil, timeout: .seconds(30))
/// Task { try? await qdrant.run() }
/// let info = try await qdrant.collectionInfo(.with { $0.collectionName = "products" })
/// ```
///
/// A failed call throws `RPCError`; its `code` tells a missing collection (`.notFound`) from other failures.
public final class QdrantClient: Sendable {
    private let client: GRPCClient<HTTP2ClientTransport.Posix>
    private let collections: QdrantCollections.Client<HTTP2ClientTransport.Posix>
    private let points: QdrantPoints.Client<HTTP2ClientTransport.Posix>
    private let metadata: Metadata
    private let options: CallOptions

    /// Connects on the first call, not here.
    ///
    /// - Parameters:
    ///   - url: The gRPC endpoint, usually port 6334. `https` uses TLS with the system's root certificates.
    ///   - apiKey: Sent as the `api-key` header of every call.
    ///   - timeout: The time one call may take.
    public init(url: String, apiKey: String? = nil, timeout: Duration = .seconds(5)) throws {
        guard let components = URLComponents(string: url), let host = components.host, ["http", "https"].contains(components.scheme)
        else {
            throw QdrantClientError.invalidURL(url)
        }
        let usesTLS = components.scheme == "https"
        let transport = try HTTP2ClientTransport.Posix(
            target: .dns(host: host, port: components.port ?? (usesTLS ? 443 : 80)),
            transportSecurity: usesTLS ? .tls : .plaintext,
            // gRPC's default waits up to two minutes between connection attempts, so calls would keep failing that long
            // after Qdrant is back from an outage.
            config: .defaults { $0.backoff.max = .seconds(1) }
        )

        client = GRPCClient(transport: transport)
        collections = QdrantCollections.Client(wrapping: client)
        points = QdrantPoints.Client(wrapping: client)
        var metadata: Metadata = [:]
        if let apiKey {
            metadata.addString(apiKey, forKey: "api-key")
        }
        self.metadata = metadata

        var options = CallOptions.defaults
        options.timeout = timeout
        // A batch of points with their vectors and payloads is larger than gRPC's default of 4 MB.
        options.maxRequestMessageBytes = .max
        options.maxResponseMessageBytes = .max
        self.options = options
    }

    /// Keeps the connection open. Calls made before this runs wait for it; it returns after ``shutdown()``.
    public func run() async throws {
        try await client.runConnections()
    }

    /// Lets the calls in flight finish and closes the connection, which ends ``run()``.
    public func shutdown() {
        client.beginGracefulShutdown()
    }

    // MARK: - Collections

    public func collectionInfo(_ request: QdrantGetCollectionInfoRequest) async throws -> QdrantGetCollectionInfoResponse {
        try await collections.get(request, metadata: metadata, options: options)
    }

    public func createCollection(_ request: QdrantCreateCollection) async throws -> QdrantCollectionOperationResponse {
        try await collections.create(request, metadata: metadata, options: options)
    }

    public func updateCollection(_ request: QdrantUpdateCollection) async throws -> QdrantCollectionOperationResponse {
        try await collections.update(request, metadata: metadata, options: options)
    }

    public func deleteCollection(_ request: QdrantDeleteCollection) async throws -> QdrantCollectionOperationResponse {
        try await collections.delete(request, metadata: metadata, options: options)
    }

    // MARK: - Points

    public func createFieldIndex(_ request: QdrantCreateFieldIndexCollection) async throws -> QdrantPointsOperationResponse {
        try await retryingOnce { options in try await points.createFieldIndex(request, metadata: metadata, options: options) }
    }

    public func query(_ request: QdrantQueryPoints) async throws -> QdrantQueryResponse {
        try await retryingOnce { options in try await points.query(request, metadata: metadata, options: options) }
    }

    public func getPoints(_ request: QdrantGetPoints) async throws -> QdrantGetResponse {
        try await retryingOnce { options in try await points.get(request, metadata: metadata, options: options) }
    }

    public func upsertPoints(_ request: QdrantUpsertPoints) async throws -> QdrantPointsOperationResponse {
        try await retryingOnce { options in try await points.upsert(request, metadata: metadata, options: options) }
    }

    public func updatePointsBatch(_ request: QdrantUpdateBatchPoints) async throws -> QdrantUpdateBatchResponse {
        try await retryingOnce { options in try await points.updateBatch(request, metadata: metadata, options: options) }
    }

    public func deletePoints(_ request: QdrantDeletePoints) async throws -> QdrantPointsOperationResponse {
        try await retryingOnce { options in try await points.delete(request, metadata: metadata, options: options) }
    }

    // MARK: - Private

    /// A points call that failed in a way a broken connection produces is sent once more, as Qdrant's own clients do.
    /// The second attempt waits for the connection to come back, within its timeout.
    private func retryingOnce<Response>(_ call: (CallOptions) async throws -> Response) async throws -> Response {
        do {
            return try await call(options)
        } catch let error as RPCError where Self.connectionFailureCodes.contains(error.code) {
            var options = options
            options.waitForReady = true
            return try await call(options)
        }
    }

    private static let connectionFailureCodes: Set<RPCError.Code> = [.internalError, .unavailable, .cancelled, .unknown, .deadlineExceeded]
}

public enum QdrantClientError: Error, CustomStringConvertible {
    case invalidURL(String)

    public var description: String {
        switch self {
        case .invalidURL(let url): "'\(url)' is not an http or https URL"
        }
    }
}
