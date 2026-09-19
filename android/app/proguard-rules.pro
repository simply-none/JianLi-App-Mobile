# R8 / ProGuard 规则 —— 配合 build.gradle.kts 的 isMinifyEnabled + isShrinkResources。
# Flutter 官方 gradle 插件自带 flutter.io 基础规则，这里只补第三方插件的反射层 keep。
# 若开启混淆后出现运行时 NoSuchMethodError / ClassNotFoundException，
# 先用 `flutter run --release` 复现，再按缺失类补 keep，不要无脑全 keep。

# ---------- Flutter 插件反射层（MethodChannel 按 name 反射注册，必须整体保留） ----------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ---------- flutter_inappwebview（EPUB 阅读器 WebView） ----------
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview.**

# ---------- webview_flutter（隔空互传 QRFerry 扫码 WebView） ----------
-keep class io.flutter.plugins.webviewflutter.** { *; }

# ---------- mobile_scanner（二维码识别 + MLKit barhopper） ----------
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**

# ---------- awesome_notifications（通知，含反射创建 action） ----------
-keep class me.carda.awesome_notifications.** { *; }
-dontwarn me.carda.awesome_notifications.**

# ---------- workmanager（后台任务，反射回调） ----------
-keep class dev.fluttercommunity.** { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# ---------- file_picker ----------
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ---------- 反射/序列化需要的元信息 ----------
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod

# ---------- Flutter 引擎 deferred components（Play 商店延迟加载） ----------
# PlayStoreDeferredComponentManager 静态引用 play.core，本项目不使用 deferred components
# 且未引入 Play Core 依赖，运行时不会走到这些类 → 直接 dontwarn（2026-09-19 R8 实测报缺）。
-dontwarn com.google.android.play.core.**
