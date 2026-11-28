package de.nglab.sentinel.kern.netz

import io.ktor.client.HttpClient
import io.ktor.client.engine.js.Js

actual fun plattformClient(): HttpClient = HttpClient(Js) {
    expectSuccess = false
}
