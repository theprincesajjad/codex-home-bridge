#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_dir/dist/Set It Up.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
swift build -c release

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$project_dir/.build/release/SetItUp" "$contents_dir/MacOS/SetItUp"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"

xattr -cr "$app_dir"
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "$app_dir"
