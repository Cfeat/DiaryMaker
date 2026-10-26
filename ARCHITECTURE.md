# DiaryMaker 分层架构

> 产品范围：本地优先私密日记。唯一核心旅程为「写 → 本地加密存 → 用户自备 WebDAV 同步 → 他端解密读」。  
> 不含社交、AI 分析、社区、官方云服务端。  
> 技术与隐私硬约束见 `PRIVACY_ARCHITECTURE.md`；Agent 规则见 `AGENTS.md`。

文档版本：v0.1｜日期：2026-10-26

---

## 1. 四层概览

```
┌─────────────────────────────────────────┐
│  app          各平台入口、路由、主题壳   │
├─────────────────────────────────────────┤
│  feature      日记编辑 / 时间线 / 设置   │
├─────────────────────────────────────────┤
│  core         仓储、同步引擎、领域用例   │
├─────────────────────────────────────────┤
│  foundation   加密、存储接口、平台适配   │
└─────────────────────────────────────────┘
```

| 层 | 职责 | 典型内容 |
|----|------|----------|
| **foundation** | 无业务语义的基础设施 | SQLCipher 打开/关闭、平台安全存储读写、AES-256-GCM 封装、WebDAV 传输接口、路径与文件 I/O 抽象 |
| **core** | 领域与应用服务 | Entry 仓储、SyncMeta 仓储、同步引擎（加密→上传 / 下载→解密→合并）、冲突检测、访问锁策略编排 |
| **feature** | 面向用户的功能 UI + 该功能内 Riverpod | 时间线、编辑器、同步设置、应用锁门禁页 |
| **app** | 组装与平台入口 | `main.dart`、各平台 runner、全局 ProviderScope、路由表、未登录锁门路由守卫 |

---

## 2. 依赖方向（禁止反向依赖）

**唯一允许方向：上层 → 下层。**

```
app  →  feature  →  core  →  foundation
```

| 规则 | 说明 |
|------|------|
| foundation 不依赖任何上层 | 不得 `import` core / feature / app |
| core 只依赖 foundation | 不得依赖 feature / app；不得直接引用 Widget |
| feature 只依赖 core（及 foundation 的公开类型若确需） | 优先经 core 暴露的 API；禁止 feature 之间隐式循环依赖（跨 feature 经 core 或显式共享契约） |
| app 依赖 feature（及必要时 core） | 负责注入 foundation 的平台实现到 core |

**禁止：**

- feature / app 直接操作 SQLCipher 或原始 WebDAV HTTP（必须经 core）
- core 调用 UI（SnackBar、Navigator 等）
- 为图省事把同步加密逻辑写在 feature 页内

状态管理：跨页面 / 全局状态使用 **Riverpod**（`PRIVACY_ARCHITECTURE` §1）；页面内短暂 UI 态可用局部状态，但不得以此管理跨页日记数据。

---

## 3. 包 / 目录映射（建议）

实现阶段可采用 Dart 多 package 或单仓目录分层；逻辑边界必须与下表一致。

```
lib/
  foundation/     # 或 packages/foundation
  core/
  feature/
    timeline/
    editor/
    settings_sync/
    app_lock/
  app/
```

具体包名以 Phase A 初始化为准；若拆 package，依赖图仍须满足 §2。

---

## 4. 数据流：一篇日记从输入到 WebDAV

对应产品旅程与 `PRIVACY_ARCHITECTURE` §3。字段加密边界见 `DATA_MODEL.md`。

### 4.1 写 → 本地落盘

```
[编辑页 feature]
   │  用户输入 title / content / mood / tags / 附件
   ▼
[core: EntryRepository.save]
   │  组装 Entry 领域对象；attachments 落本地加密文件
   ▼
[foundation: EncryptedDatabase]
   │  SQLCipher 整库加密写入（密钥 ← 平台安全存储，§2.4）
   ▼
[本地磁盘：加密 DB + 加密附件文件]
```

内存中短暂存在明文仅限于编辑会话与仓储映射；不得写入未加密偏好存储。

### 4.2 本地 → 同步上传

```
[设置页 / 自动同步触发 feature]
   ▼
[core: SyncEngine.push]
   │  读取待同步 Entry + SyncMeta
   │  序列化为同步载荷（含敏感字段）
   ▼
[foundation: AesGcmCipher]          ← cryptography / pointycastle（§2.3）
   │  AES-256-GCM 客户端加密 → 密文 blob
   ▼
[foundation: WebDavClient]
   │  PUT/PROPFIND 等仅传输密文（§2.1）
   ▼
[用户自备 WebDAV 服务器]            ← 只接触密文
   │
   ▼
[core: 更新 SyncMeta]
      last_sync_at / remote_etag / local_version / conflict_flag
```

### 4.3 他端：下载 → 解密 → 阅读

```
[用户自备 WebDAV]
   ▼
[foundation: WebDavClient]  GET 密文
   ▼
[foundation: AesGcmCipher]  解密（密钥不离开客户端）
   ▼
[core: SyncEngine.merge]    对比 SyncMeta；冲突则设 conflict_flag
   ▼
[foundation: EncryptedDatabase]  写入本机 SQLCipher
   ▼
[feature: 时间线 / 编辑页]   解锁后（§2.5）展示解密后的可读内容
```

### 4.4 访问锁门禁（横切）

```
[app 启动 / 回前台]
   ▼
[feature: AppLock]  PIN 或（移动端）生物识别
   │  未解锁 → 不进入时间线/编辑，不在 UI 缓存日记明文（§2.5）
   ▼
[已解锁] → feature 正常读写 core
```

---

## 5. 明确不在架构内的能力

| 不做 | 原因 |
|------|------|
| 官方内容云 / 账号体系代管正文 | §2.1 |
| 社交、评论、关注 | 产品范围外 |
| AI 分析日记、情绪云端推断 | 产品范围外 + 易触碰明文上云 |
| 分析 / 崩溃遥测 SDK | §2.2 |

---

## 6. 相关文档

| 文档 | 内容 |
|------|------|
| `PRIVACY_ARCHITECTURE.md` | 技术栈与隐私红线 |
| `DATA_MODEL.md` | Entry / SyncMeta 与加密字段 |
| `PLAN.md` | Phase A–G 里程碑 |
| `DESIGN-SPECS.md` | 核心界面交互与状态 |
| `AGENTS.md` | Agent 诚实性与变更摘要 |
