/**
 * [INPUT]: 依赖 Foundation 的 Sendable 基础类型
 * [OUTPUT]: 对外提供会话状态、事件及语音释放、输入法恢复和结束待编辑文本的动作
 * [POS]: DoubaoVoiceBridgeCore 的会话状态核心，被菜单栏主程序驱动输入法切换与语音触发
 * [PROTOCOL]: 变更时更新此头部，然后检查 codex.md
 */
import Foundation

public enum BridgeState: Equatable, Sendable {
    case idle
    case waitingForTriggerHold
    case preparingVoice
    case holdingOption
    case tapVoiceActive
}

public enum BridgeEvent: Equatable, Sendable {
    case rightCommandDown
    case triggerHoldThresholdPassed
    case optionHoldStarted
    case tapVoiceTriggerSent
    case rightCommandUp
    case reset
}

public enum BridgeAction: Equatable, Sendable {
    case startVoiceSession
    case cancelPendingOptionHold
    case releaseOptionHold
    case restorePreviousInputMethod
    case finishMarkedText
}

public struct BridgeStateMachine: Sendable {
    public private(set) var state: BridgeState

    public init(state: BridgeState = .idle) {
        self.state = state
    }

    @discardableResult
    public mutating func handle(_ event: BridgeEvent) -> [BridgeAction] {
        switch (state, event) {
        case (.idle, .rightCommandDown):
            state = .waitingForTriggerHold
            return []
        case (.waitingForTriggerHold, .triggerHoldThresholdPassed):
            state = .preparingVoice
            return [.startVoiceSession]
        case (.waitingForTriggerHold, .rightCommandUp):
            state = .idle
            return []
        case (.preparingVoice, .optionHoldStarted):
            state = .holdingOption
            return []
        case (.preparingVoice, .tapVoiceTriggerSent):
            state = .tapVoiceActive
            return []
        case (.preparingVoice, .rightCommandUp):
            state = .idle
            return [.cancelPendingOptionHold, .restorePreviousInputMethod]
        case (.holdingOption, .rightCommandUp):
            state = .idle
            return [.releaseOptionHold, .restorePreviousInputMethod, .finishMarkedText]
        case (.tapVoiceActive, .rightCommandUp):
            state = .idle
            return [.restorePreviousInputMethod, .finishMarkedText]
        case (_, .reset):
            state = .idle
            return []
        default:
            return []
        }
    }
}
