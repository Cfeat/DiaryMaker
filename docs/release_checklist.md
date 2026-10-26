# 发布前手动检查清单

> 封面标题：发布前手动检查清单  
> Phase G3｜对照 `PRIVACY_ARCHITECTURE.md` §2 / §4 与商店要求  
> 日期：2026-10-26  

勾选表示**已人工确认**。未完成项视为阻塞商店提交。

---

## 1. 四平台构建产物

| 平台 | 预期产物 | 本地路径 / CI Artifact | 完成 |
|------|----------|------------------------|------|
| Android | Release APK（或上架用 AAB） | `build/app/outputs/flutter-apk/app-release.apk`；CI：`android-release-apk` | [ ] |
| Windows | Release 目录 | `build/windows/x64/runner/Release/`；CI：`windows-release` | [ ] |
| macOS | Release 应用包 | `build/macos/Build/Products/Release/`；CI：`macos-release` | [ ] |
| iOS | Release（无签名）产物 | `build/ios/iphoneos/`；CI：`ios-release-unsigned`（正式上架需另行 codesign / Archive） | [ ] |

补充：

- [x] `main` 分支 GitHub Actions workflow **Build** 已跑通四端（含 Windows MSVC 修复后）；产物见 Actions Artifacts。
- [ ] iOS 商店包已用正式证书与 Provisioning Profile 签名（CI 的 `--no-codesign` **不能**直接上架）。
- [x] Android **已移除** debug 签名回退；release 必须提供 `android/key.properties` + keystore（见 `docs/android_signing.md`）。Play 上架请用正式密钥打 AAB。

---

## 2. 隐私政策 URL

- [x] `PRIVACY_POLICY.md` 已写入公开 URL 与 GitHub Issues 联系入口。
- [x] 隐私政策已部署到公网 HTTPS：https://cfeat.github.io/DiaryMaker/privacy/（已测 HTTP 200）。
- [ ] App Store Connect / Google Play Console 中的「隐私政策」链接与上述 URL 一致。
- [x] 政策正文仍诚实反映：数据在本机 + 用户自备 WebDAV；开发者不接触日记明文；同步为客户端 AES-256-GCM E2E。

---

## 3. iOS 用途描述字符串（Usage Descriptions）

当前 `ios/Runner/Info.plist`：

| Key | 现状 | 完成 |
|-----|------|------|
| `NSFaceIDUsageDescription` | 已有：Face ID 用于解锁加密日记 | [ ] 文案已按产品语言终审 |
| 相册 / 麦克风 / 位置 / 通讯录等 | **未**声明（当前功能不需要） | [ ] 若后续加附件/定位，须先补字符串再提审 |
| `PrivacyInfo.xcprivacy` | 已加入 Runner Resources；无追踪、无收集类型 | [ ] Archive 中确认 Manifest 被打入包内 |

- [x] Bundle ID 已改为正式标识 `app.privatenote.diary`（Android / iOS / macOS）。

---

## 4. Android targetSdk / Play 要求

| 项 | 现状（2026-10-26） | 完成 |
|----|-------------------|------|
| `targetSdk` | 已在 `android/app/build.gradle.kts` **固定为 36** | [ ] |
| Play 政策 | 自 **2026-08-31** 起，新应用与更新须 target **API 36+**（手机/平板） | [ ] 与 [Play 文档](https://developer.android.com/google/play/requirements/target-sdk) 复核无变 |
| `minSdk` | 26（SQLCipher / 加密库要求） | [ ] |
| Data Safety | 已按 `docs/google_play_data_safety_guide.md` 填写，且与最终 AAB 行为一致 | [ ] |
| 权限 | `INTERNET`（可选 WebDAV）、`USE_BIOMETRIC` | [ ] 合并 Manifest 无额外可疑权限 |

---

## 5. 调试残留与密钥安全

- [ ] `lib/` 无残留 `print` / `debugPrint` 输出敏感内容（抽查：`rg "print\\(|debugPrint" lib`）。
- [ ] 无硬编码生产 DB 密钥、同步主密钥或 WebDAV 密码（密钥仅经安全存储 / 用户输入）。
- [ ] `test/` 中的假密码与 `MemoryWebDavClient` **未**编入 release 业务路径。
- [ ] `pubspec.yaml` / 依赖树无 Firebase Analytics、Sentry、友盟等 §2.2 禁用 SDK。
- [ ] Release 构建未启用「官方明文同步」或调试后门开关。

---

## 6. 功能与隐私自检（§4 摘要）

- [ ] 未引入未加密本地业务库。
- [ ] 无网络路径会上传日记明文。
- [ ] 同步仍为用户自备 WebDAV + 客户端 AES-256-GCM。
- [ ] DB 密钥仍仅存平台安全存储。
- [ ] PIN（全平台）与移动端生物识别仍可用。
- [ ] Win / macOS / Android / iOS 均有可交付构建或已书面豁免（豁免不得违反隐私红线）。

---

## 7. 签署

| 角色 | 姓名 | 日期 | 签字确认可提交商店 |
|------|------|------|-------------------|
| 工程 | | | [ ] |
| 隐私文案 | | | [ ] |

**在本清单全部关键项勾选前，不要提交 App Store / Google Play。**
