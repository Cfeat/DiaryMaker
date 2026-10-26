# DiaryMaker — Agent 行为规则

> 面向在本仓库中协作的 AI / 自动化 Agent。与 `PRIVACY_ARCHITECTURE.md` 一并遵守；隐私与技术栈冲突时以 `PRIVACY_ARCHITECTURE.md` 为准。

---

## 1. 必须先读的文档

在编写或建议任何业务代码之前：

1. 阅读并遵守 `PRIVACY_ARCHITECTURE.md`（技术栈 + 隐私红线）。
2. 遵守本文档的诚实性与变更摘要要求。

---

## 2. 技术栈与隐私（摘要，细节见 PRIVACY_ARCHITECTURE）

- **框架**：仅 Flutter（Dart）；禁止 React Native、Tauri 等。
- **平台**：Windows、macOS、Android、iOS 全覆盖。
- **数据库**：SQLite + SQLCipher（`sqflite_sqlcipher` + `sqlcipher_flutter_libs`，或 drift + SQLCipher）；禁止未加密 SQLite、Isar。
- **状态**：Riverpod；禁止用 `setState` 管理跨页面状态。
- **同步**：WebDAV + 客户端 AES-256-GCM E2E；服务器仅密文。
- **红线**：明文日记不上云；无分析/遥测 SDK；只用审计密码学库；DB 密钥进平台安全存储；本地 PIN + 移动端生物识别。

---

## 3. 诚实性规则（不可省略）

### 3.1 不发明 API / 包 / 配置

- 不得捏造不存在的 API、包名、pub.dev 包、平台配置项或 Flutter 插件能力。
- 若对某包或 API **不确定是否存在**：必须写出 **`[DOES NOT EXIST]`**，并建议维护者人工确认后再采用。
- 不得把「可能存在」写成既成事实。

### 3.2 不虚报测试 / 构建结果

- **不得**声称测试或构建已通过，除非 Agent **实际运行了**相应命令。
- 若无法运行：写出 **`[NOT RUN]`** + 简短原因（例如：环境无 Flutter SDK、无目标设备、用户未授权联网安装依赖等）。

### 3.3 变更摘要（每次代码变更后必须输出）

每次对仓库产生代码或配置变更后，在回复中输出摘要，至少包含：

| 项 | 说明 |
|----|------|
| 改了哪些文件 | 路径列表 |
| 为什么改 | 目的 / 问题 |
| 涉及条款 | 对应 `PRIVACY_ARCHITECTURE.md` 的章节编号（如 §2.1、§2.4）；若无关隐私则写「无（非隐私相关）」 |

纯文档 clarifications 可注明「仅文档，无业务代码」。

---

## 4. 禁止事项（Agent 侧）

- 引入分析、追踪、遥测 SDK。
- 建议或实现「官方代管明文日记」的同步方案。
- 自行实现 AES 或其他加密算法。
- 将加密密钥硬编码或写入 SharedPreferences 等明文存储。
- 在未确认包存在的情况下直接写入 `pubspec.yaml` 依赖并当作可用。

---

## 5. 推荐工作顺序

1. 对照 `PRIVACY_ARCHITECTURE.md` 做方案 / PR 自检。
2. 不确定的依赖 → `[DOES NOT EXIST]` → 等人确认。
3. 实现 → 实际运行可运行的检查 → 否则 `[NOT RUN]`。
4. 输出变更摘要（文件 / 原因 / 条款）。
