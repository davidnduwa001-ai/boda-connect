pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }

    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = java.io.File(settingsDir, "local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }
        val path = properties.getProperty("flutter.sdk")
        requireNotNull(path) { "flutter.sdk not set in local.properties" }
        path
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // Android Gradle Plugin (supports SDK 35)
    id("com.android.application") version "8.4.2" apply false
    id("com.android.library") version "8.4.2" apply false

    // Kotlin (Flutter-compatible) - Updated for Firebase compatibility
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false

    // Google services
    id("com.google.gms.google-services") version "4.4.2" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("https://jitpack.io") }
    }
}

include(":app")
