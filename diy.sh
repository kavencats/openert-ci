#!/bin/bash

# ============================================
# diy.sh – 自定义 OpenWrt 构建脚本（含依赖 + 中文语言包）
# ============================================

# 1. 添加第三方软件源
echo "src-git kiddin9 https://github.com/kiddin9/openwrt-packages.git" >> feeds.conf.default
echo "src-git oaf https://github.com/destan19/OpenAppFilter.git" >> feeds.conf.default
echo "src-git adguardhome https://github.com/OneNAS-space/luci-app-adguardhome.git" >> feeds.conf.default

# 2. 更新所有源
./scripts/feeds update -a

# 3. 安装指定包及其依赖（按源分组）
# 官方源包（含中文语言包）
./scripts/feeds install \
  uhttpd luci-app-commands \
  luci-i18n-base-zh-cn \
  luci-i18n-commands-zh-cn \
  luci-i18n-samba4-zh-cn

# kiddin9 源包（含中文语言包）
./scripts/feeds install -p kiddin9 \
  luci-app-diskman block-mount parted e2fsprogs \
  luci-app-smbuser shadow-usermod shadow-groupmod \
  luci-app-filemanager luci-compat luci-app-samba4 \
  samba4-server wsdd2 \
  luci-i18n-diskman-zh-cn \
  luci-i18n-smbuser-zh-cn \
  luci-i18n-filemanager-zh-cn

# OpenAppFilter 源包（核心 + Luci + 依赖）
./scripts/feeds install -p oaf oaf luci-app-oaf kmod-nf-conntrack iptables-mod-conntrack

# AdGuardHome 源包
./scripts/feeds install -p adguardhome luci-app-adguardhome adguardhome curl ca-certificates

# 4. 修改默认 IP 和主机名
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/TR3000/g' package/base-files/files/bin/config_generate

# 5. 将所有包（含依赖和中文翻译）写入 .config，确保编译进固件
cat >> .config <<EOF
# 用户指定包
CONFIG_PACKAGE_uhttpd=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-smbuser=y
CONFIG_PACKAGE_luci-app-filemanager=y
CONFIG_PACKAGE_luci-app-commands=y
CONFIG_PACKAGE_oaf=y
CONFIG_PACKAGE_luci-app-oaf=y
CONFIG_PACKAGE_luci-app-adguardhome=y

# 依赖包
CONFIG_PACKAGE_samba4-server=y
CONFIG_PACKAGE_wsdd2=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_shadow-usermod=y
CONFIG_PACKAGE_shadow-groupmod=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_iptables-mod-conntrack=y
CONFIG_PACKAGE_adguardhome=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_ca-certificates=y

# 中文语言包
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-commands-zh-cn=y
CONFIG_PACKAGE_luci-i18n-samba4-zh-cn=y
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y
CONFIG_PACKAGE_luci-i18n-smbuser-zh-cn=y
CONFIG_PACKAGE_luci-i18n-filemanager-zh-cn=y
EOF
