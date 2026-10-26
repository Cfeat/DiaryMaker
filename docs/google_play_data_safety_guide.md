# Google Play Data Safety 填写指南

> 封面标题：Google Play 数据安全表单填写指南  
> 依据：当前仓库实现（`lib/`、`pubspec.yaml`、Android 清单），**不是**理想假设。  
> 对照：`PRIVACY_ARCHITECTURE.md` §2.1 / §2.2 / §2.4。  
> 日期：2026-10-26｜应用包名：`app.privatenote.diary`

---

## 0. 先核对事实（证据）

| 事实 | 证据 | 对表单的含义 |
|------|------|--------------|
| 无分析 / 崩溃 / 广告 SDK | `pubspec.yaml` 无 Firebase Analytics、Sentry、友盟等；`PRIVACY_ARCHITECTURE` §2.2 | 不勾选广告、分析、开发者通讯类收集 |
| 日记正文本地库级加密 | SQLCipher / sqlite3mc；密钥经 `flutter_secure_storage` | 设备上存储的日记不是明文落盘偏好项 |
| 无官方日记服务器 | 同步仅用户配置的 WebDAV（`SyncEngine` + `webdav_plus`） | 开发者**不**运营内容云；不接收日记明文 |
| 同步载荷为客户端 AES-256-GCM | `cryptography`；上传前密封 | WebDAV 侧仅为密文；开发者若未持有用户密钥则无法解密 |
| 生物识别仅本机解锁 | `local_auth` + `USE_BIOMETRIC`；无生物特征上传代码 | **不**申报为向开发者收集的生物识别数据 |
| PIN / WebDAV 密码进安全存储 | `AppLockService`、`SyncCredentialsStore` → secure storage | 凭证不进 SharedPreferences 明文 |
| 网络权限 | `AndroidManifest.xml`：`INTERNET`（可选同步） | 有网络能力 ≠ 向开发者收集；仅在用户开启同步时访问其 WebDAV |
| Release 仍用 debug 签名 | `android/app/build.gradle.kts` `signingConfig = debug` | **上架前必须换成正式密钥**（与 Data Safety 无关，但阻塞发布） |

`lib/` 内未发现 `print` / `debugPrint` 或硬编码生产密钥（抽查日期同上）。测试里的假密码仅存在于 `test/`。

---

## 1. 总览问题（建议答法）

### 1.1 Does your app collect or share any of the required user data types?

**建议：选 Yes，并只申报「用户开启同步时」离开设备的数据类别。**

理由（诚实）：Play 将「从应用传到用户设备外」视为 *collect*。用户启用 WebDAV 同步时，密封后的日记密文会传到**用户自己填写的** WebDAV 主机。这不是「开发者服务器收集」，但仍属离设备传输，不宜在开启同步的产品上勾「完全不收集」而回避说明。

若你**强制关闭同步功能**并从商店包中移除 WebDAV 代码路径，才可再评估「No」；当前代码包含同步，故按 Yes + 加密/自备服务器说明填写。

### 1.2 Is all of the user data collected by your app encrypted in transit?

**Yes**（HTTPS/TLS 由用户 WebDAV 端点与 HTTP 客户端决定；同步载荷另有应用层 AES-256-GCM）。表单备注中写明：应用层 E2E + 期望 WebDAV 使用 HTTPS。

### 1.3 Do you provide a way for users to request that their data is deleted?

**Yes（有限）**：用户可在应用内删除本地条目；同步删除依赖客户端删除远程密文对象。开发者**无法**代删用户 WebDAV 上的文件（无账号、无托管）。隐私政策中应写清：删除本地 + 用户自行清理 WebDAV。

---

## 2. 数据类别勾选建议

仅勾与实现一致的项；未列出的类别一律 **不收集**。

### 2.1 Personal info / Financial / Health / Messages / Photos / Files / Calendar / Contacts / App info and performance / Device or other IDs

**不勾选**（当前实现无账户体系、无通讯录/相册读取、无崩溃上报、无广告 ID 采集）。

### 2.2 User-generated content（用户生成内容）

| 字段 | 建议 |
|------|------|
| 是否收集 | **Yes**（仅当用户配置并启用 WebDAV 同步） |
| 是否分享给第三方 | **No**（开发者不转发；用户自选服务器不属于「我们分享给第三方」） |
| 是否为处理必需 / 加密 | 勾选 **Encrypted in transit**；说明另有客户端 AES-256-GCM，开发者不可解密 |
| 用途 | **App functionality**（多设备同步） |
| 是否可选 | **Yes** — 不同步则日记仅存本机 |

说明文案示例（可粘贴到 Play Console「数据使用说明」）：

> Diary entries are stored encrypted on the device. If the user enables WebDAV sync, ciphertext only is uploaded to a server URL the user provides. The developer does not operate a content server and cannot read diary plaintext.

### 2.3 Other：App activity / Crash logs / Diagnostics

**不勾选**（无遥测 SDK；无自动上传诊断）。

### 2.4 Biometrics

**不勾选为「收集」**。Face ID / 指纹仅用于本机解锁（`local_auth`）；生物模板由系统管理，应用不上传。

---

## 3. 安全实践勾选

| 问题 | 建议 |
|------|------|
| Data is encrypted in transit | Yes |
| Users can request data deletion | Yes（见 §1.3 限制） |
| Committed to Play Families / 面向儿童 | 按实际受众；日记应用通常 **不是** 专为儿童设计 |
| Independent security review | 当前 **No**（除非已完成外部审计） |

---

## 4. 上架前再扫一遍（防「按假设填写」）

1. `rg -i "firebase|sentry|analytics|umeng|telemetry|crashlytics" pubspec.yaml lib` → 应无业务命中。  
2. 确认商店包 **未** 打开「官方代管明文同步」。  
3. 用正式签名 AAB 的合并 Manifest 确认仍只有预期权限（`INTERNET`、`USE_BIOMETRIC` 等）。  
4. 隐私政策 URL 与本文、仓库 `PRIVACY_POLICY.md` 表述一致后再提交表单。

---

## 5. 与隐私政策的关系

公开政策见仓库根目录 [`PRIVACY_POLICY.md`](../PRIVACY_POLICY.md)。Play Console「隐私政策」链接必须指向**已公网可访问**的同一内容副本（GitHub Pages / 静态站均可），勿只放仓库私有路径。
