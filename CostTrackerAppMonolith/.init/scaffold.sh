#!/usr/bin/env bash
set -euo pipefail
# Scaffolding script for minimal Kotlin Android app and Gradle wrapper
WORKSPACE="/home/kavia/workspace/code-generation/cost-tracker-app-5821-5906/CostTrackerAppMonolith"
cd "$WORKSPACE"
# If project present, validate gradlew if exists
if [ -f settings.gradle.kts ] || [ -f settings.gradle ] || [ -d app ]; then
  if [ -x ./gradlew ]; then ./gradlew --version >/tmp/scaffold_gradle_version 2>&1 || { echo "ERROR: existing gradlew broken" >&2; exit 22; }; fi
  exit 0
fi
# Scaffold minimal project structure
mkdir -p app/src/main/{java/com/example/costtracker,res/values,res/layout}
cat > settings.gradle.kts <<'EOF'
pluginManagement { repositories { gradlePluginPortal(); google(); mavenCentral() } }
rootProject.name = "CostTrackerAppMonolith"
include(":app")
EOF
cat > build.gradle.kts <<'EOF'
plugins { kotlin("jvm") version "1.9.0" apply false }
allprojects { repositories { google(); mavenCentral() } }
EOF
cat > app/build.gradle.kts <<'EOF'
plugins { id("com.android.application") version "8.4.0" apply false }
plugins { id("org.jetbrains.kotlin.android") version "1.9.0" }
android {
  compileSdk = 33
  defaultConfig { applicationId = "com.example.costtracker"; minSdk = 21; targetSdk = 33; versionCode = 1; versionName = "0.1" }
  buildTypes { debug { isDebuggable = true } }
}
repositories { google(); mavenCentral() }
dependencies { implementation("org.jetbrains.kotlin:kotlin-stdlib") testImplementation("junit:junit:4.13.2") }
EOF
cat > app/src/main/AndroidManifest.xml <<'EOF'
<manifest package="com.example.costtracker">
  <application android:label="CostTracker">
    <activity android:name=".MainActivity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
      </intent-filter>
    </activity>
  </application>
</manifest>
EOF
cat > app/src/main/java/com/example/costtracker/MainActivity.kt <<'EOF'
package com.example.costtracker
import android.app.Activity
import android.os.Bundle
class MainActivity: Activity() {
  override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState) }
}
EOF
cat > app/src/main/res/values/strings.xml <<'EOF'
<resources><string name="app_name">CostTracker</string></resources>
EOF
cat > app/src/main/res/layout/activity_main.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android" android:layout_width="match_parent" android:layout_height="match_parent" />
EOF
# Ensure Gradle wrapper: prefer system gradle
if command -v gradle >/dev/null 2>&1; then
  gradle wrapper --gradle-version 8.4 --distribution-type all >/dev/null
else
  # Bootstrap wrapper by downloading Gradle distribution and extracting gradle-wrapper.jar
  DIST_URL="https://services.gradle.org/distributions/gradle-8.4-all.zip"
  tmpd=$(mktemp -d)
  trap 'rm -rf "${tmpd}"' EXIT
  curl -fsSLo "$tmpd/gradle-8.4-all.zip" "$DIST_URL" || { echo "ERROR: cannot download gradle distribution" >&2; exit 23; }
  unzip -q "$tmpd/gradle-8.4-all.zip" -d "$tmpd" || { echo "ERROR: unzip gradle distribution" >&2; exit 24; }
  # find wrapper jar inside extracted distribution
  gwjar=$(find "$tmpd" -type f -name gradle-wrapper.jar -print -quit || true)
  if [ -z "$gwjar" ]; then
    mkdir -p gradle/wrapper
    cat > gradle/wrapper/gradle-wrapper.properties <<'EOF'
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip
EOF
    extracted_jar=$(find "$tmpd" -name "gradle-wrapper*.jar" -print -quit || true)
    if [ -n "$extracted_jar" ]; then mkdir -p gradle/wrapper; cp "$extracted_jar" gradle/wrapper/gradle-wrapper.jar; fi
  else
    mkdir -p gradle/wrapper; cp "$gwjar" gradle/wrapper/gradle-wrapper.jar
    cat > gradle/wrapper/gradle-wrapper.properties <<'EOF'
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip
EOF
  fi
fi
# Ensure gradlew script exists and is executable
if [ ! -f gradlew ]; then cat > gradlew <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
BASEDIR=$(cd "$(dirname "$0")" && pwd)
JAVA_EXE="$(command -v java || true)"
if [ -z "$JAVA_EXE" ]; then echo "ERROR: java not found" >&2; exit 2; fi
if [ -f "$BASEDIR/gradle/wrapper/gradle-wrapper.jar" ]; then exec "$JAVA_EXE" -jar "$BASEDIR/gradle/wrapper/gradle-wrapper.jar" "$@"; else echo "ERROR: gradle wrapper jar missing" >&2; exit 3; fi
EOF
chmod +x gradlew
fi
# Validate gradlew
./gradlew --version > /tmp/scaffold_gradle_version 2>&1 || { tail -n 200 /tmp/scaffold_gradle_version >&2; echo "ERROR: gradlew invalid" >&2; exit 25; }
# Mark done
echo "SCAFFOLD_OK" > /tmp/scaffold-002.done
