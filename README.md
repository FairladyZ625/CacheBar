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

## 通知授权与 ad-hoc 签名

ad-hoc 签名在每次重新打包后都会变化，本机实测（macOS 26）：重打包后的应用请求通知授权时，系统直接返回错误（stderr 可见 `Notifications are not allowed for this application`），不再弹出授权弹窗，旧构建上点过的「允许」也不会沿用到新构建。所以重新打包后若收不到通知，去 系统设置 → 通知 里重新给 CacheBar 授权（面板底部状态区的「打开系统设置」按钮可直接跳转）；授权状态与最近一次失败原因都会显示在状态区里，不用翻日志。

## License

[MIT](LICENSE)
