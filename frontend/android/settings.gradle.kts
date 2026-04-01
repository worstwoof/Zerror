pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 🌟 核心修改 1：将阿里云替换为极其稳定的腾讯云镜像
        maven { url = uri("https://mirrors.tencent.com/nexus/repository/maven-public/") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    // 【核心魔法】赋予最高权限，杜绝一切冲突
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        // 🌟 核心修改 2：用腾讯云替换阿里云，解决 androidx 依赖下载失败的问题
        maven { url = uri("https://mirrors.tencent.com/nexus/repository/maven-public/") }

        // 2. Flutter 国内镜像：负责下载 Flutter 引擎核心包 (保持不变)
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }

        google()
        mavenCentral()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}
include(":app")