#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/cost-tracker-app-5821-5906/CostTrackerAppMonolith"
SDK_ROOT="/opt/android-sdk"
CMDLINE_URL_BASE="https://dl.google.com/android/repository/"
CMDLINE_FILENAME="commandlinetools-linux-latest.zip"
LOG=/tmp/env-001.log
: >"$LOG"
# Minimal package install (idempotent)
sudo apt-get update -qq >/dev/null && sudo apt-get install -y --no-install-recommends unzip zip curl wget >/dev/null
# Ensure JDK present (use existing if >=11)
if ! command -v javac >/dev/null 2>&1; then
  sudo apt-get install -y --no-install-recommends openjdk-17-jdk >/dev/null
fi
JAVA_BIN=$(readlink -f "$(command -v javac || true)" || true)
if [ -z "$JAVA_BIN" ]; then echo "ERROR: javac not found" | tee -a "$LOG" >&2; exit 11; fi
JAVA_HOME=$(dirname "$(dirname "$JAVA_BIN")")
# Ensure SDK root exists and ownership is safe
sudo mkdir -p "$SDK_ROOT"
if [ "$(id -u)" -ne 0 ]; then
  owner_uid=$(stat -c %u "$SDK_ROOT" || echo 0)
  if [ "$owner_uid" != "$(id -u)" ]; then
    sudo chown -R "$(id -u):$(id -g)" "$SDK_ROOT" || true
  fi
fi
# Install cmdline-tools if missing
if [ ! -x "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  curl -fsSLo "$tmpdir/$CMDLINE_FILENAME" "${CMDLINE_URL_BASE}${CMDLINE_FILENAME}" || { echo "ERROR: cmdline-tools download" | tee -a "$LOG" >&2; exit 14; }
  unzip -q "$tmpdir/$CMDLINE_FILENAME" -d "$tmpdir" || { echo "ERROR: unzip cmdline-tools" | tee -a "$LOG" >&2; exit 15; }
  inner=$(find "$tmpdir" -type f -name sdkmanager -print -quit || true)
  if [ -z "$inner" ]; then echo "ERROR: sdkmanager not found in archive" | tee -a "$LOG" >&2; exit 16; fi
  innerdir=$(dirname "$inner")
  sudo mkdir -p "$SDK_ROOT/cmdline-tools/latest"
  sudo rm -rf "$SDK_ROOT/cmdline-tools/latest"/* || true
  sudo cp -a "$innerdir/"* "$SDK_ROOT/cmdline-tools/latest/"
  sudo chmod -R a+rx "$SDK_ROOT/cmdline-tools/latest"
fi
# Persist env with expanded absolute values
ENV_FILE=/etc/profile.d/android_env.sh
sudo bash -c "cat > $ENV_FILE <<'EOF'
export JAVA_HOME=${JAVA_HOME}
export ANDROID_SDK_ROOT=${SDK_ROOT}
PATH=\"${SDK_ROOT}/cmdline-tools/latest/bin:${SDK_ROOT}/platform-tools:\$PATH\"
export PATH
EOF"
sudo chmod 0755 "$ENV_FILE"
# Export for current shell
export JAVA_HOME="$JAVA_HOME"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/platform-tools:$PATH"
SDKMAN="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
[ -x "$SDKMAN" ] || { echo "ERROR: sdkmanager missing" | tee -a "$LOG" >&2; exit 17; }
# Accept licenses non-interactively with retries
for i in 1 2 3; do
  yes | "$SDKMAN" --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null 2>&1 && break || sleep 2
done || { echo "ERROR: sdk licenses acceptance failed" | tee -a "$LOG" >&2; exit 18; }
# Install required SDK packages
TMPLOG=/tmp/sdk_install.log
"$SDKMAN" --sdk_root="$ANDROID_SDK_ROOT" "platform-tools" "platforms;android-33" "build-tools;33.0.2" >"$TMPLOG" 2>&1 || { tail -n 200 "$TMPLOG" | tee -a "$LOG"; echo "ERROR: sdkmanager install failed" | tee -a "$LOG" >&2; exit 19; }
# Verify and log concise info
java -version > /tmp/env_java_version 2>&1 || true
javac -version > /tmp/env_javac_version 2>&1 || true
"$SDKMAN" --version > /tmp/env_sdkmanager_version 2>&1 || true
if [ -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]; then "$ANDROID_SDK_ROOT/platform-tools/adb" version > /tmp/env_adb_version 2>&1 || true; fi
{
  echo "JAVA_HOME=$JAVA_HOME"
  echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
  head -n1 /tmp/env_java_version 2>/dev/null || true
  head -n1 /tmp/env_javac_version 2>/dev/null || true
  head -n1 /tmp/env_sdkmanager_version 2>/dev/null || true
  head -n1 /tmp/env_adb_version 2>/dev/null || true
  tail -n 50 "$TMPLOG" 2>/dev/null || true
} > "$LOG"
echo "ENV_OK" > /tmp/env-001.done
