package de.nglab.sentinel.kern.netz

import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp

actual fun plattformClient(): HttpClient = HttpClient(OkHttp) {
    expectSuccess = false
}
