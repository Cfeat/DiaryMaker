# DiaryMaker 隐私与技术架构约束

> 本文档为不可协商的基线。任何功能、依赖或同步方案若与本文冲突，以本文为准并拒绝合入。
> 文档版本：初稿 v0.1｜日期：2026-10-26

---

## 1. 技术栈（强制）

| 领域 | 允许 | 禁止 |
|------|------|------|
| 跨平台框架 | **Flutter（Dart）** | React Native、Tauri、Electron、Kotlin Multiplatform UI 等其他跨平台方案 |
| 目标平台 | Windows、macOS、Android、iOS（四端必须全部覆盖） | 仅单端或省略任一目标平台的交付 |
| 本地数据库 | SQLite + **库级加密**；统一方案：**drift + `package:sqlite3`（SQLite3MultipleCiphers / SQLCipher 兼容）**。禁止依赖已 EOL 的 `sqlcipher_flutter_libs`。备选（仅移动为主）：`sqflite_sqlcipher` | 未加密 SQLite、Isar、Hive（明文）、ObjectBox 等未满足库级加密要求的方案 |
| 状态管理 | **Riverpod** | 用 `setState` 管理跨页面 / 全局状态 |
| 同步 | 用户自备 **WebDAV** + 客户端 **端到端加密（AES-256-GCM）** | 自建明文同步 API、第三方日记云且服务端可读内容 |

---

## 2. 隐私红线（不可协商）

### 2.1 明文不上云

- 日记正文、附件元数据中的敏感字段、解密后的同步载荷，**绝不以明文**上传至任何服务器。
- 同步后端**仅**接受用户自行配置的 WebDAV 地址；应用不得绑定强制官方内容同步服务器。
- 服务器侧（含用户自建 WebDAV）在设计上**只能接触密文**；加密与解密均在客户端完成。

### 2.2 禁止分析 / 追踪 / 遥测

禁止引入任何分析、崩溃上报、行为追踪类 SDK，包括但不限于：

- Firebase Analytics / Crashlytics
- Sentry
- Umeng（友盟）及同类国内统计 SDK
- 其他遥测、广告归因、会话回放 SDK

允许：本地日志（默认关闭或仅调试构建）、用户主动导出的诊断信息（须经用户明确操作且不含日记明文，除非用户自行选择包含）。

### 2.3 密码学实现

- 必须使用经过审计、社区广泛使用的密码学库，例如：
  - Dart `cryptography` 包
  - `pointycastle`
- **禁止**自行实现 AES、GCM、密钥派生或其他加密算法。
- 同步载荷加密算法约定：**AES-256-GCM**（客户端 E2E）。

> 若拟引入的包名 / API 不确定是否真实存在，必须在设计或 PR 中标注 `[DOES NOT EXIST]`，并待人工确认后再依赖。

### 2.4 本地数据库密钥

- SQLCipher 所用密钥必须通过平台安全能力**派生或保存**：
  - Android：Android Keystore
  - iOS：iOS Keychain
  - Windows：Windows Credential Manager
  - macOS：macOS Keychain
- **禁止**：密钥硬编码；密钥明文写入源码、配置文件或 SharedPreferences / 等价明文偏好存储。

### 2.5 本地访问锁

- 应用必须提供本地访问锁。
- 全平台：支持 **PIN 码**。
- 移动端（Android / iOS）：额外支持生物识别（指纹 / Face ID 等平台能力）。
- 解锁失败与锁定策略应避免将日记明文暴露在锁屏前后的界面缓存中（实现细则在后续安全设计中补充）。

---

## 3. 同步与数据流（摘要）

```
[用户输入 / 本地明文]
        │
        ▼
[SQLCipher 加密库]  ←── 密钥来自平台安全存储
        │
        ▼
[导出 / 同步前：AES-256-GCM 客户端加密]
        │
        ▼
[用户自备 WebDAV]  ←── 仅密文
```

- 读路径：WebDAV 拉取密文 → 客户端解密 → 写入本地 SQLCipher 库（或内存短暂明文，用完即清）。
- 写路径：本地变更 → 客户端加密 → 上传 WebDAV。

---

## 4. 合规自检清单（变更前）

- [ ] 是否引入未加密本地存储？
- [ ] 是否有任何网络路径可能带上日记明文？
- [ ] 是否新增分析 / 遥测 SDK？
- [ ] 加密是否仍走审计库 + AES-256-GCM？
- [ ] DB 密钥是否仍仅存于平台安全存储？
- [ ] PIN / 生物识别访问锁是否仍可用？
- [ ] 四端（Win / macOS / Android / iOS）是否都被该变更覆盖或明确标注暂不支持并阻塞发布？

---

## 5. 与 AGENTS.md 的关系

实现与 Agent 协作时的行为规则见根目录 `AGENTS.md`。涉及隐私与技术选型争议时，**以本文件条款编号为准**（例如「违反 PRIVACY_ARCHITECTURE §2.1」）。
