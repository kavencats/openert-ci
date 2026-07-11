#!/bin/bash
set -euo pipefail

# ============================================
# diy.sh – Cudy TR3000 v1 官方纯净版
# 场景: 仅官方包，无第三方源、无定制插件、无设备调优
# ============================================

# ---------- 1. 第三方源（全部注释掉，只使用官方源）----------
# echo "src-git kiddin9 https://github.com/kiddin9/op-packages.git" >> feeds.conf.default
# echo "src-git oaf https://github.com/destan19/OpenAppFilter.git" >> feeds.conf.default

# ---------- 2. 更新源（注释掉，YAML 中已有 feeds update/install）----------
# export GIT_TERMINAL_PROMPT=0
# for i in 1 2 3; do
#   ./scripts/feeds update -a && break
#   sleep 8
# done
# rm -rf feeds/kiddin9/webd
# ./scripts/feeds update kiddin9

# ---------- 3. AdGuardHome 单包（注释掉）----------
# rm -rf package/luci-app-adguardhome
# git clone --depth=1 https://github.com/OneNAS-space/luci-app-adguardhome.git package/luci-app-adguardhome

# ---------- 4. 安装包（全部注释掉，YAML 中 feeds install -a 已安装所有官方包）----------
# 4a. 官方源
# ./scripts/feeds install \
#   uhttpd \
#   luci-i18n-base-zh-cn luci-i18n-samba4-zh-cn \
#   luci-app-samba4 samba4-server wsdd2 \
#   luci-compat \
#   kmod-nf-conntrack \
#   kmod-mt7915e \
#   kmod-nft-offload kmod-ipt-offload \
#   zram-swap curl ca-certificates

# 4b. kiddin9
# ./scripts/feeds install -p kiddin9 \
#   luci-theme-argon \
#   luci-app-diskman block-mount parted e2fsprogs \
#   luci-app-lucky lucky \
#   luci-i18n-diskman-zh-cn

# 4c. oaf
# ./scripts/feeds install -p oaf oaf luci-app-oaf

# ---------- 5. 默认 IP / 主机名（保留，属于官方基础配置）----------
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/TR3000/g' package/base-files/files/bin/config_generate

# ---------- 6. .config 写入（全部注释掉，只使用 seed 文件和 YAML 中的配置）----------
# cat >> .config <<'EOF'
# ...（所有定制包和调优配置）
# EOF

# ---------- 7. TR3000 设备调优（全部注释掉）----------
# 7a. PPPoE RPS hotplug
# 7b. 防火墙 MSS clamping
# 7c. Samba4 缓存调优
# 7d. 无线：5G 80MHz / CN
# 7e. AGH + Lucky DNS 防打架

echo "=== diy.sh 官方纯净版 done ==="
