// SENTINEL: gemeinsamer Kern (Kotlin Multiplatform) und Android-App. Die iOS-App (ios/) bindet den Kern als
// XCFramework ein; der Server (server/) bleibt ein eigenes Node-Projekt.
pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "sentinel"
include(":kern")
// Die Android-App braucht das Android-SDK (in der Pipeline vorhanden); lokal ohne SDK nur der Kern.
if (System.getenv("ANDROID_HOME") != null || file("local.properties").exists()) {
    include(":android")
}
