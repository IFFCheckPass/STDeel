import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.stdeel.steel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            val prop = Properties()
            val keyProps = project.rootProject.file("key.properties")
            if (keyProps.exists()) {
                prop.load(keyProps.inputStream())
            }
            storeFile = project.rootProject.file(
                prop.getProperty("storeFile", "upload-keystore.jks"),
            )
            storePassword = prop.getProperty("storePassword", "")
            keyAlias = prop.getProperty("keyAlias", "")
            keyPassword = prop.getProperty("keyPassword", "")
            // 签名方案固定为「仅 v2」：
            // 实测荣耀 30（HarmonyOS 4.2）对 v1+v2+v3 全签名 APK 报"没有证书"无法安装，
            // 而仅 v2 签名的 0.7.4/0.7.5 可正常安装（证书相同，差异只在签名方案）。
            // 故显式关闭 v1/v3，保持与 0.7.4 完全一致的 v2-only 签名。
            enableV1Signing = false
            enableV2Signing = true
            enableV3Signing = false
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.stdeel.steel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = if (project.hasProperty("signingEnabled")) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // 应用内更新：FileProvider 分享下载的 APK 给系统安装器
    implementation("androidx.core:core:1.13.1")
}
