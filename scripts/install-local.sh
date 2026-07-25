#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
source_app="$project_dir/dist/Set It Up.app"
install_root="$HOME/Applications"
installed_app="$install_root/Set It Up.app"

if [[ ! -d "$source_app" ]]; then
  "$project_dir/scripts/build-app.sh"
fi

mkdir -p "$install_root"
ditto "$source_app" "$installed_app"
xattr -cr "$installed_app"
codesign --verify --deep --strict "$installed_app"
open "$installed_app"
echo "$installed_app"
