import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (push notifications) switches on as soon as a google-services.json that
// contains this app (com.dyspatch.rider) is present — Firebase console → project
// dyspatch-bc9cc → Add app → Android. Until then the app builds and works without
// push, and job offers arrive by polling while the rider is online.
val googleServices = file("google-services.json")
if (googleServices.exists() && googleServices.readText().contains("\"com.dyspatch.rider\"")) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn("google-services.json for com.dyspatch.rider not found — building without Firebase push")
}

// Release signing: android/key.properties + android/app/upload-keystore.jks
// (both git-ignored; CI writes them from repository secrets).
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.dyspatch.rider"
    compileSdk = 36  // ✅ hardcode instead of flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (Java 8+ APIs on older Android)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
        }
    }

    defaultConfig {
        applicationId = "com.dyspatch.rider"
        minSdk = 23         // Firebase Auth / Messaging require 23+
        multiDexEnabled = true
        targetSdk = 35   // Google Play requires API 35+ for new apps/updates
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isNotEmpty()) signingConfigs.getByName("release")
                            else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
