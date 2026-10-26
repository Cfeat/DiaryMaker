# Android 正式签名说明

> 封面标题：Android 正式签名说明  
> Release 构建**不再**使用 debug 签名。

## 1. 生成本地上传密钥（一次性）

在仓库 `android/` 目录：

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

将生成的 `upload-keystore.jks` 放在 `android/`（已在 `.gitignore`）。

复制模板并填写口令：

```bash
copy key.properties.example key.properties
```

`key.properties` 示例：

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```

## 2. 构建

```bash
flutter build apk --release
flutter build appbundle --release
```

缺少 `key.properties` 时 Gradle 会直接失败（不会静默回退 debug）。

## 3. CI

GitHub Actions 在 job 内生成**临时** keystore，仅用于验证 release 可编译；  
**上架 Play 必须使用本机保管的正式 `upload-keystore.jks`**，并建议将正式密钥以 GitHub Secrets 注入（勿提交仓库）。

## 4. 备份

丢失 upload keystore 会导致无法更新同一 `applicationId` 的 Play 应用。请离线备份 `.jks` 与口令。
