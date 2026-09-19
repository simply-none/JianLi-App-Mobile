import org.jetbrains.kotlin.gradle.dsl.JvmTarget

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// JVM target 对齐（2026-09-19 P0 批次实修）：各插件「Java 与 Kotlin 的 JVM target 不一致」
// 是引新插件的高发错（首例 receive_sharing_intent：Java 11 vs Kotlin 25=运行 Gradle 的 JDK；
// 次例 android_file_picker：自身声明 Java 17，全局钉 11 反而制造冲突）。
// 正确做法 = **逐项目对齐**：Kotlin 编译任务的 jvmTarget 跟随该项目自己的
// compileOptions.targetCompatibility（Java 任务的目标正是从它来的，两边必一致）。
// 任务配置走 configureEach 懒回调（任务实化晚于 evaluation，届时 android 扩展已就绪）。
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val target = when (val ext = project.extensions.findByName("android")) {
            is com.android.build.api.dsl.ApplicationExtension ->
                ext.compileOptions.targetCompatibility.toString()
            is com.android.build.api.dsl.LibraryExtension ->
                ext.compileOptions.targetCompatibility.toString()
            else -> null
        }
        if (target != null) {
            compilerOptions.jvmTarget.set(JvmTarget.fromTarget(target))
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
