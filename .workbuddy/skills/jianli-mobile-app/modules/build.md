# 模块：构建与验证

## 构建与验证

> 📘 **从零开始（clone → 配环境 → 运行 → 打包）的完整逐步操作见仓库 `README.md`**，
> 本文档只写「已知就够用」的命令速查与雷区。README 有更新时，两边的环境值（镜像地址、SDK 路径、AGP/compileSdk 版本）
> 需保持一致。

### 环境前置（每个新 shell 必设，缺一必踩）
```bash
# 中文用户名雷区（%TEMP% 含中文 → build_runner 自举编译报 Unable to read program.dill）+ 国内镜像
export TMP=C:\src\tmp TEMP=C:\src\tmp
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export ANDROID_SDK_ROOT=C:\apps\Android\AndroidSDK
export PATH="$PATH:/c/apps/Android/AndroidSDK/platform-tools:/c/apps/Android/AndroidSDK/emulator"
cd /c/cod/jianli/jianli-mobile-app
```

### 日常开发循环（改码后按序执行）
```bash
flutter pub get                    # 改了 pubspec.yaml（依赖/版本）后必跑
dart run build_runner build -d     # 改了 drift 表定义（lib/core/db/tables/*.dart）后必跑，重新生成 app_database.g.dart
flutter analyze                    # 静态检查；基线 0 问题（2026-09-06 复核），出现新 error 必须修掉再交验
flutter test                       # 单测；基线全绿（totp RFC 向量 / transfer_utils / widget 冒烟，数量变化后更新此行）
flutter run -d emulator-5554       # 编译并启动到设备，看效果最快（r=热重载 / R=热重启 / q=退出）
```
布局排障开关见下文「代码级 paint 调试」。

### 跑起来看效果（UI 验证标准流程，**所有命令由用户在本地终端执行**）
> ⛔ **分工铁律（2026-09-05 用户明确指示，最高优先级）**：**Agent 只负责写代码与改文档；一切 flutter/dart 命令（analyze / test / build / run / pub get / build_runner…）一律由用户在本地终端执行，Agent 不代跑**。此前「Agent 可跑 analyze/test」的口径作废。
> 二次实踩依据（2026-09-05）：① Agent 侧无图形界面，无法观感验证；② 后台构建过慢（3~4 分钟仍未完）；③ 经 Git Bash 调用 `dart.bat`/`flutter.bat` 包装脚本会因本机 PowerShell 会话损坏直接失败（`InitialSessionState` 乱码报错），`dart.exe` 直连虽能跑 `analyze`，但 flutter tool 拉 git 子进程报「目录名称无效」——**结论：与其绕环境，不如全部交用户**。
> Agent 的职责止于：改码 → 把下方命令清单原样交给用户 → 等用户回贴结果再继续修。
>
> 另注：本机 bash 偶发「输出被吞」（命令执行了但 stdout 全空、exit 1），校验结果要落盘就写项目目录再用 Read 读。

```bash
# 0) 前置（每个新 shell 都要，中文用户名雷区 + 镜像）
export TMP=C:\src\tmp TEMP=C:\src\tmp
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
cd /c/cod/jianli/jianli-mobile-app

# 【可选】把 SDK 工具加进 PATH（本机 adb 默认不在 PATH，直接敲 adb 会 command not found / exit 127）
export ANDROID_SDK_ROOT=C:\apps\Android\AndroidSDK
export PATH="$PATH:/c/apps/Android/AndroidSDK/platform-tools:/c/apps/Android/AndroidSDK/emulator"

# 1) 确认模拟器在跑（没跑就先启动，见下节）
flutter devices          # 正常会显示 sdk gphone64 x86 64 (android-x64) → emulator-5554，Android 14

# 2) 一步编译并启动（看动效/UI 效果最快，推荐）
flutter run -d emulator-5554

# 3) 或：只出 debug APK 再手动装到模拟器
flutter build apk --debug --target-platform android-x64
adb install build/app/outputs/flutter-apk/app-x64-debug.apk
adb shell monkey -p <applicationId> 1     # applicationId 以 android/app/build.gradle.kts 为准
adb shell am start -n <applicationId>/.MainActivity   # 等价的显式启动方式
```

### 本机 Android 环境（2026-09-05 实测固定值，别再去默认位置找）
| 项 | 路径 / 值 |
|---|---|
| **Android SDK** | **`C:\apps\Android\AndroidSDK`**（**非默认位置**；`ANDROID_HOME`/`ANDROID_SDK_ROOT` 默认未设置，别去 `AppData\Local\Android\Sdk` 找，不存在） |
| adb | `C:\apps\Android\AndroidSDK\platform-tools\adb.exe` |
| emulator | `C:\apps\Android\AndroidSDK\emulator\emulator.exe` |
| system image | `android-34`（Android 14） |
| **AVD 名称** | **`Pixel_8`**（`C:\Users\风起\.android\avd\Pixel_8.avd` + `Pixel_8.ini`） |
| 在线设备 id | `emulator-5554` |
| applicationId（包名） | `com.jianli.jianli_mobile_app`（`android/app/build.gradle.kts`，namespace 同） |
| minSdk / targetSdk | 24（`flutter.minSdkVersion`，Flutter 3.47 默认）/ 随 Flutter 插件默认 |
| 版本号 | `pubspec.yaml` 的 `version: 26.9.6+1`（`+`前=versionName，`+`后=versionCode；发版先改这里） |
| 签名现状（2026-09-06） | release 仍用 **debug key**（Flutter 模板 TODO，无 keystore）——自测可装可跑，**正式发布前必须按「生产打包」配正式签名** |
| 应用名 / 图标 | 渐离App（AndroidManifest `android:label` + iOS Info.plist）；图标/启动屏由 `tool/make_icons.py` 生成，源图 `appLogo.png` |

**代码级 paint 调试（布局排障利器，2026-09-05 新增）**：`lib/main.dart` 顶部有三个默认关闭的开关，排查布局时置 `true` 后热重载（r），用完关回：
```dart
const bool kDebugPaintSize = false;      // 所有组件画青色边框 + padding 可视化（≈ CSS outline）
const bool kDebugPaintBaselines = false; // 文字基线
const bool kDebugRepaintRainbow = false; // 重绘彩虹（颜色变了=发生了重绘，查多余重绘）
```
仅 debug/profile 生效（release 剥离 assert）；开关经 `flutter/rendering.dart show 限定导入`（避免与 material_ui 符号冲突）；配合 DevTools 的 Widget Inspector / Layout Explorer 使用效果最佳（`flutter run` 控制台按 `v` 打开）。

**启动 SDK 虚拟机——完整可复制序列（2026-09-05 固化）**：
```bash
# ① 环境变量（每个新 shell 必设：中文用户名雷区 + 镜像 + SDK 工具入 PATH）
export TMP=C:\src\tmp TEMP=C:\src\tmp
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export ANDROID_SDK_ROOT=C:\apps\Android\AndroidSDK
export PATH="$PATH:/c/apps/Android/AndroidSDK/platform-tools:/c/apps/Android/AndroidSDK/emulator"
cd /c/cod/jianli/jianli-mobile-app

# ② 拉起虚拟机（后台运行，等它开机到锁屏/桌面）
/c/apps/Android/AndroidSDK/emulator/emulator.exe -avd Pixel_8 &

# ③ 确认在线（应出现 sdk gphone64 x86 64 (android-x64) → emulator-5554）
flutter devices

# ④ 编译并启动（首次构建数分钟属正常；运行会话内 r=热重载 / R=热重启 / q=退出）
flutter run -d emulator-5554
```
备选启动方式（`flutter devices` 里没有设备时先做这步）：
```bash
# 方式 1：直接拉起 AVD（最稳，推荐）
/c/apps/Android/AndroidSDK/emulator/emulator.exe -avd Pixel_8 &

# 方式 2：交给 Flutter（本机 flutter emulators 列表时常输出为空，不可尽信）
flutter emulators --launch Pixel_8

# 方式 3：Android Studio → Device Manager → 启动 Pixel_8（GUI，最省事）
```
启动后 `flutter devices` 复查出现 `emulator-5554`，再 `flutter run -d emulator-5554`。**真机调试**：手机开 USB 调试连电脑 → `adb devices` 授权 → `flutter devices` 拿真机 id → `flutter run -d <真机id>`（arm64 的 libsqlite3.so 已在 jniLibs 就位，无需特殊处理）。

### 生产打包（release APK / AAB，2026-09-06 全面拆解）

#### ① 版本号
- 唯一出处：`pubspec.yaml` 的 `version: 26.9.6+1`。`+` 前 = versionName（显示名），`+` 后 = versionCode（整数，**必须严格递增**才能覆盖安装）。发版第一步改这里。
- split APK 会自动在 versionCode 上加 `1000 × ABI 序号`（arm32=1/arm64=2/x64=3）；要强制用 pubspec 原值加 `-P force-version-code-ignoring-abi=true`。

#### ② 签名（当前 release 签 debug key，正式发布前必做，一次性配置）
1. 生成正式 keystore（本机一次生成、永久保管，**丢了无法再以同签名发版**；文件与口令勿外传/勿提交）：
   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 36500 -alias upload
   # keytool 不在 PATH 时用 Android Studio 自带 JBR（本机 Android Studio 装在 C:\apps\Android，注意不是默认位置）：
   # "C:\apps\Android\Android Studio\jbr\bin\keytool.exe" <同上参数>
   # 该 JBR 实测为 JDK 25.0.2，同时也是 Gradle 构建实际使用的 JDK（PATH 上的 java 可能仍是 1.8，以 Gradle 用的为准）
   ```
2. 新建 `android/key.properties`（口令明文，勿提交）：
   ```properties
   storePassword=<keystore 口令>
   keyPassword=<key 口令>
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
   `storeFile` 相对 **android/app/** 目录解析；keystore 放哪就写相对谁的路径，拿不准就写绝对路径。
3. 改 `android/app/build.gradle.kts`：文件顶部加两行 import 与加载逻辑，release buildType 换正式签名：
   ```kotlin
   import java.util.Properties
   import java.io.FileInputStream

   val keystoreProperties = Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(FileInputStream(keystorePropertiesFile))
   }

   android {
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
               storeFile = keystoreProperties["storeFile"]?.let { file(it) }
               storePassword = keystoreProperties["storePassword"] as String
           }
       }
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")   // 替换原来的 getByName("debug")
           }
       }
   }
   ```

#### ③ 打包命令矩阵（产物都在 `build/app/outputs/`）
| 命令 | 产物 | 用途 |
|---|---|---|
| `flutter build apk --release` | `flutter-apk/app-release.apk`（三 ABI 合一 fat 包） | **直接发用户装**，最省事 |
| `flutter build apk --release --split-per-abi` | `flutter-apk/app-{armeabi-v7a,arm64-v8a,x86_64}-release.apk` | 瘦包（体积约减半），真机一般发 arm64 |
| `flutter build appbundle --release` | `bundle/release/app-release.aab` | Google Play 上架 |
| `flutter build apk --debug --target-platform android-x64` | `flutter-apk/app-x64-debug.apk` | 模拟器快装调试，**非生产** |

#### ④ 安装与发布前验证
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk    # -r 覆盖升级保留数据；降级 versionCode 会拒装
adb shell am force-stop com.jianli.jianli_mobile_app            # 冷启动抓启动问题（am start 对热进程只是切前台）
adb shell am start -n com.jianli.jianli_mobile_app/.MainActivity
adb shell dumpsys package com.jianli.jianli_mobile_app | grep -E "versionName|versionCode"   # 核对版本
# 签名校验（上架/分发前）：
C:/apps/Android/AndroidSDK/build-tools/<版本号>/apksigner.bat verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```
- 未配正式签名时 `--release` 也能出包（debug key 签名），可装可跑，但**不能上架**，且与将来正式签名包互相覆盖会因签名不一致拒装（见排障）。
- release 专属问题复现：`flutter run --release -d <id>`。

### 图标 / 启动屏再生成（换 logo 或改尺寸策略时）
1. 覆盖根目录 `appLogo.png`（1024×1024 白底）。
2. `py tool/make_icons.py`（依赖 Pillow：`py -m pip install pillow`）——自动重出 Android 五密度 `ic_launcher` / 自适应前景（62% 安全区）/ `drawable-nodpi/splash_logo` / iOS AppIcon 15 尺寸（去 alpha）/ LaunchImage 三倍图。
3. 配套资源声明（一般不动）：`mipmap-anydpi-v26/ic_launcher.xml`、`values/colors.xml`、`values-v31` 与 `values-night-v31` 的 `styles.xml`（A12+ 系统启动屏白底；night 优先级高于 v31，故两处都要）。
4. 应用名（渐离App）：Android `AndroidManifest.xml` 的 `android:label` + iOS `Info.plist` 的 `CFBundleDisplayName/CFBundleName`。

### 排障：常见报错
- **`No supported devices found with name or id matching 'emulator-5554'`** → 模拟器进程根本没在跑（**不是 id 写错**）。先 `tasklist | grep -iE "qemu|emulator"` 确认无进程，再按上面「启动模拟器」拉起来，然后 `flutter devices` 复查。
- **`adb: command not found`（exit 127）** → 本机 adb 不在 PATH。用全路径 `C:\apps\Android\AndroidSDK\platform-tools\adb.exe`，或按上面把 `platform-tools` 加进 PATH。
- **`flutter emulators` 无输出 / exit 1** → 本机该命令不可靠（列表可能为空）。**别据此判断「没有 AVD」**——AVD 一直在 `C:\Users\风起\.android\avd\Pixel_8.avd`。
- **冷启动抓日志**：`am start` 对已运行应用只是切前台（result code=3），必须先 `adb shell am force-stop <pkg>` 再冷启动（同「UI 体系」排查技巧）。
- 查包名：`adb shell cmd package list packages | grep jianli`。
- Gradle JVM 已加 `--enable-native-access=ALL-UNNAMED`（修 JDK restricted-method 警告，见 `android/gradle.properties`）。
- **已知无法修的警告**：KGP 弃用警告（mobile_scanner / workmanager_android 用旧 Kotlin Gradle Plugin）——两插件已是最新，需等上游支持 Flutter built-in Kotlin，仅警告不阻塞。
- Android sqlite3：jniLibs 三 ABI（arm64-v8a / armeabi-v7a / x86_64）手动分发 `libsqlite3.so`（源文件取自 sqlite3.dart 3.5.2 release）。
- iOS：需 Mac + Xcode，Windows 阶段保留 ios 目录不构建。
- **`INSTALL_FAILED_UPDATE_INCOMPATIBLE`（覆盖安装报签名不一致）** → debug 包 ↔ 正式签名包之间切换必现：`adb uninstall com.jianli.jianli_mobile_app`（会清数据）后重装。
- **`key.properties` / keystore 相关报错**（打包期 `FileNotFoundException` / `Password verification failed`）→ `storeFile` 相对 `android/app/` 解析；逐项核对文件存在、口令、alias。
- **release 包闪退而 debug 正常** → 先 `flutter run --release -d <id>` 本机复现；再看 `adb logcat` 过滤 `FATAL`。Flutter 下 R8 混淆缺反射规则的场景罕见，优先怀疑插件初始化（通知/后台任务）与 release 剥离 assert 暴露的空安全问题。
- **`A problem occurred evaluating project ':flutter_inappwebview_android'`** → 报错 `getDefaultProguardFile('proguard-android.txt') is no longer supported`（AGP 9.x 已删除该默认文件）。根因：`flutter_inappwebview: ^6.1.5` 依赖 `flutter_inappwebview_android: ^1.1.3`，官方最新版（6.1.5，无 7.x 可用）的 `android/build.gradle` 仍引用它，assembleRelease 评估阶段即抛错。**已永久修复**：仓库内 `third_party/flutter_inappwebview_android/` 为已打补丁副本（其 `android/build.gradle` 改用 `proguard-android-optimize.txt`），app `pubspec.yaml` 用 `dependency_overrides` 指向该本地路径。⚠️ **该 override 与 `third_party/` 目录必须保留**——若被误删或 `flutter pub cache repair` 后未恢复，报错会复现。release 若因 R8 优化误删插件代码而崩，在 `third_party/flutter_inappwebview_android/android/proguard-rules.pro` 末尾加 `-dontoptimize` 兜底。

