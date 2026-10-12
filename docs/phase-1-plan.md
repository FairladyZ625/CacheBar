# CacheBar 一阶段计划

状态：已确认（2026-10-12）。任务与决策以 Harness 台账为准。

## 目标

一个常驻 macOS 菜单栏的原生 Swift 应用，让我在缓存过期前知道并来得及续上。
一阶段只做 Claude Code，本机通知；多 agent 聚合、用量统计、手机推送放二阶段。

## 已核实的前提（2026-10-12 本机）

| 前提 | 证据 |
|---|---|
| 每条 assistant 消息带缓存用量与时间戳 | `~/.claude/projects/<proj>/<session>.jsonl` 的 `message.usage`：`cache_read_input_tokens`、`cache_creation_input_tokens`、`cache_creation.ephemeral_1h_input_tokens` / `ephemeral_5m_input_tokens`，外层 `timestamp`、`sessionId`、`cwd`、`isSidechain` |
| TTL 档位可从数据判断，不必写死 1 小时 | 同上，`ephemeral_1h` 与 `ephemeral_5m` 分开计数 |
| 额度、上下文、花费由 statusline 输入提供 | 现有 `~/.claude/statusline-command.sh` 已从 stdin JSON 读 `context_window.*`；transcript 里没有额度字段 |
| 无 Xcode 证书也能构建 | CLT 自带 Swift 6.2.3 与 `MacOSX26.2.sdk`，`swift build` + 手工组 `.app` + ad-hoc 签名；`xcodebuild` 当前不可用（xcode-select 指向 CLT，`/Applications/Xcode-beta.app` 存在） |
| 液态玻璃可用 | 系统 macOS 27.2，SDK 26.2 含 `glassEffect` |
| Codex 数据形状（二阶段用） | `~/.codex/sessions/**/rollout-*.jsonl` 的 `token_count` 事件含 `cached_input_tokens`、`model_context_window`、`rate_limits.primary.{used_percent,resets_at}` |

未核实，一阶段第一个任务要测：

- statusline stdin JSON 里 `rate_limits`（5h / 7d 百分比与重置时间）和 `cost` 的确切字段名。
- 网上有说法称 stdin 还带 `prompt_cache.{warm,ttl,expires_at}`；若属实，过期时间直接取它，transcript 推算作兜底。

## 过期时间口径（已确认）

需求写的是“按最后一次缓存写入时间算”。但缓存**命中读取也会刷新 TTL**，所以按写入时间算会偏早报警。
采用口径：过期时刻 = 该会话最后一次触碰缓存的请求时间（读或写）+ 该次写入的 TTL 档位。
主会话与 subagent（`isSidechain`）缓存各自独立，一阶段只对主会话倒计时。

## 数据流

```
Claude Code ──statusline stdin──> statusline-command.sh ──追加一行 tee──> ~/Library/Application Support/CacheBar/sessions/<session_id>.json
Claude Code ──写 transcript──────> ~/.claude/projects/**/<session_id>.jsonl
                                              │
                         CacheBar（FSEvents 监听两处，增量读 jsonl 尾部）
                                              │
                    SessionStore ──> 菜单栏标题 / 玻璃弹窗 / UNUserNotificationCenter
```

不读取任何 OAuth 凭据，不发网络请求。

## 界面

- 菜单栏标题（宽度有限）：最紧急会话的 `命中率 · 缓存倒计时`，临近过期变色。
- 点击弹出玻璃面板，每个活跃会话一行，从左到右：
  本轮缓存命中率 → 缓存过期倒计时 → 5h 额度 % + 重置倒计时 → 7d 额度 % + 重置倒计时 → 上下文大小 → 本次会话花费。
- 每行附“过期后重建成本”估算（上下文 token × 1h 缓存写入单价），直接回答“值不值得去续一下”。
- 活跃会话 = transcript 最近有写入且缓存未过期；过期的折叠到底部。

命中率口径：`cache_read / (cache_read + cache_creation + input)`，取本轮最后一次请求。

## 通知

- 本机 `UNUserNotificationCenter`，每会话在过期前 10 分钟和 2 分钟各一条（阈值可调），会话有新请求即撤销重排。
- 点通知跳到对应会话的终端目录（一阶段只做到打开 cwd）。

## 任务切分

| # | 任务 | 交付与验收 |
|---|---|---|
| T1 | statusline 字段实测 + 落盘桥 | dump 一份真实 stdin JSON；在 statusline 脚本加一行落盘（改动前给业主看 diff）；确认额度/花费/`prompt_cache` 字段 |
| T2 | SwiftPM 骨架 + 打包脚本 | `swift build` 出菜单栏图标；脚本组 `.app`、ad-hoc 签名、可登录自启 |
| T3 | Claude Code 适配器 + SessionStore | 增量解析 transcript，算命中率、TTL 档位、过期时刻；用真实 jsonl 做夹具的单元测试 |
| T4 | 菜单栏标题 + 玻璃面板 | 六项指标按序显示，倒计时每秒走；CEO 截图亲验 |
| T5 | 过期通知 | 用缩短 TTL 的夹具验证：到点响、续上后撤销 |
| T6 | 一周自用收口 | 倒计时与实际 `cache_read` 是否为 0 对账，修口径 |

T1、T2 可并行；T3 依赖 T1 的字段结论；T4、T5 依赖 T3。
适配器从 T3 起按协议写（`AgentAdapter`：发现会话 → 产出统一 `SessionSnapshot`），二阶段加 Codex 不用动 UI。

## 二阶段（不在本期）

- Codex、Antigravity、ZCode 适配器（Codex 数据形状已核实，另两个待查）。
- 用量统计：按天 / 按项目 / 按模型的 token 与花费。
- 过期前自动压缩（设置里开启，默认关）：上下文超过可调阈值（如 300K）且临近过期仍未动的会话，自动触发压缩；先做可行性调研，同时评估更轻的“保活”方案。
- 手机推送：没有 Apple 开发者证书做不了自有 APNs，走 Bark 或 ntfy 这类自带推送通道的 App，CacheBar 只发一个 HTTP 请求。

## 同类项目（参考，不照搬）

- steipete/CodexBar：Swift 菜单栏，多 provider 额度与重置时间；不做缓存过期。
- leeguooooo/claude-code-usage-bar：终端 statusline 里有缓存倒计时，无菜单栏、无通知。
- sirmalloc/ccstatusline：statusline 额度与重置计时。

“菜单栏 + 缓存过期通知”这个组合目前没找到现成的。
