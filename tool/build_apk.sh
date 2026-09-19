#!/usr/bin/env bash
# jianli-mobile-app 一键打包脚本
# 用法：在 Git Bash 中执行  bash tool/build_apk.sh
#
# 版本号规则（年.月.日.版本）：
#   当天第 1 次构建 -> versionName = 26.9.19        （pubspec 存 26.9.19+1）
#   当天第 5 次构建 -> versionName = 26.9.19.4      （pubspec 存 26.9.19+5）
#   说明：pubspec.yaml 只能存三段 semver（x.y.z+N），四段显示名由
#         android/app/build.gradle.kts 用「N-1」后缀拼接出来。
#   versionCode 由「日期 + 构建序号」推导（如 26091905），跨天单调递增，
#   避免覆盖安装报 INSTALL_FAILED_VERSION_DOWNGRADE。

set -e
cd "$(dirname "$0")/.."

# ---------- 1. 版本号自增 ----------
PUBSPEC="pubspec.yaml"
TODAY="$(date +%y.%-m.%-d)"
CUR_LINE="$(grep -E '^version:' "$PUBSPEC" | head -1 | sed -E 's/^version:[[:space:]]*//')"
VER_DATE="$(sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+.*/\1/' <<<"$CUR_LINE")"
N="$(sed -E 's/^[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+).*/\1/' <<<"$CUR_LINE")"

if [ -z "$VER_DATE" ] || [ -z "$N" ]; then
  echo "!! 无法解析 $PUBSPEC 中的 version 行: '$CUR_LINE'，退出。" >&2
  exit 1
fi

if [ "$VER_DATE" = "$TODAY" ]; then
  N=$((N + 1))
else
  N=1
fi

NEW_VERSION="$TODAY+$N"
if [ "$N" -eq 1 ]; then
  DISPLAY_VERSION="$TODAY"
else
  DISPLAY_VERSION="$TODAY.$((N - 1))"
fi

sed -i -E "s/^version:.*$/version: $NEW_VERSION/" "$PUBSPEC"
echo "==> 版本号已更新: $DISPLAY_VERSION (pubspec: $NEW_VERSION)"

# ---------- 2. 打包前环境准备 ----------
export TMP=C:/src/tmp TEMP=C:/src/tmp
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export ANDROID_HOME=C:/apps/Android/AndroidSDK ANDROID_SDK_ROOT=C:/apps/Android/AndroidSDK
export GRADLE_USER_HOME=C:/src/gradle-home
export JAVA_HOME="/c/apps/Android/Android Studio/jbr"

# flutter 命令：优先用 PATH 里的，兜底本地 SDK
if command -v flutter >/dev/null 2>&1; then
  FLUTTER="flutter"
else
  FLUTTER="C:/src/flutter/bin/flutter.bat"
fi

# ---------- 3. 构建 ----------
echo "==> 开始构建 release APK (split-per-abi) ..."
"$FLUTTER" build apk --release --split-per-abi

# ---------- 4. 产物列表 ----------
OUT_DIR="build/app/outputs/flutter-apk"
echo "==> 构建完成，产物："
ls -lh "$OUT_DIR" 2>/dev/null || echo "（请自行查看 $OUT_DIR）"
