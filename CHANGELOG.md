# Changelog

## v1 - 2026-05-27

**定时更新功能**

- 添加 `needs_update` 全局标志位，`on_time` 触发时设置
- `on_boot` 检测 `needs_update` 决定是否刷新屏幕
- 定时配置：每天 7:00、12:00、18:00~22:00 每小时更新
- `deep_sleep` 改为每 5 分钟自动唤醒一次

Backup: versions/v1.yaml

## v0 - 2026-05-27

**初始版本**

- 基础墨水屏显示：天气 + 待办 + 日程
- `deep_sleep` + GPIO2 按键唤醒
- 无主动更新机制，必须按键唤醒

Backup: versions/v0.yaml
## v2.yaml (2026-05-28 09:28)

- **测试备份脚本**
  - 备份自 v1

## v3.yaml (2026-05-28 09:37)

- **添加日志调试**
  - 备份自 v2
