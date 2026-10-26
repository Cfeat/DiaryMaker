# 四端 Release 构建核对记录

> 封面标题：四端 Release 构建核对记录  
> 日期：2026-10-26  

| 平台 | 命令 | 结果 | 产物 |
|------|------|------|------|
| 单元/组件测试 | `flutter test` | **通过**（73） | — |
| 静态分析 | `flutter analyze --fatal-infos` | **通过** | — |
| Windows | `flutter build windows --release` | **通过**（clean 前）；clean 后需 Windows「开发人员模式」才能再建（symlink） | `build/windows/x64/runner/Release/private_note.exe` |
| Android | `flutter build apk --release` | **通过**；签名 DN=`CN=PrivateNote, OU=Mobile…`（非 debug） | `build/app/outputs/flutter-apk/app-release.apk`（57.5MB） |
| macOS | `flutter build macos --release` | **[NOT RUN]** 当前为 Windows 主机，无 macOS runner | 依赖 CI `apple` job |
| iOS | `flutter build ios --release --no-codesign` | **[NOT RUN]** 同上；商店签名仍需本机 Xcode | 依赖 CI + 人工 Archive |

## CI

- Workflow：`.github/workflows/build.yml`（push `main` / `workflow_dispatch`）
- Android CI 使用**临时** keystore（非 Play 上传密钥）
- 正式 Play 上传请使用本机 `android/upload-keystore.jks`（见 `docs/android_signing.md`）

## 隐私政策公网页

- 目标 URL：https://cfeat.github.io/DiaryMaker/privacy/
- 源文件：`docs/public/privacy/index.html`
- 部署：`.github/workflows/pages.yml`
