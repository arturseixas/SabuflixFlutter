import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }
fun signingValue(name: String, env: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: signingProperties.getProperty(name)
val releaseStore = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseStorePassword = signingValue("storePassword", "ANDROID_STORE_PASSWORD")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
    check(listOf(releaseStore, releaseAlias, releaseStorePassword, releaseKeyPassword).all { !it.isNullOrBlank() }) {
        "Configure android/key.properties or ANDROID_* signing variables before building a release."
    }
}

android {
    namespace = "com.sabuflix.app.sabuflix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sabuflix.app.sabuflix"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = releaseStore?.let { file(it) }
            keyAlias = releaseAlias
            storePassword = releaseStorePassword
            keyPassword = releaseKeyPassword
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("release") }
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
