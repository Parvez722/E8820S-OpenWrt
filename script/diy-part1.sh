#!/bin/bash

echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall;main" >> feeds.conf.default
echo "src-git passwallpackages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
