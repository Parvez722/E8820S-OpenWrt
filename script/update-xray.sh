#!/usr/bin/env bash
set -euo pipefail

want_ver="${1:-latest}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "缺少命令：$1" >&2; exit 1; }; }
for c in curl sha256sum sed awk grep; do need_cmd "$c"; done

# ---- 1) 自动定位 xray-core Makefile ----
mapfile -t MF_LIST < <(
  {
    ls -1 feeds/*/net/xray-core/Makefile 2>/dev/null || true
    ls -1 package/feeds/*/xray-core/Makefile 2>/dev/null || true
    ls -1 package/*/xray-core/Makefile 2>/dev/null || true
  } | sort -u
)

if [[ ${#MF_LIST[@]} -eq 0 ]]; then
  mapfile -t MF_LIST < <(find feeds package -type f -path '*/xray-core/Makefile' 2>/dev/null | sort -u)
fi
[[ ${#MF_LIST[@]} -gt 0 ]] || { echo "未找到 xray-core/Makefile"; exit 1; }

echo "→ 将更新以下文件："
printf '  - %s\n' "${MF_LIST[@]}"

# ---- 2) 取得目标版本号（tag）----
get_latest_tag() {
  local tag
  # 先用 API，失败再用 302 跟随
  tag="$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\(v[^"]*\)".*/\1/p' \
        | head -n1 || true)"
  if [[ -z "$tag" ]]; then
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}\n' \
          https://github.com/XTLS/Xray-core/releases/latest \
          | awk -F/ '{print $NF}')"
  fi
  printf '%s' "$tag"
}

if [[ "$want_ver" == "latest" ]]; then
  tag="$(get_latest_tag)"
else
  [[ "$want_ver" == v* ]] && tag="$want_ver" || tag="v$want_ver"
fi
[[ -n "$tag" ]] || { echo "获取版本失败"; exit 1; }
ver="${tag#v}"

# ---- 3) 计算 SHA256（按常见两种 URL 依次尝试）----
echo "→ 目标版本: ${ver} (${tag})"
urls=(
  "https://codeload.github.com/XTLS/Xray-core/tar.gz/${tag}"
  "https://github.com/XTLS/Xray-core/archive/refs/tags/${tag}.tar.gz"
)

sha256=""
tar_url=""
for u in "${urls[@]}"; do
  echo "→ 尝试获取: $u"
  if sha="$(curl -fsSL "$u" | sha256sum | awk '{print $1}')" && [[ -n "$sha" ]]; then
    sha256="$sha"; tar_url="$u"; break
  fi
done
[[ -n "$sha256" ]] || { echo "计算 SHA256 失败"; exit 1; }
echo "→ 使用 Tarball: $tar_url"
echo "→ SHA256:       $sha256"

# ---- 4) 回写各 Makefile（仅更新版本与哈希）----
for MF in "${MF_LIST[@]}"; do
  echo "→ 更新 $MF"

  # 读取当前值
  old_ver="$(sed -nE 's/^PKG_VERSION[[:space:]]*[:?]?=([0-9][^[:space:]]*)/\1/p' "$MF" | head -n1 || true)"
  old_hash="$(sed -nE 's/^PKG_HASH[[:space:]]*[:?]?=([0-9a-f]{64})/\1/p' "$MF" | head -n1 || true)"
  old_mhash="$(sed -nE 's/^PKG_MIRROR_HASH[[:space:]]*[:?]?=([0-9a-f]{64})/\1/p' "$MF" | head -n1 || true)"
  echo "   当前: ver=${old_ver:-N/A} hash=${old_hash:-N/A} mirror=${old_mhash:-N/A}"

  # 替换时保留原来的赋值操作符（:= 或 ?=）
  sed -i -E \
    -e "s|^PKG_VERSION([[:space:]]*[:?]?=).*|PKG_VERSION\1${ver}|" \
    -e "s|^PKG_HASH([[:space:]]*[:?]?=).*|PKG_HASH\1${sha256}|" \
    -e "s|^PKG_MIRROR_HASH([[:space:]]*[:?]?=).*|PKG_MIRROR_HASH\1${sha256}|" \
    "$MF"

  # 显示结果（不动 PKG_SOURCE_URL，防止误改）
  grep -E '^(PKG_VERSION|PKG_HASH|PKG_MIRROR_HASH|PKG_SOURCE_URL)[[:space:]]*[:?]?=' "$MF" || true
done

echo "✔ 完成"
