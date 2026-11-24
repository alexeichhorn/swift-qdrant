# swift-qdrant

A client for [Qdrant](https://qdrant.tech)'s gRPC API, built on grpc-swift 2.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/alexeichhorn/swift-qdrant.git", from: "0.1.0")
]
```

Then add the product to a target: `.product(name: "Qdrant", package: "swift-qdrant")`.

## Usage

```swift
import Qdrant

let qdrant = try QdrantClient(url: "http://localhost:6334", apiKey: nil, timeout: .seconds(30))
Task { try await qdrant.run() }

let info = try await qdrant.collectionInfo(QdrantGetCollectionInfoRequest(collection: "products"))

struct ProductPayload: Encodable {
    let name: String
    let inStock: Bool
    let brandID: Int64?
}
let product = ProductPayload(name: "Desk Lamp", inStock: true, brandID: nil)
let point = try QdrantPointStruct(id: UUID(), vector: [0.1, 0.2, 0.3], payload: product)
_ = try await qdrant.upsertPoints(QdrantUpsertPoints(collection: "products", points: [point], wait: true))

let hits = try await qdrant.query(
    QdrantQueryPoints(
        collection: "products",
        query: .nearest([0.1, 0.2, 0.3]),
        filter: QdrantFilter(must: [.matches("inStock", true)]),
        limit: 10,
        withPayload: false))
```

- Requests and responses are the `Qdrant…` messages generated from Qdrant's proto files. The requests listed below
  have an initializer with labelled arguments; an argument left out stays unset and Qdrant applies its default. Any
  message can also be built field by field with `.with { $0.… = … }`.
- `withPayload:` and `withVectors:` take `true` or `false`; `withPayload: .fields(["name"])` returns only those fields.
- A payload is any `Encodable` value: `QdrantPointStruct(id:vector:payload:)` encodes it, and
  `QdrantPayloadEncoder().encode(_:)` gives the payload alone, for a call that replaces payloads. The keys are the
  value's coding keys.
- Qdrant tells an integer from a double, so the Swift type decides: every integer type is stored as an integer, and
  `Float` and `Double` as a double even when the value is whole. A `nil` property is stored as `null`, a `UUID` as
  lowercase text and a `Date` as ISO 8601 text with milliseconds.
- `QdrantPointId(uuid)` is a point id from a `UUID`.
- Filters have short forms: `QdrantFilter(must:should:mustNot:)` takes conditions such as `.matches("in_stock", true)`,
  `.matchesText("name", "desk lamp")`, `.matchesPhrase(…)`, `.range("price", atLeast: 10, atMost: 20)`,
  `.dateRange("added_at", atLeast: date)`, `.hasID(ids)` and `.filter(nested)`.
- `QdrantPointsSelector.ids(uuids)` selects points by id, and `QdrantQuery.nearest(vector)` is a nearest-neighbour query.
- `run()` keeps the connection open and must be running while calls are made; start it in a task that lives as long as
  the client. The connection is opened by the first call.
- `https` URLs use TLS with the system's root certificates. `apiKey` is sent as the `api-key` header.
- `timeout` limits each call. Messages of any size are sent and accepted; gRPC's default limit of 4 MB is too small for
  a batch of points.
- A failed call throws `RPCError`. Its `code` is `.notFound` for a missing collection and `.alreadyExists` when
  creating one that exists.
- Calls on points (`query`, `getPoints`, `upsertPoints`, `updatePointsBatch`, `deletePoints`, `createFieldIndex`) are
  sent a second time when the first attempt fails the way a broken connection does (`unavailable`, `internalError`,
  `unknown`, `cancelled`, `deadlineExceeded`), as Qdrant's Rust client does. The second attempt waits for the
  connection to come back, within its timeout. Calls on collections are not sent again.
- A lost connection is retried at least once a second, so calls work again as soon as Qdrant is back. While it is
  down, a points call fails when its timeout ends and a collections call fails at once.

## What's covered

`QdrantClient` has `collectionInfo`, `createCollection`, `updateCollection`, `deleteCollection` and the six calls on
points above. Every other call of Qdrant's collections and points API exists in the generated
`QdrantCollections.Client` and `QdrantPoints.Client`; to use one, add a method to `QdrantClient` that forwards to it,
like the existing ones. Snapshots and the other services in Qdrant's API are not included.

## Updating to another Qdrant version

`Protos/` holds `collections.proto`, `collections_service.proto`, `json_with_int.proto`, `points.proto`,
`points_service.proto` and `qdrant_common.proto` from the `proto/` folder of
[Qdrant's Rust client](https://github.com/qdrant/rust-client) 1.19.0. To move to another version:

1. Replace them with the same files from the Rust client's tag for that version.
2. Build the code generators from this package's dependencies:

   ```sh
   swift build -c release --product protoc
   swift build -c release --product protoc-gen-swift
   swift build -c release --product protoc-gen-grpc-swift-2
   ```

3. Regenerate `Sources/Qdrant/Generated`:

   ```sh
   PATH="$(swift build -c release --show-bin-path):$PATH" \
     PROTO_INCLUDE=.build/checkouts/swift-protobuf/Protos/Sources/SwiftProtobuf \
     scripts/generate.sh
   ```

4. Run `swift build` and `swift test`. Generated code expects the swift-protobuf and grpc-swift-protobuf versions it
   was generated with, so raise their minimums in `Package.swift` if they resolved to newer ones.

## Requirements

- Swift 6.2 or later.
- macOS 15 or later, or Linux.

## License

MIT. See [LICENSE](LICENSE).

The proto files in `Protos/` are Qdrant's and are licensed under the Apache License 2.0; see
[Protos/LICENSE](Protos/LICENSE). The code in `Sources/Qdrant/Generated` is generated from them and is distributed
under the same license.
