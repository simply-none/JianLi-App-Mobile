plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jianli.jianli_mobile_app"
    // permission_handler_android 14.x 要求 compileSdk >= 37；AGP 升级到 9.1.1 后官方支持 API 37.0
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jianli.jianli_mobile_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // 版本号规则（年.月.日.版本，由 tool/build_apk.sh 维护 pubspec）：
        // pubspec.yaml 存 26.9.19+N（N = 当天第几次构建，从 1 开始）。
        // versionName：N=1 -> "26.9.19"；N>1 -> "26.9.19.(N-1)"（如第 5 次构建为 26.9.19.4）。
        // versionCode：由「日期+N」推导（如 26091905），跨天单调递增，避免覆盖安装版本降级。
        // split-per-abi 的 1000*ABI 偏移由 Flutter 插件在此值上自动叠加。
        val vName = flutter.versionName
        val buildNo = flutter.versionCode
        val dateParts = vName.split(".")
        val dateCode = if (dateParts.size == 3)
            ((dateParts[0].toInt() * 100 + dateParts[1].toInt()) * 100 + dateParts[2].toInt()) * 100
        else 0
        versionCode = dateCode + buildNo
        versionName = if (buildNo <= 1) vName else "$vName.${buildNo - 1}"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // R8 代码压缩 + 资源收缩（classes.dex 5.6MB -> 约 3MB）。
            // 插件反射层的 keep 规则见同目录 proguard-rules.pro；改动后需完整跑一次 release 构建回归。
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
