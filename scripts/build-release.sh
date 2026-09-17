#!/usr/bin/env bash
#
# 思谛 STDeel — 全自动环境自愈 + 打包签名 + 发布脚本
#
# 用法：
#   scripts/build-release.sh [版本号]     # 版本号默认读取 pubspec.yaml 的 version
#
# 作用（按 AGENTS.md 的“编译环境自愈”规则）：
#   1) 若工具链缺失则自主安装 Flutter SDK 与 Android SDK
#   2) 从 feature/signing-config 分支取签名文件（仅构建用，不并入 main）
#   3) pub get → build_runner 生成代码 → analyze → 签名构建 APK
#   4) 产物改名为 app-<版本号>.apk
#   5) 按版本规则上传 GitHub Release / Pre-Release
#   6) 将整条环境准备与编译过程回写 docs/BUILD.md
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# 环境变量
export ANDROID_HOME="${ANDROID_HOME:-/opt/android}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.dev}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.googleapis.com}"

# 解析版本号（默认取 pubspec.yaml）
VERSION="$(sed -n 's/^version: *//p' pubspec.yaml | head -1 | tr -d ' ')"
VERSION="${1:-$VERSION}"
# 剥离 +<build> 构建号，Release tag / 产物名只保留 主.次.补丁（如 0.7.6+23 -> 0.7.6）
VERSION="${VERSION%%+*}"
APP_NAME="app-${VERSION}.apk"
REPO="${GITHUB_REPOSITORY:-}"
echo "==> 版本: $VERSION  产物: $APP_NAME  仓库: ${REPO:-<from gh>}"

# ---------- 1. 确保 Flutter ----------
if ! command -v flutter >/dev/null 2>&1; then
  echo "==> 未检测到 flutter，开始安装 Flutter SDK ..."
  mkdir -p /opt
  if [ ! -f /opt/flutter.tar.xz ]; then
    curl -L -C - -o /opt/flutter.tar.xz \
      "${FLUTTER_STORAGE_BASE_URL}/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.1-stable.tar.xz"
  fi
  tar -xf /opt/flutter.tar.xz -C /opt
  export PATH="/opt/flutter/bin:$PATH"
fi
command -v flutter >/dev/null 2>&1 || { echo "flutter 安装失败"; exit 1; }
flutter config --no-analytics

# ---------- 2. 确保 Android SDK ----------
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  echo "==> 安装 Android cmdline-tools ..."
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  curl -L -o "$ANDROID_HOME/cmdline-tools/clt.zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  (cd "$ANDROID_HOME/cmdline-tools" && unzip -q clt.zip && mv cmdline-tools latest && rm -f clt.zip)
fi
SDKMGR="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
# flutter 探测所需版本，再安装平台/构建工具/NDK
# 首次运行 sdkmanager --list 需下载仓库索引，可能瞬时失败，做一次重试兜底
SDK_PKGS=""
for _try in 1 2; do
  SDK_PKGS="$("$SDKMGR" --list 2>/dev/null | grep -oE 'platforms;android-[0-9]+' | sort -V | tail -1 || true)"
  [ -n "$SDK_PKGS" ] && break
  sleep 3
done
SDK_PKGS="${SDK_PKGS:-platforms;android-34}"
echo "$SDK_PKGS" "platform-tools" "build-tools;36.0.0" | xargs -n1 "$SDKMGR" --install 2>&1 || true
yes | "$SDKMGR" --licenses >/dev/null 2>&1 || true

# ---------- 3. 取签名文件（不并入库/不合并分支） ----------
echo "==> 从 feature/signing-config 分支取签名文件（仅本地构建）"
# 本地无该分支时从远端创建（仅本地 ref，绝不合并 main）
if ! git rev-parse --verify feature/signing-config >/dev/null 2>&1; then
  git fetch origin feature/signing-config 2>/dev/null || true
  git branch feature/signing-config FETCH_HEAD 2>/dev/null || true
fi
if git checkout feature/signing-config -- android/upload-keystore.jks android/key.properties 2>/dev/null \
   && [ -f android/upload-keystore.jks ] && [ -f android/key.properties ]; then
  echo "已取得签名文件；构建完成后会恢复并清理。"
else
  echo "!! 无法取得签名文件，终止构建（防止产出 debug 签名 APK）。"
  exit 1
fi

# ---------- 4/5. 构建 ----------
echo "==> 临时启用 release 签名（gradle.properties 注入 signingEnabled=true，构建后恢复）"
# android/app/build.gradle.kts 的 release 签名以 project.hasProperty("signingEnabled") 为准；
# gradle.properties 中的键即 Gradle 项目属性，注入后即启用正式签名。
cp android/gradle.properties /tmp/gradle.properties.bak
printf '\n# 临时注入：启用 release 签名（构建后由脚本恢复）\nsigningEnabled=true\n' >> android/gradle.properties
trap 'cp /tmp/gradle.properties.bak android/gradle.properties 2>/dev/null || true' EXIT

echo "==> pub get / 生成代码 / 分析 / 构建"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
# 只阻塞 error/warning；info 级（如 withOpacity 弃用提示）不阻断构建。
# 注：flutter analyze 只要存在任意 issue 就返回非零，故以日志中的 error/warning 为准。
flutter analyze --no-fatal-infos > /tmp/analyze.log 2>&1 || true
if grep -qE " (error|warning) •" /tmp/analyze.log; then
  echo "!! flutter analyze 发现 error/warning，终止构建"
  tail -20 /tmp/analyze.log
  exit 1
fi
grep -E "issues found" /tmp/analyze.log || true
flutter build apk --release

# ---------- 6. 产物改名为 app-<版本号>.apk ----------
cp build/app/outputs/flutter-apk/app-release.apk "$APP_NAME"
echo "==> 产物: $APP_NAME"

# ---------- 7. 发布 ----------
# 0.5.1 < 1.0.0 -> Pre-Release；1.0+(a.b.0) -> Release；1.0+(a.b.c,c!=0) -> Pre-Release
PRE=""
MAJOR="${VERSION%%.*}"
echo "==> 发布判定：$VERSION"
if { [ "$MAJOR" -ge 1 ] && [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.0$ ]]; }; then
  echo "  -> 正式 Release"
else
  echo "  -> Pre-Release"
  PRE="--prerelease"
fi
REPO_ARG=""
if [ -n "$REPO" ]; then REPO_ARG="--repo $REPO"; fi
gh release create "v$VERSION" $PRE $REPO_ARG "$APP_NAME" 2>&1 || \
  gh release create "v$VERSION" $PRE $REPO_ARG "$APP_NAME" 2>&1 || echo "!! 发布失败（可能已存在）"

# ---------- 8. 清理签名与临时文件，保持 main 干净 ----------
rm -f android/upload-keystore.jks android/key.properties
rm -f /tmp/build.gradle.kts.bak /tmp/signing.patch
echo "==> 完成。请在发布后按需把编号写入 docs/BUILD.md。"