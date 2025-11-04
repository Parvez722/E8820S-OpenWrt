
want_ver="${1:-latest}"

# ---- 1) 自动定位 xray-core Makefile ----
mapfile -t MF_LIST < <(
  {
    ls -1 feeds/*/net/xray-core/Makefile 2>/dev/null || true
    ls -1 package/feeds/*/xray-core/Makefile 2>/dev/null || true
  } | sort -u
)

if [[ ${#MF_LIST[@]} -eq 0 ]]; then
  # 兜底：全树搜索（慢一点，但只在前两类没找到时用）
  mapfile -t MF_LIST < <(find feeds package -type f -path '*/xray-core/Makefile' 2>/dev/null | sort -u)
fi

if [[ ${#MF_LIST[@]} -eq 0 ]]; then
  echo "未找到 xray-core/Makefile。请确认已执行 feeds 并包含 xray-core 包。" >&2
  exit 1
fi

echo "→ 将更新以下文件："
printf '  - %s\n' "${MF_LIST[@]}"

# ---- 2) 取得目标版本号 ----
get_latest_tag() {
  local tag
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
[[ -n "$tag" ]] || { echo "获取最新版本失败"; exit 1; }
ver="${tag#v}"

tar_url="https://codeload.github.com/XTLS/Xray-core/tar.gz/v${ver}"
echo "→ 目标版本: ${ver} (${tag})"
echo "→ Tarball:  ${tar_url}"

# ---- 3) 计算 SHA256 ----
echo "→ 计算 SHA256 中..."
sha256="$(curl -fsSL "$tar_url" | sha256sum | awk '{print $1}')"
[[ -n "$sha256" ]] || { echo "计算 SHA256 失败"; exit 1; }
echo "→ SHA256:   ${sha256}"

# ---- 4) 回写各 Makefile ----
for MF in "${MF_LIST[@]}"; do
  echo "→ 更新 $MF"
  old_ver="$(sed -nE 's/^PKG_VERSION:=([0-9][^[:space:]]*)/\1/p' "$MF" | head -n1 || true)"
  old_hash="$(sed -nE 's/^PKG_HASH:=([0-9a-f]{64})/\1/p' "$MF" | head -n1 || true)"
  echo "   当前: ver=${old_ver:-N/A} hash=${old_hash:-N/A}"

  sed -i -E \
    -e "s|^(PKG_VERSION):=.*|\1:=${ver}|" \
    -e "s|^(PKG_SOURCE_URL):=.*|\1:=https://codeload.github.com/XTLS/Xray-core/tar.gz/v\$(PKG_VERSION)?|" \
    -e "s|^(PKG_HASH):=.*|\1:=${sha256}|" \
    "$MF"

  # 显示结果
  grep -E '^(PKG_VERSION|PKG_SOURCE_URL|PKG_HASH):=' "$MF"
done

echo "✔ 完成"
