# DoubaoVoiceBridge/
> L2 | 父级: /codex.md

成员清单
main.swift: macOS 菜单栏入口，编排权限、事件 tap、豆包语音触发、延时恢复输入法和结束待编辑文本的焦点切换；HotkeySender 模拟真实硬件事件序列

模块法则:
入口层只编排副作用。配置、状态机和版本策略来自 DoubaoVoiceBridgeCore；入口不得复制版本判断和配置解析逻辑。

[PROTOCOL]: 变更时更新此头部，然后检查 codex.md
