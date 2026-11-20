// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FIDOKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FIDOKit", targets: ["FIDOKit"]),
    ],
    targets: [
        // Pure Swift: APDU model, ISO 7816 channel, transport contract, traces, mock transport.
        .target(name: "CardCore"),
        // Pure Swift: canonical CBOR, CTAP client, command models (GetInfo, ...).
        .target(name: "CTAP", dependencies: ["CardCore"]),
        // PIN/UV auth protocol 2 (CryptoKit + CommonCrypto) and authenticatorClientPIN.
        .target(name: "PinUvAuth", dependencies: ["CTAP"]),
        // CoreNFC transport (iOS only), the FIDOSimulator facade and its scenarios.
        // Re-exports CardCore, CTAP and PinUvAuth.
        .target(name: "FIDOKit", dependencies: ["CardCore", "CTAP", "PinUvAuth"]),
        .testTarget(
            name: "CardCoreTests",
            dependencies: ["CardCore"],
            resources: [.copy("Fixtures")]
        ),
        // Reads the shared trace fixtures from CardCoreTests/Fixtures via #filePath.
        .testTarget(name: "CTAPTests", dependencies: ["CTAP"]),
        // Test-only: a fake authenticator that speaks ClientPIN, for scenario tests without a card.
        .target(name: "FIDOTestSupport", dependencies: ["PinUvAuth"], path: "Tests/FIDOTestSupport"),
        .testTarget(name: "PinUvAuthTests", dependencies: ["PinUvAuth", "FIDOTestSupport"]),
        // Loads fixtures from CardCoreTests/Fixtures via #filePath, so there is a single copy.
        .testTarget(name: "FIDOKitTests", dependencies: ["FIDOKit", "FIDOTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
