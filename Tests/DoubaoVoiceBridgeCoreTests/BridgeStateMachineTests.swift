/**
 * [INPUT]: 依赖 XCTest 的断言能力，依赖 DoubaoVoiceBridgeCore 的 BridgeStateMachine
 * [OUTPUT]: 对外提供桥接状态机的行为回归测试
 * [POS]: Tests/DoubaoVoiceBridgeCoreTests 的核心状态测试，约束按键生命周期与恢复动作
 * [PROTOCOL]: 变更时更新此头部，然后检查 codex.md
 */
import XCTest
@testable import DoubaoVoiceBridgeCore

final class BridgeStateMachineTests: XCTestCase {
    func testTriggerDownWaitsForHoldThresholdBeforeStartingVoiceSession() {
        var machine = BridgeStateMachine()

        let downActions = machine.handle(.rightCommandDown)
        let thresholdActions = machine.handle(.triggerHoldThresholdPassed)

        XCTAssertEqual(downActions, [])
        XCTAssertEqual(thresholdActions, [.startVoiceSession])
        XCTAssertEqual(machine.state, .preparingVoice)
    }

    func testTriggerUpBeforeHoldThresholdDoesNotStartVoiceSession() {
        var machine = BridgeStateMachine()

        let downActions = machine.handle(.rightCommandDown)
        let upActions = machine.handle(.rightCommandUp)

        XCTAssertEqual(downActions, [])
        XCTAssertEqual(upActions, [])
        XCTAssertEqual(machine.state, .idle)
    }

    func testRightCommandUpBeforeOptionHoldCancelsPendingVoiceTrigger() {
        var machine = BridgeStateMachine()

        _ = machine.handle(.rightCommandDown)
        let downActions = machine.handle(.triggerHoldThresholdPassed)
        let upActions = machine.handle(.rightCommandUp)

        XCTAssertEqual(downActions, [.startVoiceSession])
        XCTAssertEqual(upActions, [.cancelPendingOptionHold, .restorePreviousInputMethod])
        XCTAssertEqual(machine.state, .idle)
    }

    func testRightCommandUpWhileHoldingOptionReleasesOptionThenRestoresInputMethod() {
        var machine = BridgeStateMachine()

        _ = machine.handle(.rightCommandDown)
        _ = machine.handle(.triggerHoldThresholdPassed)
        _ = machine.handle(.optionHoldStarted)
        let actions = machine.handle(.rightCommandUp)

        XCTAssertEqual(actions, [.releaseOptionHold, .restorePreviousInputMethod, .finishMarkedText])
        XCTAssertEqual(machine.state, .idle)
    }

    func testRightCommandUpAfterTapVoiceTriggerOnlyRestoresInputMethod() {
        var machine = BridgeStateMachine()

        _ = machine.handle(.rightCommandDown)
        _ = machine.handle(.triggerHoldThresholdPassed)
        _ = machine.handle(.tapVoiceTriggerSent)
        let actions = machine.handle(.rightCommandUp)

        XCTAssertEqual(actions, [.restorePreviousInputMethod, .finishMarkedText])
        XCTAssertEqual(machine.state, .idle)
    }
}
