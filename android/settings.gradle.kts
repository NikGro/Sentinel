// SENTINEL für Android: Jetpack Compose (Material 3 Expressive), MapLibre, gemeinsamer Kern aus ../kern.
pluginManagement {
    repositories {
        google()
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "sentinel-android"
include(":app")
// Gemeinsamer Kern als eingebundener Build: `de.nglab.sentinel:kern` kommt direkt aus dem Quelltext.
includeBuild("../kern")
