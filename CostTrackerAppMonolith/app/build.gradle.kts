plugins { id("com.android.application") version "8.4.0" apply false }
plugins { id("org.jetbrains.kotlin.android") version "1.9.0" }
android {
  compileSdk = 33
  defaultConfig { applicationId = "com.example.costtracker"; minSdk = 21; targetSdk = 33; versionCode = 1; versionName = "0.1" }
  buildTypes { debug { isDebuggable = true } }
}
repositories { google(); mavenCentral() }
dependencies { implementation("org.jetbrains.kotlin:kotlin-stdlib") testImplementation("junit:junit:4.13.2") testImplementation("org.jetbrains.kotlin:kotlin-test-junit:1.9.0") }
