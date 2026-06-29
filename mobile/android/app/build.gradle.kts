plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lifescale.mobile.lifescale_mobile"
    // 锁定 35：本机已装 platforms/android-35（未装 36），避免触发 android-36 平台下载。
    // 应用仍可在 Vivo X100（API 36）上正常运行（向下兼容）。
    compileSdk = 35
    // Flutter 插件链要求 27.0.12077973；本机已安装，显式锁定可消除构建期 NDK 版本告警。
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 唯一 Application ID（用于 ADB run-as 与 APK 安装）。
        // 注意：beta flavor 会追加 .beta 后缀，实现与正式版共存。
        applicationId = "com.lifescale.mobile.lifescale_mobile"
        // minSdk 24（Android 7.0）覆盖广；Vivo X100 为 Android 16/API 36，向下兼容。
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ---- 渠道（flavor）：测试版 beta / 正式版 prod ----
    // 通过 --flavor beta|prod 选择；两套图标、包名、应用名物理隔离，可同机共存。
    flavorDimensions += "channel"
    productFlavors {
        create("prod") {
            dimension = "channel"
            // 正式版：保持默认 applicationId / app_name，无版本后缀
            resValue("string", "app_name", "LifeScale")
        }
        create("beta") {
            dimension = "channel"
            // 测试版：包名追加 .beta（可与正式版同时安装），版本名加 -beta 后缀，应用名带「测试版」
            applicationIdSuffix = ".beta"
            versionNameSuffix = "-beta"
            resValue("string", "app_name", "LifeScale 测试版")
        }
    }

    buildTypes {
        release {
            // 当前 release 暂用 debug 签名（仅限内测/自用安装）。
            // 上架应用商店前需换成正式 keystore：
            //   1) keytool 生成 keystore → 放 mobile/ 下（已被 .gitignore 忽略）
            //   2) 新建 mobile/android/key.properties 填签名信息
            //   3) 把下行 signingConfig 改为读取 key.properties 的正式 signingConfig
            // 详细步骤见 docs/deployment/客户端打包指南.md。
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
