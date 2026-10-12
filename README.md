# CacheBar

常驻 macOS 菜单栏的 coding agent 会话监视器，原生 Swift。

Prompt 缓存过期后重新写入很贵。CacheBar 盯着每个活跃会话的缓存，在过期前提醒你续上。

每个会话从左到右显示：本轮缓存命中率、缓存过期倒计时、5 小时额度与重置倒计时、7 天额度与重置倒计时、上下文大小、本次会话花费。

状态：开发中，尚无可用版本。一阶段只支持 Claude Code 和本机通知，计划见 [docs/phase-1-plan.md](docs/phase-1-plan.md)。

## License

[MIT](LICENSE)
