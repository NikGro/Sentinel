import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    kotlin("multiplatform") version "2.4.10"
    kotlin("plugin.serialization") version "2.4.10"
}

group = "de.nglab.sentinel"
version = "1.0.0"

kotlin {
    // JVM: für Android (reines Kotlin, keine Android-APIs) und die lokalen Tests; Bytecode für Java 17 (Android).
    jvm {
        compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
    }

    // Web: als JavaScript-Bibliothek für Sentinel Web (gleiche Karten-Szene und Kurzübersichten wie die Apps).
    js(IR) {
        outputModuleName.set("sentinel-kern")
        // Tests laufen auf der JVM; ohne Karma-Testläufer (wird sonst von GitHub nachgeladen).
        browser { testTask { enabled = false } }
        binaries.library()
        generateTypeScriptDefinitions()
        compilerOptions { target.set("es2015") }
    }

    // iOS: als XCFramework „SentinelKern“ (nur auf macOS gebaut).
    val xcf = XCFramework("SentinelKern")
    listOf(iosArm64(), iosSimulatorArm64()).forEach { target ->
        target.binaries.framework {
            baseName = "SentinelKern"
            isStatic = true
            xcf.add(this)
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")
            implementation("io.ktor:ktor-client-core:3.3.2")
            implementation("io.ktor:ktor-client-websockets:3.3.2")
            implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.8.0")
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
        }
        jvmMain.dependencies {
            implementation("io.ktor:ktor-client-okhttp:3.3.2")
        }
        iosMain.dependencies {
            implementation("io.ktor:ktor-client-darwin:3.3.2")
        }
        jsMain.dependencies {
            implementation("io.ktor:ktor-client-js:3.3.2")
        }
    }
}

tasks.withType<JavaCompile>().configureEach {
    sourceCompatibility = "17"
    targetCompatibility = "17"
}
