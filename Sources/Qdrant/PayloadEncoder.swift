import Foundation

/// Turns an `Encodable` value into a point's payload.
///
/// ```swift
/// struct ProductPayload: Encodable {
///     let name: String
///     let brandID: Int64?
/// }
/// let payload = try QdrantPayloadEncoder().encode(ProductPayload(name: "Desk Lamp", brandID: nil))
/// // ["name": "Desk Lamp", "brandID": null]
/// ```
///
/// The payload keys are the value's coding keys. Qdrant tells an integer from a double, so the Swift type decides:
/// every integer type is stored as an integer, and `Float` and `Double` as a double even when the value is whole.
/// A `nil` property is stored as `null`, a `UUID` as lowercase text, and a `Date` as ISO 8601 text with milliseconds.
public struct QdrantPayloadEncoder: Sendable {
    public init() {}

    /// - Throws: `EncodingError` when `value` does not encode as an object.
    public func encode(_ value: some Encodable) throws -> [String: QdrantValue] {
        let node = Node()
        try node.write(value, at: [])
        guard case .object(let fields) = node.content else {
            throw EncodingError.invalidValue(
                value, EncodingError.Context(codingPath: [], debugDescription: "A payload is an object, and this value is not one."))
        }
        return fields.mapValues(\.value)
    }
}

/// One value while it is being encoded. Containers share their node, so a nested container can still be written to
/// after its parent moved on.
private final class Node {
    enum Content {
        case empty
        case value(QdrantValue)
        case object([String: Node])
        case array([Node])
    }

    var content = Content.empty

    var value: QdrantValue {
        switch content {
        case .value(let value): value
        case .array(let items): .with { $0.listValue.values = items.map(\.value) }
        case .object(let fields): .with { $0.structValue.fields = fields.mapValues(\.value) }
        // A type that encodes nothing is an empty object, as in JSON.
        case .empty: .with { $0.structValue = QdrantStruct() }
        }
    }

    func write(_ value: some Encodable, at codingPath: [any CodingKey]) throws {
        switch value {
        case let uuid as UUID:
            content = .value(.with { $0.stringValue = uuid.uuidString.lowercased() })
        case let date as Date:
            content = .value(.with { $0.stringValue = date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)) })
        default:
            try value.encode(to: NodeEncoder(node: self, codingPath: codingPath))
        }
    }

    func writeNull() {
        content = .value(.with { $0.nullValue = .nullValue })
    }

    func write(_ value: Bool) {
        content = .value(.with { $0.boolValue = value })
    }

    func write(_ value: String) {
        content = .value(.with { $0.stringValue = value })
    }

    /// A number that is not finite has no payload form and is stored as `null`.
    func write(_ value: Double) {
        if value.isFinite {
            content = .value(.with { $0.doubleValue = value })
        } else {
            writeNull()
        }
    }

    /// An integer above the `Int64` range is stored as a double, the nearest value Qdrant can hold.
    func write(_ value: some BinaryInteger) {
        if let integer = Int64(exactly: value) {
            content = .value(.with { $0.integerValue = integer })
        } else {
            write(Double(value))
        }
    }
}

private struct NodeEncoder: Encoder {
    let node: Node
    let codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if case .object = node.content {} else { node.content = .object([:]) }
        return KeyedEncodingContainer(KeyedContainer<Key>(node: node, codingPath: codingPath))
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        if case .array = node.content {} else { node.content = .array([]) }
        return UnkeyedContainer(node: node, codingPath: codingPath)
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        SingleValueContainer(node: node, codingPath: codingPath)
    }
}

private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let node: Node
    let codingPath: [any CodingKey]

    private func child(_ key: Key) -> Node {
        child(named: key.stringValue)
    }

    private func child(named name: String) -> Node {
        let child = Node()
        if case .object(var fields) = node.content {
            fields[name] = child
            node.content = .object(fields)
        }
        return child
    }

    mutating func encodeNil(forKey key: Key) throws { child(key).writeNull() }
    mutating func encode(_ value: Bool, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: String, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: Double, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: Float, forKey key: Key) throws { child(key).write(Double(value)) }
    mutating func encode(_ value: Int, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { child(key).write(value) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { child(key).write(value) }

    mutating func encode<Value: Encodable>(_ value: Value, forKey key: Key) throws {
        try child(key).write(value, at: codingPath + [key])
    }

    // Swift's generated `encode(to:)` skips a `nil` property through these; a payload stores it as `null`.
    mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws { try encodeOrNull(value, key) }
    mutating func encodeIfPresent<Value: Encodable>(_ value: Value?, forKey key: Key) throws { try encodeOrNull(value, key) }

    private mutating func encodeOrNull<Value: Encodable>(_ value: Value?, _ key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<
        NestedKey
    > {
        NodeEncoder(node: child(key), codingPath: codingPath + [key]).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        NodeEncoder(node: child(key), codingPath: codingPath + [key]).unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        // Named directly: the caller's `CodingKeys` rarely has a `super` case.
        NodeEncoder(node: child(named: "super"), codingPath: codingPath)
    }

    mutating func superEncoder(forKey key: Key) -> any Encoder {
        NodeEncoder(node: child(key), codingPath: codingPath + [key])
    }
}

private struct UnkeyedContainer: UnkeyedEncodingContainer {
    let node: Node
    let codingPath: [any CodingKey]

    var count: Int {
        if case .array(let items) = node.content { items.count } else { 0 }
    }

    private func child() -> Node {
        let child = Node()
        if case .array(var items) = node.content {
            items.append(child)
            node.content = .array(items)
        }
        return child
    }

    mutating func encodeNil() throws { child().writeNull() }
    mutating func encode(_ value: Bool) throws { child().write(value) }
    mutating func encode(_ value: String) throws { child().write(value) }
    mutating func encode(_ value: Double) throws { child().write(value) }
    mutating func encode(_ value: Float) throws { child().write(Double(value)) }
    mutating func encode(_ value: Int) throws { child().write(value) }
    mutating func encode(_ value: Int8) throws { child().write(value) }
    mutating func encode(_ value: Int16) throws { child().write(value) }
    mutating func encode(_ value: Int32) throws { child().write(value) }
    mutating func encode(_ value: Int64) throws { child().write(value) }
    mutating func encode(_ value: UInt) throws { child().write(value) }
    mutating func encode(_ value: UInt8) throws { child().write(value) }
    mutating func encode(_ value: UInt16) throws { child().write(value) }
    mutating func encode(_ value: UInt32) throws { child().write(value) }
    mutating func encode(_ value: UInt64) throws { child().write(value) }

    mutating func encode<Value: Encodable>(_ value: Value) throws {
        try child().write(value, at: codingPath)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        NodeEncoder(node: child(), codingPath: codingPath).container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        NodeEncoder(node: child(), codingPath: codingPath).unkeyedContainer()
    }

    mutating func superEncoder() -> any Encoder {
        NodeEncoder(node: child(), codingPath: codingPath)
    }
}

private struct SingleValueContainer: SingleValueEncodingContainer {
    let node: Node
    let codingPath: [any CodingKey]

    mutating func encodeNil() throws { node.writeNull() }
    mutating func encode(_ value: Bool) throws { node.write(value) }
    mutating func encode(_ value: String) throws { node.write(value) }
    mutating func encode(_ value: Double) throws { node.write(value) }
    mutating func encode(_ value: Float) throws { node.write(Double(value)) }
    mutating func encode(_ value: Int) throws { node.write(value) }
    mutating func encode(_ value: Int8) throws { node.write(value) }
    mutating func encode(_ value: Int16) throws { node.write(value) }
    mutating func encode(_ value: Int32) throws { node.write(value) }
    mutating func encode(_ value: Int64) throws { node.write(value) }
    mutating func encode(_ value: UInt) throws { node.write(value) }
    mutating func encode(_ value: UInt8) throws { node.write(value) }
    mutating func encode(_ value: UInt16) throws { node.write(value) }
    mutating func encode(_ value: UInt32) throws { node.write(value) }
    mutating func encode(_ value: UInt64) throws { node.write(value) }

    mutating func encode<Value: Encodable>(_ value: Value) throws {
        try node.write(value, at: codingPath)
    }
}
