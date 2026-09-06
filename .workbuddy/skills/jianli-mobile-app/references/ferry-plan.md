# 隔空互传（ferry）移动端方案 · 决策记录

> 状态：**已实施完成（2026-09-06）**。与 PC 端 `jianli-app/.workbuddy/skills/jianli-app/references/modules/ferry.md` 同机制、共享同一份 QRFerry 打包资源。

## 一、需求（已落地）
- 移动端新增【隔空互传】页（工具组入口）：无需局域网，把文件编码成屏幕动态二维码、或用摄像头扫描对方屏幕二维码收发文件。
- 与 PC 端共享同一 QRFerry 静态站（屏幕→摄像头、fountain 码），双端对称（都能发、都能收）。

## 二、集成架构（已落地）
- 资源：`assets/qyferry/`（pubspec `flutter.assets` 声明，打包进 app）。
  - **移动端特殊处理**：QRFerry 打包产物内部资源目录默认叫 `assets/`。若移动端直接放在 `assets/qyferry/assets/`，Flutter 构建工具会出现「嵌套 assets 子目录资源漏打包」问题（现象：`index.html` 能加载，`/assets/index-xxx.css` 与 `/assets/index-xxx.js` 返回 404）。因此移动端把实际资源目录改名为 `assets/qyferry/webassets/`，但**不修改 HTML**，由 `ferry_server` 把 URL `/assets/...` rewrite 到 `assets/qyferry/webassets/...`。
  - PC 端 Electron 直接读文件系统，无此限制，仍保持 `electron/resources/qyferry/assets/` 原结构。
- `lib/features/ferry/ferry_server.dart`：单例 `HttpServer` 绑定 `InternetAddress.loopbackIPv4` 随机端口，由 `rootBundle` 即时按 URL 提供静态文件（含 MIME、`Content-Length`、显式 200、`Access-Control-Allow-Origin:*`、防目录穿越；URL `/assets/...` 会 rewrite 到 `assets/qyferry/webassets/...`；资源未找到回退 404 并带 assetKey 便于排查）。**踩坑记**：曾试过「启动期读 `AssetManifest.loadFromAssetBundle` 枚举 key → 解压到临时目录 → 真实文件 serving」，但引入了 manifest/bin 解析与写盘两个额外失败点，反而报「启动本地服务失败」；回退为直接 rootBundle 即时读（失败点最少）。资源是否进 bundle 由 `flutter clean && flutter pub get && flutter run` 保证，**热重载不会重新打包资源**。
- `lib/features/ferry/ferry_page.dart`：forui 页（FScaffold + FHeader.nested + PageBanner 红(6) + ≤10MB 说明），用 `flutter_inappwebview` 的 `InAppWebView` 加载 `http://127.0.0.1:<port>/`；`onPermissionRequest` 自动放行摄像头（getUserMedia）；入页 `Permission.camera.request()` 预申请。页面带**屏内自诊断**：启动后 `_selfCheckAssets()` 拉首页 HTML → 提取其引用的 CSS 路径 → 直接 `rootBundle.load` 验证该资源是否真打包进 bundle，屏上红/绿字显示结果（旧构建会明确报「CSS 资源未打包进 bundle」）；并把 console / httpError / loadStop 打到屏底「调试日志」区，无需依赖控制台日志。
- 路由 `/ferry`（go_router，`slidePage` 纯横向滑入）+ 工具组入口（`FLucideIcons.scanQrCode`，accent 6，组内唯一不撞色）。**注意**：WebView 等 PlatformView 在 `FadeTransition` 转场中容易空白/黑屏，因此 /ferry 不用全局 `fadeSlidePage`，改用无淡入的 `slidePage`。

## 三、权限（已落地）
- Android：`AndroidManifest.xml` 加 `android.permission.CAMERA`（WebView getUserMedia 运行时授权；`onPermissionRequest` 自动放行）。
- iOS：`Info.plist` 加 `NSCameraUsageDescription`（WKWebView getUserMedia 系统弹窗用同一 key；flutter_inappwebview 规避 WKWebView 摄像头限制）。
- `android:usesCleartextTraffic="true"` 已存在（文件互传 release 必需），127.0.0.1 http 属安全上下文，摄像头可用。

## 四、关键文件
- `lib/features/ferry/ferry_server.dart`、`lib/features/ferry/ferry_page.dart`
- `pubspec.yaml`：`flutter_inappwebview: ^6.1.5` + `flutter.assets: - assets/qyferry/`
- `lib/app/router/app_router.dart` `/ferry`；`lib/features/hubs/hub_pages.dart` 工具组入口
- `android/app/src/main/AndroidManifest.xml` `CAMERA`；`ios/Runner/Info.plist` `NSCameraUsageDescription`

## 五、坑 / 注意
- **本地 http 托管是必须的**：QRFerry 的 `index.html` 用 `<script type="module" crossorigin>`，file:// 会被 CORS 拦截；127.0.0.1 是安全上下文，getUserMedia 可用。`ferry_server` 已补全 `Content-Length`、显式 200 状态码、请求/响应日志。
- **无需自写扫码**：网页自带扫码识别与解码，本端只开放摄像头权限（`onPermissionRequest` 放行 + permission_handler 预申请）。
- **WebView 白屏排查**：若页面框架（PageBanner + 提示条）能出来但下方空白，先看屏上「资源自检」结论。① 路由必须改用无淡入的 `slidePage`（FadeTransition 对 PlatformView 易空白）。② 若 console 报 `Refused to apply style ... MIME type ('text/plain')` → 来自 `ferry_server` 404 回退分支（`rootBundle.load` 抛「找不到」），即该 CSS 资源**没打进正在运行的 APK 的 bundle**。这与 `_assetCheck` 报「❌ CSS 资源未打包进 bundle」一致。**根因是旧构建**：`index.html`（assets/qyferry 顶层）能加载、嵌套 `assets/qyferry/assets/*.css` 报 text/plain，正说明安装的是旧的/部分资源 APK。**判定旧构建的铁证**：每个请求都应打 `[FerryServer] request` 日志，若一条都没有，说明跑的不是最新 `ferry_server.dart`。**解决：必须让 `flutter run` 真正跑完并重新安装**（`flutter clean && flutter pub get && flutter run -d emulator-5554`，等其进入 Running 状态；若中途报错旧 APK 会残留，须把报错贴出）。热重载不会重打包 assets，`ferry_server` 的 MIME 映射本身正确（`.css`→`text/css`），无需改 MIME。
- **≤10MB 限制**：屏幕→摄像头逐帧扫描机制固有，大文件极慢；入口页与网页内联提示条均带说明。
- **改 pubspec.yaml 后须 `flutter pub get`**；`flutter analyze` / `flutter run` 由用户在本地执行（分工铁律）。
- iOS 真机需 Mac+Xcode 构建验证；Windows 阶段仅 Android 构建。
- 与「文件互传」（`file-transfer`）是**两套独立机制**：文件互传走局域网 UDP+HTTP 数据面；隔空互传走屏幕二维码→摄像头，互不相干。
