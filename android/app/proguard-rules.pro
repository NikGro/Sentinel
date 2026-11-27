# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-keepclassmembers class de.nglab.sentinel.kern.** { *** Companion; }
-keepclasseswithmembers class de.nglab.sentinel.kern.** { kotlinx.serialization.KSerializer serializer(...); }
-keep class de.nglab.sentinel.kern.**$$serializer { *; }
# MapLibre
-keep class org.maplibre.** { *; }
-dontwarn org.slf4j.**
-dontwarn io.ktor.**
