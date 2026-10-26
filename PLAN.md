# DiaryMaker 开发计划

> 有序里程碑；每阶段可独立验证。产品范围仅「写、存、同步、读」。  
> 约束：`PRIVACY_ARCHITECTURE.md`、`AGENTS.md`；结构：`ARCHITECTURE.md`、`DATA_MODEL.md`、`DESIGN-SPECS.md`。

文档版本：v0.1｜日期：2026-10-26

---

## 总览

| Phase | 名称 | 一句话目标 |
|-------|------|------------|
| **A** | 项目初始化与四平台骨架 | `flutter create` + 最低平台配置，四端 build 可通过 |
| **B** | 加密本地数据库 | SQLCipher + 密钥管理 + CRUD 仓储 |
| **C** | 核心 UI | 时间线 + 编辑器 + 应用锁 |
| **D** | WebDAV 同步引擎 | 客户端 AES-256-GCM + 上下传 + 冲突检测 |
| **E** | 四平台适配与打磨 | 惯用法、响应式、桌面快捷键 |
| **F** | 测试加固 | 单元 + 集成 + 加密层安全测试 |
| **G** | CI/CD 与发布准备 | GitHub Actions 四平台构建 + 隐私合规文件 |

依赖顺序：**A → B → C → D → E → F → G**（E 可与 D 尾部部分并行打磨 UI，但同步功能以 D 完成标准为准）。

每阶段验证命令若因环境无法执行，Agent 须标 `[NOT RUN]` + 原因（见 `AGENTS.md` §3.2），不得声称已通过。

---

## Phase A — Flutter 项目初始化 + 四平台骨架

### 目标

创建 Flutter 工程；Windows / macOS / Android / iOS 目录与最低配置齐全；分层目录占位符合 `ARCHITECTURE.md`（可为空实现）。

### 完成标准（DoD）

- [ ] 仓库内存在可识别的 Flutter 工程（含 `pubspec.yaml`）。
- [ ] 已生成 `android/`、`ios/`、`windows/`、`macos/`。
- [ ] 默认计数器或占位首页可在各目标构建产物中启动（无需业务功能）。
- [ ] 目录占位：`foundation` / `core` / `feature` / `app`（或等价 package）。
- [ ] **未**引入分析/遥测 SDK；**未**引入未加密业务 DB。

### 验证命令

```bash
flutter doctor -v
flutter pub get
flutter build windows
flutter build macos
flutter build apk
flutter build ios --no-codesign
```

> macOS / iOS 命令需在具备对应 SDK 的机器上执行；Windows CI 或开发机若缺某平台，该项标 `[NOT RUN]`。

### 涉及 PRIVACY_ARCHITECTURE 条款

| 条款 | 本阶段如何满足 |
|------|----------------|
| §1 框架与平台 | 仅 Flutter；四端骨架齐全 |
| §2.2 | 不添加遥测依赖 |

---

## Phase B — 加密本地数据库

### 目标

集成 SQLCipher；DB 密钥经平台安全存储；实现 Entry 基础 CRUD 仓储（`core`），接口落在 `foundation` 之上。

### 完成标准（DoD）

- [ ] 选用已确认存在的 SQLCipher 方案（`sqflite_sqlcipher` + `sqlcipher_flutter_libs`，或 drift + SQLCipher）；不确定的包名标 `[DOES NOT EXIST]` 并经人工确认。
- [ ] 密钥不入源码、不入 SharedPreferences 明文（§2.4）。
- [ ] `EntryRepository`：create / read / update / delete 可用（可先无 UI）。
- [ ] 磁盘上 DB 文件无法用普通 SQLite 工具直接读出明文正文。
- [ ] 无 Isar / 未加密 SQLite 作为日记存储。

### 验证命令

```bash
flutter pub get
flutter test test/foundation/  # 或本阶段实际测试路径
flutter test test/core/entry_repository_test.dart
# 可选：在调试构建中写入一条 Entry 后，用外部 sqlite3 打开 DB 文件应失败或不可读正文
```

四端至少在**一个桌面 + 一个移动**目标上验证 DB 可打开（其余标环境限制）。

### 涉及 PRIVACY_ARCHITECTURE 条款

| 条款 | 本阶段如何满足 |
|------|----------------|
| §1 本地数据库 | SQLCipher |
| §2.3 | 若本阶段触及加密原语，仅用审计库 |
| §2.4 | 密钥 → Keystore / Keychain / Credential Manager |

---

## Phase C — 核心 UI

### 目标

时间线列表、日记编辑页、应用锁门禁；状态用 Riverpod；交互符合 `DESIGN-SPECS.md`（空状态、锁定等；同步相关状态可先占位）。

### 完成标准（DoD）

- [ ] 时间线：列出本地 Entry；空状态有引导。
- [ ] 编辑页：新建/编辑/保存走仓储；返回后列表刷新。
- [ ] 应用锁：PIN；Android/iOS 生物识别可用或可降级到 PIN（§2.5）。
- [ ] 未解锁不能浏览正文；回前台可再次要求解锁（策略可配置，默认安全）。
- [ ] 跨页状态经 Riverpod；无用 `setState` 管理日记列表全局态（§1）。

### 验证命令

```bash
flutter test
flutter run -d windows    # 或 macos / 已连接设备
# 手工：设 PIN → 杀进程重启 → 须解锁才见日记
# 移动端手工：生物识别成功/失败降级 PIN
```

### 涉及 PRIVACY_ARCHITECTURE 条款

| 条款 | 本阶段如何满足 |
|------|----------------|
| §1 状态管理 | Riverpod |
| §2.5 | PIN + 移动生物识别 |
| §2.1 | UI 仍不向网络发正文（本阶段可无网络） |

---

## Phase D — WebDAV 同步引擎

### 目标

客户端 AES-256-GCM；上传/下载用户自备 WebDAV；更新 `SyncMeta`；冲突检测与 `conflict_flag`；设置页可配置 WebDAV（见 `DESIGN-SPECS.md`）。

### 完成标准（DoD）

- [ ] 同步前敏感字段均进入密文；抓包/代理可见内容为密文不可读（§2.1）。
- [ ] 加密使用 `cryptography` 或 `pointycastle`，无自研 AES（§2.3）。
- [ ] 仅用户填写的 WebDAV 地址；无强制官方内容服务器。
- [ ] push / pull / 基础冲突检测可用；冲突时 UI 可进入冲突状态。
- [ ] 同步逻辑在 `core`，经 `foundation` 的 cipher 与 WebDAV 接口。

### 验证命令

```bash
flutter test test/core/sync/
flutter test test/foundation/crypto/
# 手工：两台设备或两沙箱，同一 WebDAV，写→同步→他端同步→可读
# 手工：制造冲突 → conflict_flag / UI 冲突态
```

### 涉及 PRIVACY_ARCHITECTURE 条款

| 条款 | 本阶段如何满足 |
|------|----------------|
| §1 同步 | WebDAV + E2E |
| §2.1 | 明文不上云 |
| §2.3 | AES-256-GCM + 审计库 |
| §3 | 与架构数据流一致 |

---

## Phase E — 四平台适配与打磨

### 目标

平台惯用法、响应式布局、桌面键盘快捷键；不扩大功能范围。

### 完成标准（DoD）

- [x] 手机 / 平板 / 桌面宽度断点下，时间线与编辑可完成核心旅程。（`LayoutBreakpoints.splitMinWidth = 720`）
- [x] 桌面：至少支持新建、保存、搜索或列表导航类快捷键（具体表见设计补丁或本阶段 README）。（见 `docs/desktop_shortcuts.md`：Ctrl/⌘S、N、L + ↑↓）
- [x] iOS / Android / Windows / macOS 各自无明显平台违规（如错误安全截图策略可在此收紧）。（移动端 screen_protector + edge-to-edge；桌面 min window；macOS 原生标题栏）
- [x] 无新增遥测；无削弱加密与锁。


### 验证命令

```bash
flutter build windows
flutter build macos
flutter build apk
flutter build ios --no-codesign
# 手工：各平台走完 写→存→同步→读；桌面快捷键清单勾选
```

### 涉及 PRIVACY_ARCHITECTURE 条款

| 条款 | 本阶段如何满足 |
|------|----------------|
| §1 四端覆盖 | 构建与体验均覆盖 |
| §2.5 | 锁在各平台行为正确 |

---

## Phase F — 测试加固

### 目标

单元测试、集成测试、加密层安全测试达到可发布门槛。

### 完成标准（DoD）

- [ ] 仓储、同步合并、冲突、密钥错误路径有单元测试。
- [ ] 至少一条集成测试覆盖「保存 →（模拟）同步信封加解密 → 再读」。
- [ ] 加密层：错误 nonce/密钥失败；密文篡改检测（GCM tag）。
- [ ] 确认无测试夹具把明文密钥提交进仓库。

### 验证命令

```bash
flutter test
flutter test integration_test/  # 若已添加
```

### 涉及 PRIVACY_ARCHITECTURE 条款

| 条款 | 本阶段如何满足 |
|------|----------------|
| §2.1–§2.4 | 用测试锁定红线不被回归破坏 |
| §2.3 | 安全测试针对 AES-GCM 行为 |

---

## Phase G — CI/CD 与发布准备

### 目标

GitHub Actions（或等价）四平台构建；隐私合规文件齐套；发布清单可执行。

### 完成标准（DoD）

- [x] CI 对可用 runner 执行分析/测试/构建；缺平台的 job 明确标记而非默默跳过无说明。（`.github/workflows/build.yml`：ubuntu APK / windows / macos+ios；每 job 先 `flutter test` 再 build）
- [x] 仓库含隐私说明（可引用 `PRIVACY_ARCHITECTURE.md`）与用户可见的「无追踪、WebDAV 自备」说明。（`PRIVACY_POLICY.md`、`ios/Runner/PrivacyInfo.xcprivacy`、`docs/google_play_data_safety_guide.md`）
- [x] 发布产物不含调试后门、固定测试密钥。（见 `docs/release_checklist.md` §5；上架前须人工复勾）
- [x] 依赖清单可审计；无 §2.2 禁用 SDK。


### 验证命令

```bash
# 本地
flutter test
flutter build apk
# CI：在 GitHub Actions 界面确认 workflow 绿灯；本地无法代替时标 [NOT RUN] 并附 run URL
```

### 涉及 PRIVACY_ARCHITECTURE 条款

| 条款 | 本阶段如何满足 |
|------|----------------|
| §2.2 | CI 依赖扫描/人工清单确认无遥测 |
| §4 自检清单 | 发布前完整勾选 |
| §1 | 四端构建流水线 |

---

## 阶段门禁（通用）

进入下一 Phase 前：

1. 本 Phase DoD 全部勾选或书面豁免（豁免不得违反隐私红线）。  
2. 验证命令已执行或已 `[NOT RUN]` 备案。  
3. 变更摘要已按 `AGENTS.md` §3.3 输出并标注条款号。

---

## 相关文档

- `ARCHITECTURE.md` — 分层与数据流  
- `DATA_MODEL.md` — Entry / SyncMeta  
- `DESIGN-SPECS.md` — UI 状态机  
- `PRIVACY_ARCHITECTURE.md` — 条款正文  
