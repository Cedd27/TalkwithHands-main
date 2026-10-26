import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProps = Properties().apply {
    val localFile = rootProject.file("local.properties")
    if (localFile.exists()) {
        localFile.inputStream().use { load(it) }
    }
}

fun localOrEnv(name: String, fallback: String = ""): String {
    return (localProps.getProperty(name) ?: System.getenv(name) ?: fallback).trim()
}

val facebookAppId = localOrEnv("FACEBOOK_APP_ID", "0")
val facebookClientToken = localOrEnv("FACEBOOK_CLIENT_TOKEN", "")

android {
    namespace = "com.example.sign_language_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
            applicationId = "com.example.sign_language_app"
            
            // Change this line:
            minSdk = flutter.minSdkVersion 
            
            targetSdk = flutter.targetSdkVersion
            versionCode = flutter.versionCode
            versionName = flutter.versionName
            ndk {
                abiFilters.clear()
                abiFilters += listOf("arm64-v8a")
            }
            resValue("string", "facebook_app_id", facebookAppId)
            resValue("string", "facebook_client_token", facebookClientToken)
            resValue("string", "fb_login_protocol_scheme", "fb$facebookAppId")
            manifestPlaceholders["fbLoginProtocolScheme"] = "fb$facebookAppId"
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

dependencies {
    implementation("org.tensorflow:tensorflow-lite-select-tf-ops:+")
}
