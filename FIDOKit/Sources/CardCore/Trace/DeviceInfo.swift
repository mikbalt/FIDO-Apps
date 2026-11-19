import Foundation

public struct DeviceInfo: Codable, Sendable, Equatable {
    /// Hardware identifier such as `iPhone16,2`, or a reader name for PC/SC traces.
    public var model: String
    /// Operating system, such as `iOS 26.1`.
    public var os: String

    public init(model: String, os: String) {
        self.model = model
        self.os = os
    }

    /// The device this process runs on.
    public static var current: DeviceInfo {
        DeviceInfo(model: hardwareModel, os: operatingSystem)
    }

    private static var hardwareModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        #if os(macOS)
        return sysctlString("hw.model") ?? "Mac"
        #else
        return sysctlString("hw.machine") ?? "unknown"
        #endif
    }

    private static var operatingSystem: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        var number = "\(version.majorVersion).\(version.minorVersion)"
        if version.patchVersion != 0 {
            number += ".\(version.patchVersion)"
        }
        #if os(iOS)
        let name = "iOS"
        #elseif os(macOS)
        let name = "macOS"
        #else
        let name = "Unknown OS"
        #endif
        #if targetEnvironment(simulator)
        return "\(name) \(number) Simulator"
        #else
        return "\(name) \(number)"
        #endif
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
