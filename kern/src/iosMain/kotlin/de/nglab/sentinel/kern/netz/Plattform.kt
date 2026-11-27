package de.nglab.sentinel.kern.netz

import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin

actual fun plattformClient(): HttpClient = HttpClient(Darwin) {
    expectSuccess = false
    engine {
        // Kein Zwischenspeicher auf der Platte, keine Cookies (wie bisher).
        configureSession {
            setURLCache(null)
            setHTTPCookieStorage(null)
        }
    }
}
