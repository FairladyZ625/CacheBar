# CacheBar 签名与通知授权

CacheBar 使用 macOS 本机通知。macOS 会把通知授权与应用签名身份关联；ad-hoc 签名会随每次构建改变，因此重打包后的应用可能无法沿用之前的通知授权。本机曾观察到系统拒绝新 ad-hoc 构建的授权请求且不再弹窗。

## 三种签名选择

| 方式 | 适用场景 | 结果 |
| --- | --- | --- |
| ad-hoc | 快速试用、CI、无需稳定通知授权 | 无证书；每次构建身份不同，通知授权可能丢失；不公证。 |
| 本地自签名 | 本机持续使用与源码构建 | 固定本地身份，重复构建可沿用授权；仅本机信任范围，不公证。首次使用新身份构建仍需在系统设置授权通知。 |
| Apple 开发者证书 | 正式分发 | 由开发者证书签名，可按发行流程公证与分发；需要 Apple Developer 账户与证书。 |

## 建立本地身份

在项目根目录运行：

```sh
scripts/setup-signing.sh
```

脚本会先说明操作并等待确认。它在临时目录生成有效期十年的自签名证书，仅包含数字签名与 Code Signing 用途，然后导入登录钥匙串，并把私钥访问限制为 `/usr/bin/codesign`。临时私钥、PKCS#12 文件和随机口令会在退出时清理。可用 `--yes` 跳过确认；身份已存在时脚本直接报告并成功退出。脚本通过不带 `-v` 的 `security find-identity` 查找身份，因为自签名身份在未调整信任设置时可能显示 `CSSMERR_TP_NOT_TRUSTED`，不会被 `-v` 列出；这是预期状态，不影响 `codesign` 使用身份。

之后执行 `scripts/build-app.sh`，脚本依次采用 `CACHEBAR_SIGN_IDENTITY` 环境变量、钥匙串中的 `CacheBar Local Signing`，或在都不可用时回退 ad-hoc 并提示本页。也可显式设置 `CACHEBAR_SIGN_IDENTITY=-` 选择 ad-hoc。

亲自核验时，可运行 `security find-identity "$(security login-keychain | tr -d '\"')"` 查看登录钥匙串身份。若该行带有 `CSSMERR_TP_NOT_TRUSTED`，这是未修改系统信任设置时的预期显示；不妨碍使用固定身份签名。

新身份第一次构建后，前往“系统设置 → 通知”并允许 CacheBar 通知。通知授权界面由 macOS 管理。

## 撤销

运行 `scripts/setup-signing.sh --remove`，确认后从登录钥匙串删除该身份及私钥。此操作不改系统信任设置。删除身份后再次构建会使用 ad-hoc 签名，除非提供另一个 `CACHEBAR_SIGN_IDENTITY`。
