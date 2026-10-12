# CacheBar

常驻 macOS 菜单栏的 coding agent 会话监视器，原生 Swift。

Prompt 缓存过期后重新写入很贵。CacheBar 盯着每个活跃会话的缓存，在过期前提醒你续上。

每个会话从左到右显示：本轮缓存命中率、缓存过期倒计时、5 小时额度与重置倒计时、7 天额度与重置倒计时、上下文大小、本次会话花费。

状态：开发中，尚无可用版本。一阶段只支持 Claude Code 和本机通知，计划见 [docs/phase-1-plan.md](docs/phase-1-plan.md)。

## 从源码构建

需要 macOS 26+ 与 Swift 6.2+（Xcode 26 或 Command Line Tools 皆可）。

```bash
swift build && swift test   # 构建三个 target 并跑单元测试
scripts/build-app.sh        # 组出 dist/CacheBar.app 并 ad-hoc 签名
open dist/CacheBar.app      # 菜单栏出现图标，Dock 不出现
```

没有 Apple 开发者证书：脚本只做 `codesign -s -` ad-hoc 签名，不公证；首次启动若被 Gatekeeper 拦，在 Finder 里右键 → 打开。

## License

[MIT](LICENSE)
