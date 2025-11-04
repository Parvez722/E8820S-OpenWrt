#!/usr/bin/env bash
set -euo pipefail

JOBS="$(nproc)"
OPENWRT_BRANCH="openwrt-24.10"
REPO_URL="https://github.com/openwrt/openwrt"
BUILD_USER="builder"

export JOBS BASE_DIR OPENWRT_BRANCH REPO_URL BUILD_USER

sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk \
  gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
  python3-setuptools rsync swig unzip zlib1g-dev file wget screen -y

if ! id -u "${BUILD_USER}" >/dev/null 2>&1; then
  sudo useradd -m "${BUILD_USER}"
  echo "=== 已创建用户 ${BUILD_USER}（未授予 sudo）。如需 sudo 自行添加到组 ==="
fi

sudo mkdir -p /var/log
sudo touch /var/log/screen.log
sudo chown "$(id -u)":"$(id -g)" /var/log/screen.log   # 确保当前用户可写日志
sudo --preserve-env=JOBS,BASE_DIR,OPENWRT_BRANCH,REPO_URL,BUILD_USER \
  -u "${BUILD_USER}" -H bash -lc '
  set -euo pipefail
  # 必要性检查（如果没传进来会直接报错，便于定位）
  : "${JOBS:?JOBS not set}"
  : "${OPENWRT_BRANCH:?OPENWRT_BRANCH not set}"
  : "${REPO_URL:?REPO_URL not set}"
  : "${BUILD_USER:?BUILD_USER not set}"

  echo "=== 切换到 ${BUILD_USER}，开始准备源码 ==="
  cd ~
  if [ ! -d E8820S-OpenWrt ]; then
    git clone https://github.com/TwoOnefour/E8820S-OpenWrt
  fi

  cd E8820S-OpenWrt
  BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
  # 3.1 克隆源码
  if [ ! -d openwrt ]; then
    git clone "${REPO_URL}" -b "${OPENWRT_BRANCH}" openwrt
  fi

  # 3.2 配置/脚本/补丁
  cp "${BASE_DIR}/config/e8820s-official-openwrt.config" openwrt/.config
  cd openwrt
  chmod a+x "${BASE_DIR}/script/diy-part1.sh" "${BASE_DIR}/script/diy-part2.sh" "${BASE_DIR}/script/update-xray.sh" "${BASE_DIR}/script/update-golang.sh"
  "${BASE_DIR}/script/diy-part1.sh"
  "${BASE_DIR}/script/diy-part2.sh"

  patch -p1 < "${BASE_DIR}/patch/0001-ZTE8820S.patch"
  patch -p2 < "${BASE_DIR}/patch/0002-ramips-add-support-for-mtk-eip93-crypto-engine.patch"

  ./scripts/feeds clean
  ./scripts/feeds update -a
  ./scripts/feeds install -a
  "${BASE_DIR}/script/update-xray.sh"
  "${BASE_DIR}/script/update-golang.sh"

  make defconfig
  make download -j"${JOBS}"
  find dl -size -1024c -exec ls -l {} \;
  find dl -size -1024c -exec rm -f {} \;
  make -j"${JOBS}" || make -j1 V=sc
'
