/**
 * [INPUT]: 依赖 Foundation 的 Bundle 路径与 Info.plist 读取能力
 * [OUTPUT]: 对外提供 DoubaoImeVoiceStrategy 与 DoubaoImeVersionDetector
 * [POS]: DoubaoVoiceBridgeCore 的豆包版本协议层，隔离版本探测与语音触发策略选择
 * [PROTOCOL]: 变更时更新此头部，然后检查 codex.md
 */
import Foundation

public enum DoubaoImeVoiceStrategy: Equatable, Sendable {
    case holdHotkey
    case tapHotkey
    case warmupHoldHotkey

    public static func resolve(versionString: String?) -> DoubaoImeVoiceStrategy {
        guard let version = SemanticVersion(versionString) else {
            return .warmupHoldHotkey
        }
        if version >= SemanticVersion(1, 0, 1) {
            return .holdHotkey
        }
        if version >= SemanticVersion(0, 9, 2) {
            return .tapHotkey
        }
        return .warmupHoldHotkey
    }
}

public struct DoubaoImeVersionDetector: Sendable {
    public let bundleURLs: [URL]

    public init(bundleURLs: [URL] = DoubaoImeVersionDetector.defaultBundleURLs()) {
        self.bundleURLs = bundleURLs
    }

    public static func defaultBundleURLs() -> [URL] {
        let homeInputMethod = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Input Methods/DoubaoIme.app", isDirectory: true)
        return [
            URL(fileURLWithPath: "/Library/Input Methods/DoubaoIme.app", isDirectory: true),
            homeInputMethod
        ]
    }

    public func installedVersionString() -> String? {
        for bundleURL in bundleURLs {
            guard let version = versionString(in: bundleURL) else {
                continue
            }
            return version
        }
        return nil
    }

    public func voiceStrategy() -> DoubaoImeVoiceStrategy {
        DoubaoImeVoiceStrategy.resolve(versionString: installedVersionString())
    }

    private func versionString(in bundleURL: URL) -> String? {
        let infoURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any] else {
            return nil
        }
        return info["CFBundleShortVersionString"] as? String
    }
}

private struct SemanticVersion: Comparable {
    private let components: [Int]

    init?(_ rawValue: String?) {
        guard let rawValue else {
            return nil
        }
        let parts = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return nil
        }

        var parsed: [Int] = []
        for part in parts {
            guard let value = Int(part) else {
                return nil
            }
            parsed.append(value)
        }
        components = parsed
    }

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        components = [major, minor, patch]
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let length = max(lhs.components.count, rhs.components.count)
        for index in 0..<length {
            let left = lhs.components[safe: index] ?? 0
            let right = rhs.components[safe: index] ?? 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
