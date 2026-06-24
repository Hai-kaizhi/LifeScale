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
        applicationId = "com.lifescale.mobile.lifescale_mobile"
        // minSdk 24（Android 7.0）覆盖广；Vivo X100 为 Android 16/API 36，向下兼容。
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
