import Foundation

public struct AppInfo: Codable, Sendable, Equatable {
    public var name: String
    public var version: String
    public var build: String

    public init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }

    /// Reads name, version and build from a bundle's Info.plist.
    public static func current(bundle: Bundle = .main) -> AppInfo {
        let info = bundle.infoDictionary ?? [:]
        return AppInfo(
            name: info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? "FIDOSims",
            version: info["CFBundleShortVersionString"] as? String ?? "0.0.0",
            build: info["CFBundleVersion"] as? String ?? "0"
        )
    }
}

func ciWarningProbe() { let unused = 1 }
