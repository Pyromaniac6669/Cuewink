#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
export CLANG_MODULE_CACHE_PATH="$project_root/.tmp/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_root/.tmp/module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

swift_options=(
    --package-path "$project_root"
    --scratch-path "$project_root/.build"
    --cache-path "$project_root/.tmp/swiftpm/cache"
    --config-path "$project_root/.tmp/swiftpm/config"
    --security-path "$project_root/.tmp/swiftpm/security"
    --manifest-cache local
    --disable-dependency-cache
    --configuration release
)
xcrun swift build "${swift_options[@]}" --product Cuewink
binary_dir="$(xcrun swift build "${swift_options[@]}" --show-bin-path)"
app_path="$project_root/build/Cuewink.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_dir/Cuewink" "$app_path/Contents/MacOS/Cuewink"
cp "$project_root/Resources/Info.plist" "$app_path/Contents/Info.plist"
cp "$project_root/Resources/Cuewink.icns" "$app_path/Contents/Resources/Cuewink.icns"
cp "$project_root/Resources/MenuBarTemplate.png" "$app_path/Contents/Resources/MenuBarTemplate.png"
cp "$project_root/Resources/MenuBarTemplate@2x.png" "$app_path/Contents/Resources/MenuBarTemplate@2x.png"
codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --strict "$app_path"
printf '已构建：%s\n' "$app_path"
