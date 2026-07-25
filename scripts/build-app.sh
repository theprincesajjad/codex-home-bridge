#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_dir/dist/Codex Home Bridge.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
swift build -c release

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$project_dir/.build/release/CodexHomeBridge" "$contents_dir/MacOS/CodexHomeBridge"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
