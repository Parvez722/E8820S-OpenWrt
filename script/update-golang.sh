#!/usr/bin/env bash
set -euo pipefail

MF="./feeds/packages/lang/golang/golang/Makefile"   # 你的目标文件
NEW_MM="1.25"
NEW_PATCH="3"
NEW_HASH="a81a4ba593d0015e10c51e267de3ff07c7ac914dfca037d9517d029517097795"

[[ -f "$MF" ]] || { echo "找不到文件：$MF" >&2; exit 1; }

# 先备份
cp -f "$MF" "$MF.bak"

if grep -qE '^GO_VERSION_MAJOR_MINOR' "$MF"; then
  # 形式：GO_VERSION_MAJOR_MINOR / GO_VERSION_PATCH
  sed -i.bak -E \
    -e "s|^(GO_VERSION_MAJOR_MINOR[[:space:]]*[:?]?=)[[:space:]]*[0-9]+\.[0-9]+|\1 ${NEW_MM}|" \
    -e "s|^(GO_VERSION_PATCH[[:space:]]*[:?]?=)[[:space:]]*[0-9]+|\1 ${NEW_PATCH}|" \
    -e "s|^(PKG_HASH[[:space:]]*[:?]?=)[[:space:]]*[0-9a-f]{64}|\1 ${NEW_HASH}|" \
    "$MF"
else
  # 形式：GO_VERSION=1.XX.Y
  sed -i.bak -E \
    -e "s|^(GO_VERSION[[:space:]]*[:?]?=).*|\1 ${NEW_MM}.${NEW_PATCH}|" \
    -e "s|^(PKG_HASH[[:space:]]*[:?]?=)[[:space:]]*[0-9a-f]{64}|\1 ${NEW_HASH}|" \
    "$MF"
fi

echo "修改完成（已保存备份：$MF.bak）。当前关键行："
grep -nE '^(GO_VERSION(_MAJOR_MINOR|_PATCH)?|PKG_HASH)[[:space:]]*[:?]?=' "$MF" || true
