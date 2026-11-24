// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "swift-qdrant",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Qdrant", targets: ["Qdrant"])
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.4"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.12.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.5.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.41.0"),
    ],
    targets: [
        .target(
            name: "Qdrant",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
        .testTarget(name: "QdrantTests", dependencies: ["Qdrant", .product(name: "SwiftProtobuf", package: "swift-protobuf")]),
    ]
)
