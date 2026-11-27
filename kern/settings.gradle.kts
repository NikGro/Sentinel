// Gemeinsamer Kern (Kotlin Multiplatform). Eigener Build: lokal ohne Android-SDK testbar, von der Android-App
// (android/) als eingebundener Build genutzt, für iOS als XCFramework gebaut.
pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}

rootProject.name = "kern"
