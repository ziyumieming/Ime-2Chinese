# 配置模块（P1）

已实现 Defaults、HotkeySpec 和 ConfigStore：生成用户配置、严格校验、规范化热键及安全保存。用户配置位于 `%AppData%\ImeAssist\settings.ini`；示例在 `config/settings.example.ini`。规则按文件顺序保留，P3 接入匹配。

P5 SettingsModel 提供可读快捷键与字段校验，只将相对窗口基线改变的字段合并到最新有效配置，同字段冲突拒绝；保留规则和旧 RefeedTarget。GUI 仍由 App 应用配置并调用 ConfigStore 保存。Issue #4 已冻结自动切换，相关字段不再提供控件；保存可见偏好时兼容保留旧字段/规则，不创建独立规则文件。
