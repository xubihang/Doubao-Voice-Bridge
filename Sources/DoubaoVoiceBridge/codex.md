# DoubaoVoiceBridge/
> L2 | 父级: /codex.md

成员清单
main.swift: macOS 菜单栏入口，编排权限门禁、LaunchAgent、事件 tap、输入法切换、焦点 bounce、豆包语音触发，以及语音键 key-up 后延时恢复输入法；HotkeySender 模拟真实硬件事件序列

模块法则:
入口层只编排副作用。配置、状态机和版本策略来自 DoubaoVoiceBridgeCore；入口不得复制版本判断和配置解析逻辑。

[PROTOCOL]: 变更时更新此头部，然后检查 codex.md
