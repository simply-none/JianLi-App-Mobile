# 渐离 App 移动端（jianli-mobile-app）

桌面版「渐离 App」（Electron + Vue3）的 **Flutter 移动端**移植工程，包名 `com.jianli`。

本文档从「一台空机器」开始，一步步记录**拉取代码 → 配环境 → 跑起来 → 打包出 APK** 的完整操作。
命令以 **Windows（cmd / PowerShell）** 为准；Linux / macOS 只需把路径和环境变量写法替换掉，流程一致。

---

## 0. 项目速览

| 项 | 值 |
| --- | --- |
| 仓库 | `https://github.com/simply-none/JianLi-App-Mobile.git`（默认分支 `master`） |
| 包名 / applicationId | `com.jianli.jianli_mobile_app` |
| 版本 | `26.9.6+1`（`pubspec.yaml` 的 `version`，即 versionName + versionCode） |
| 语言 | Flutter 3.47.x / Dart 3.13.x（`environment: sdk: ^3.13.2`） |
| Android | `compileSdk = 37`，AGP **9.1.1**，Kotlin **2.4.0**，Gradle **9.3.1**（wrapper） |
| minSdk / targetSdk | 未显式覆写，跟随 Flutter 默认（`flutter.minSdkVersion` / `flutter.targetSdkVersion`） |
| UI | forui 0.26 + material_ui（**独立 Material 发行版，勿与 `flutter/material` 混用**） |
| 状态管理 | flutter_riverpod 3.x + go_router |
| 数据库 | drift + sqlite3_flutter_libs（native 库按 ABI 手动分发，见 §5.3） |

---

## 1. 前置环境（首次只需装一次）

### 1.1 Flutter SDK

1. 下载 Flutter **3.47.x**（稳定版）并解压，例如本机装在 `C:\src\flutter`。
2. 把 `C:\src\flutter\bin` 加入 `PATH`。
3. 验证（首次会自举 Dart SDK，稍慢）：

```bat
flutter --version
flutter doctor -v
```

`flutter doctor` 里 Android 相关的 ✓ 全绿才继续；有 ✗ 先按提示修（通常是缺 SDK 平台或许可未接受）。

### 1.2 Android Studio + Android SDK

1. 安装 **Android Studio**（本机装在 `C:\apps\Android\Android Studio`）。
2. 打开 Android Studio → **Settings → Android SDK**，安装：
   - **Android SDK Platform 37**（`compileSdk = 37` 必须，否则报 `Failed to find target with hash string 'android-37'`）
   - 对应 **Build Tools**（本机 36.0.0）
   - **Android SDK Platform-Tools**、**Emulator**
   - 若要跑模拟器：一个 **System Image**（本机 `android-34` / Android 14）
3. 记下 **Android SDK Location**（本机 `C:\apps\Android\AndroidSDK`，**非默认位置**，后面 §3 要写到 `local.properties`）。

### 1.3 JDK

AGP 9.x / Gradle 9.x **需要 JDK 17 以上**。两个来源二选一：

- **推荐**：直接用 Android Studio 自带的 JBR（本机 `C:\apps\Android\Android Studio\jbr`，实测 **JDK 25.0.2**）。Flutter 构建时会自动找到它，无需额外配置。
- 或者自行安装 JDK 17+，并设置 `JAVA_HOME`；若命令行 `java -version` 显示的是别的版本（本机 PATH 上是 1.8），还可以在
  `android/gradle.properties` 里显式指定：

```properties
org.gradle.java.home=C:\\path\\to\\jdk-17
```

> ⚠️ 判断标准：Gradle 实际使用的 JDK 必须 ≥ 17，与 PATH 里的 `java` 版本无关。

### 1.4 Python（可选）

只有**重新生成应用图标**时才需要：`tool/make_icons.py`。日常构建运行不需要。

---

## 2. 拉取代码

```bat
:: 选一个不含中文、不含空格的父目录（中文路径会让 Dart/Gradle 出各种玄学问题）
cd /d C:\cod\jianli

git clone https://github.com/simply-none/JianLi-App-Mobile.git jianli-mobile-app
cd jianli-mobile-app

:: 确认在 master 分支
git branch --show-current
git pull origin master
```

仓库里已包含：Flutter 工程（`lib/`、`test/`）、Android 工程（`android/`）、iOS 工程（`ios/`）、
图标生成脚本（`tool/make_icons.py`），以及**已入库的 sqlite3 原生库**（`android/app/src/main/jniLibs/`，3 个 ABI）。

---

## 3. 配置本地路径（`android/local.properties`）

Gradle 靠这个文件定位 Flutter SDK 与 Android SDK。它**不入库**，通常 Flutter 首次构建会自动生成；
若你的 SDK 不在默认位置（本机就是），建议**手动写一次**避免自动探测失败：

`android/local.properties`：

```properties
flutter.sdk=C:\\src\\flutter
sdk.dir=C:\\apps\\Android\\AndroidSDK
```

> Windows 路径分隔符用 `\\` 或 `/` 都可以。**不要提交这个文件**（含本机绝对路径）。

---

## 4. 设置环境变量（**每开一个新终端都要设**）

这是本工程最容易踩的坑，请在**构建用的那个终端**里先执行完再跑任何 flutter / dart / gradle 命令。

### 4.1 中文用户名雷区 → 必须重定向临时目录

Windows 用户目录含中文（如 `C:\Users\风起`）时，`%TEMP%` 带中文会让 Dart `build_runner` 自举编译失败
（`Unable to read program.dill`）。**必须先建一个纯 ASCII 临时目录并指过去**：

```bat
:: 建一次即可
mkdir C:\src\tmp

:: 每个终端都要设
set TMP=C:\src\tmp
set TEMP=C:\src\tmp
```

PowerShell：

```powershell
New-Item -ItemType Directory -Force -Path C:\src\tmp
$env:TMP  = 'C:\src\tmp'
$env:TEMP = 'C:\src\tmp'
```

### 4.2 国内镜像（pub / Flutter 构件）

```bat
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

> ⚠️ 这两个必须是**当前有效值**。若终端里继承了旧的 cernet 镜像变量，会出现
> `flutter_embedding_debug` 等构件拉取失败。不确定就先 `echo %PUB_HOSTED_URL%` 看一眼，
> 不对就按上面重设（同终端后设的覆盖先设的）。

### 4.3 Gradle 缓存目录（可选，建议固定）

```bat
set GRADLE_USER_HOME=C:\src\gradle-home
```

### 4.4 一次性设完全部（cmd 直接复制）

```bat
set TMP=C:\src\tmp
set TEMP=C:\src\tmp
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set GRADLE_USER_HOME=C:\src\gradle-home
```

> Gradle 的 Maven 镜像（阿里云）已写死在 `android/settings.gradle.kts`，**不要删**；

---

## 5. 拉依赖

```bat
cd /d C:\cod\jianli\jianli-mobile-app
flutter pub get
```

成功后会生成 `.dart_tool/`、`pubspec.lock`。

### 5.1 仅当改动 drift 表定义时：跑代码生成

新增/修改了 `lib/` 里的 drift 表（`@DriftDatabase`、列名、`MigrationStrategy`）后必须重新生成 `.g.dart`：

```bat
flutter pub run build_runner build --delete-conflicting-outputs
```

- 首次约 2~4 分钟；**必须**先设好 §4.1 的 `TMP/TEMP`，否则必崩。
- 生成空壳 `.g.dart`（表没进去）几乎都是 `part` 声明缺失或表名/字段写错，去 `lib/core/database/` 核对。

### 5.2 不要动的配置

- `pubspec.yaml` 里的 `hooks.user_defines.sqlite3`（Windows 用 `winsqlite3.dll`、Android 用裸名 `sqlite3`）：
  这是踩坑后固化的配置，**删了或改回默认**会导致构建期从 GitHub 下载 dll 超时。
- 图标/启动屏**不要**改用 `flutter_launcher_icons` / `flutter_native_splash`：
  它们依赖 `image ^4`，与 `epubx`（`image ^3`）冲突。图标用 `python tool/make_icons.py` 生成。

---

## 6. 静态检查与测试

```bat
flutter analyze
```

出现 `error` 必须修干净；`warning` 建议一并处理。

```bat
flutter test
```

当前测试：`test/totp_test.dart`、`test/features/file_transfer/transfer_utils_test.dart`、`test/widget_test.dart`，
**全部通过即为正常基线**。若你没改代码却挂了，先确认 §4 的环境变量都设了。

---

## 7. 运行

### 7.1 启动模拟器

```bat
:: 后台启动本机 AVD（名称 Pixel_8，Android 14 / android-34）
start "" "C:\apps\Android\AndroidSDK\emulator\emulator.exe" -avd Pixel_8
```

等桌面出现模拟器画面后确认在线（adb 不在 PATH，用绝对路径）：

```bat
C:\apps\Android\AndroidSDK\platform-tools\adb.exe devices
```

正常会看到：

```
List of devices attached
emulator-5554	device
```

### 7.2 用真机（推荐，功能最全）

1. 手机**开发者选项**里开「USB 调试」。
2. USB 连电脑，手机上点「允许调试」。
3. `adb devices` 能看到设备即 OK。
4. 通知类功能需在 Android 13+ 上**运行时授予**「通知」权限（首次进相关页会弹）。

### 7.3 跑起来

```bat
flutter devices          :: 列出可选设备
flutter run -d emulator-5554
flutter run              :: 只有一个设备时可省略 -d
```

运行起来后：

| 操作 | 快捷键 |
| --- | --- |
| 热重载（改 UI 秒生效，保留状态） | `r` |
| 热重启（状态重置） | `R` |
| 退出 | `q` |

其他常用参数：

```bat
flutter run --release          :: 发行模式（性能真实，但无法热重载）
flutter run -v                 :: 打不出错时看详细日志
flutter run -d <deviceId> --dart-define=...   :: 需要自定义编译变量时
```

---

## 8. 打包构建

### 8.1 Debug APK（日常自测）

```bat
flutter build apk --debug
```

### 8.2 Release APK

```bat
flutter build apk --release
```

### 8.3 按 ABI 分包（体积小很多，推荐分发用）

```bat
flutter build apk --release --split-per-abi
```

### 8.4 AAB（上架 Google Play）

```bat
flutter build appbundle --release
```

### 8.5 产物位置

| 类型 | 路径 |
| --- | --- |
| APK | `build/app/outputs/flutter-apk/app-release.apk` |
| 分包 APK | `build/app/outputs/flutter-apk/`（`app-armeabi-v7a-release.apk`、`app-arm64-v8a-release.apk`、`app-x86_64-release.apk`） |
| AAB | `build/app/outputs/bundle/release/app-release.aab` |

安装到设备：

```bat
C:\apps\Android\AndroidSDK\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-release.apk
```

### 8.6 关于签名（重要）

`android/app/build.gradle.kts` 当前 **release 复用了 debug 签名**，所以 `flutter run --release` / `build apk --release`
能直接跑通；但**这个 APK 不能对外发布**。正式发布前请替换成你自己的签名配置：

1. 生成 keystore：

```bat
keytool -genkey -v -keystore C:\cod\jianli\jianli-mobile-app\android\jianli.jks ^
  -keyalg RSA -keysize 2048 -validity 10000 -alias jianli
```

2. 新建 `android/key.properties`（**不要入库**）：

```properties
storeFile=..\\jianli.jks
storePassword=<你的密码>
keyAlias=jianli
keyPassword=<你的密码>
```

3. 在 `android/app/build.gradle.kts` 里读取它并配 `signingConfigs`，再把 `buildTypes.release.signingConfig`
   从 `debug` 改成你自己的配置。

### 8.7 版本号

版本号只改 `pubspec.yaml` 一处：

```yaml
version: 26.9.6+1      # + 前面是 versionName，后面是 versionCode
```

改完重新构建即可；`android/local.properties` 里的 `flutter.versionName/versionCode` 会由 Flutter 自动同步。

---

## 9. 常见坑与排障

| 症状 | 原因 / 处理 |
| --- | --- |
| `Unable to read program.dill` | `%TEMP%` 含中文 → 按 §4.1 设 `TMP/TEMP` 到 `C:\src\tmp`，重开终端 |
| `flutter_embedding_debug` 等构件下载失败 | 继承了旧镜像变量 → 重设 §4.2 的 `PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL` |
| `Failed to find target with hash string 'android-37'` | 没装 SDK Platform 37，或 AGP 版本不对（需 **9.1.1**）。**不要**去重命名 SDK 目录或改 `ApiLevel`，AGP 9.1.0 本身就认不了 API 37 |
| Gradle 报 JDK 版本不对 | 用 Android Studio 自带 JBR 或装 JDK 17+，必要时设 `org.gradle.java.home` |
| `flutter.sdk not set in local.properties` | 按 §3 手写 `android/local.properties` |
| 启动即崩 / `sqlite3_open` 报 `no such table` | 检查 `android/app/src/main/jniLibs/` 三个 ABI 的 `libsqlite3.so` 是否齐全（已入库，别误删）；以及 drift 迁移是否漏了新表 |
| 改了表但数据没变 | 忘了跑 `build_runner`（§5.1） |
| 通知不弹 | Android 13+ 需在系统设置里给「通知」权限；`awesome_notifications` 初始化要在 `main()` 里完成 |
| 局域网同步 / 文件互传扫不到 PC | 手机与 PC 需在**同一 Wi-Fi**；若 PC 连的是手机热点，扫描逻辑已覆盖该场景，仍不行就检查防火墙放行 UDP 47123 / TCP 47124 |
| **模拟器**上同步/互传扫不到 PC | 模拟器在 NAT 后（10.0.2.15），UDP 广播过不去，**扫不出来是必然的**。见 §10 |
| 构建慢 | 首次构建（下载 Gradle、AAR、生成 .g.dart）正常要几分钟；之后增量构建快很多 |

---

## 10. 附：模拟器与 PC 端联调（局域网同步 / 文件互传）

PC 端（Electron）通过 **UDP 广播 47123** 发现设备、**TCP 47124** 传数据。模拟器跑在 QEMU 的 SLIRP NAT 后
（guest `10.0.2.15`），宿主机**无法直接访问**它，adb 又只转发 TCP 不转发 UDP——所以模拟器永远扫不出来。

**解决办法（已实测可用）**：用 adb 把宿主机端口转发进模拟器，再在 PC 端手动添加设备（**端口必须是 47125**，
因为宿主机的 47124 已被 PC 自己的数据面占用）：

```bat
C:\apps\Android\AndroidSDK\platform-tools\adb.exe forward tcp:47125 tcp:47124
```

然后 PC 端「文件互传 / 同步」页 → 手动添加 → 填：

```
127.0.0.1:47125
```

验证链路是否通：

```bat
curl http://127.0.0.1:47125/ping
:: 正常返回形如 {"name":"localhost","id":"...","platform":"android"}
```

注意：

- 模拟器重启 / adb 断连后 forward 会失效，需重跑一次。
- 必须在 App 已启动、47124 已监听之后再转发才有效。
- **真机与 PC 同 Wi-Fi 时无需任何转发**，直接扫描即可，联调优先用真机。

---

## 11. 目录结构速查

```
lib/
  core/           基础设施：database(drift)、sync、theme、router、notifications
  features/       功能域：dashboard / habit / todo / pomodoro / reminder /
                  countdown / note(笔记) / chat(主题对话) / ebook / totp(2FA) /
                  password(密码库) / vault(文件保险箱) / qrcode / file_transfer
android/          Android 壳工程（AGP 9.1.1，compileSdk 37）
ios/              iOS 壳工程
test/             单元测试与 widget 测试
tool/make_icons.py 图标生成脚本（Python）
```

更细的架构约定、drift 三大铁律、vault 加密对齐规则、同步协议与已知雷区，见工程内的开发技能文档：
`.workbuddy/skills/jianli-mobile-app/SKILL.md`。
