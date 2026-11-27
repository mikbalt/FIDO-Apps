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
        // WebAuthn data and checks: options JSON, clientDataJSON, authenticatorData, MakeCredential and
        // GetAssertion, and the minimal local RP. No UI, no CoreNFC.
        .target(name: "WebAuthn", dependencies: ["CTAP", "PinUvAuth"]),
        // CoreNFC transport (iOS only), the FIDOSimulator facade and its scenarios.
        // Re-exports CardCore, CTAP, PinUvAuth and WebAuthn.
        .target(name: "FIDOKit", dependencies: ["CardCore", "CTAP", "PinUvAuth", "WebAuthn"]),
        .testTarget(
            name: "CardCoreTests",
            dependencies: ["CardCore"],
            resources: [.copy("Fixtures")]
        ),
        // Reads the shared trace fixtures from CardCoreTests/Fixtures via #filePath.
        .testTarget(name: "CTAPTests", dependencies: ["CTAP"]),
        // Test-only: a fake authenticator that speaks ClientPIN, for scenario tests without a card.
        .target(name: "FIDOTestSupport", dependencies: ["PinUvAuth"], path: "Tests/FIDOTestSupport"),
        .testTarget(name: "WebAuthnTests", dependencies: ["WebAuthn", "FIDOTestSupport"]),
        .testTarget(name: "PinUvAuthTests", dependencies: ["PinUvAuth", "FIDOTestSupport"]),
        // Loads fixtures from CardCoreTests/Fixtures via #filePath, so there is a single copy.
        .testTarget(name: "FIDOKitTests", dependencies: ["FIDOKit", "FIDOTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
