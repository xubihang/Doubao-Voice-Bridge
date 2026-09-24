/**
 * [INPUT]: 依赖 XCTest 的断言能力，依赖 DoubaoVoiceBridgeCore 的豆包版本探测与策略选择
 * [OUTPUT]: 对外提供 DoubaoImeVersionDetector 与 DoubaoImeVoiceStrategy 的行为回归测试
 * [POS]: Tests/DoubaoVoiceBridgeCoreTests 的版本协议测试，保护 0.9.2 与 1.0.1 两个触发策略边界
 * [PROTOCOL]: 变更时更新此头部，然后检查 codex.md
 */
import XCTest
@testable import DoubaoVoiceBridgeCore

final class DoubaoImeVersionTests: XCTestCase {
    func testVersionsBeforeZeroNineTwoUseLegacyWarmupHoldTrigger() {
        XCTAssertEqual(DoubaoImeVoiceStrategy.resolve(versionString: "0.9.1"), .warmupHoldHotkey)
        XCTAssertEqual(DoubaoImeVoiceStrategy.resolve(versionString: "0.8.9"), .warmupHoldHotkey)
    }

    func testVersionsFromZeroNineTwoThroughOneZeroZeroUseTapTrigger() {
        XCTAssertEqual(DoubaoImeVoiceStrategy.resolve(versionString: "0.9.2"), .tapHotkey)
        XCTAssertEqual(DoubaoImeVoiceStrategy.resolve(versionString: "0.10.0"), .tapHotkey)
        XCTAssertEqual(DoubaoImeVoiceStrategy.resolve(versionString: "1.0.0"), .tapHotkey)
    }

    func testOneZeroOneAndLaterHoldVoiceHotkeyUntilTriggerRelease() {
        XCTAssertEqual(DoubaoImeVoiceStrategy.resolve(versionString: "1.0.1"), .holdHotkey)
        XCTAssertEqual(DoubaoImeVoiceStrategy.resolve(versionString: "1.1.0"), .holdHotkey)
    }

    func testUnknownVersionFallsBackToLegacyWarmupHoldTrigger() {
        XCTAssertEqual(DoubaoImeVoiceStrategy.resolve(versionString: nil), .warmupHoldHotkey)
        XCTAssertEqual(DoubaoImeVoiceStrategy.resolve(versionString: "bad-version"), .warmupHoldHotkey)
    }

    func testDetectorReadsFirstExistingDoubaoBundleVersion() throws {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let missingBundle = tempDirectory.appendingPathComponent("Missing.app", isDirectory: true)
        let bundle = tempDirectory.appendingPathComponent("DoubaoIme.app", isDirectory: true)
        let contents = bundle.appendingPathComponent("Contents", isDirectory: true)
        try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleShortVersionString</key>
            <string>0.9.2</string>
        </dict>
        </plist>
        """.data(using: .utf8)!.write(to: contents.appendingPathComponent("Info.plist"))

        defer {
            try? fileManager.removeItem(at: tempDirectory)
        }

        let detector = DoubaoImeVersionDetector(bundleURLs: [missingBundle, bundle])

        XCTAssertEqual(detector.installedVersionString(), "0.9.2")
        XCTAssertEqual(detector.voiceStrategy(), .tapHotkey)
    }
}
