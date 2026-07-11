#!/bin/bash

# ============================================
# diy.sh – Cudy TR3000 自定义构建
# ============================================

# 1. 第三方源（kiddin9 走 feed；adguardhome 是单包仓库，不走 feed）
echo "src-git kiddin9 https://github.com/kiddin9/op-packages.git" >> feeds.conf.default
echo "src-git oaf https://github.com/destan19/OpenAppFilter.git" >> feeds.conf.default

# 2. 更新源（kiddin9 偶发 HTTPS 节流，加重试）
export GIT_TERMINAL_PROMPT=0
for i in 1 2 3; do
  ./scripts/feeds update -a && break
  sleep 5
done

# 3. adguardhome 单包仓库 → 直接 clone 到 package/（不走 feed！）
rm -rf package/luci-app-adguardhome
git clone --depth=1 https://github.com/OneNAS-space/luci-app-adguardhome.git package/luci-app-adguardhome

# 4. 安装包（按源分组）
# 官方源
./scripts/feeds install \
  uhttpd \
  luci-app-commands \
  luci-app-uhttpd \
  luci-app-filemanager \
  luci-compat \
  block-mount \
  luci-i18n-base-zh-cn \
  luci-i18n-commands-zh-cn \
  luci-i18n-filemanager-zh-cn \
  luci-i18n-uhttpd-zh-cn

# kiddin9（diskman / smbuser / filemanager 都在这）
./scripts/feeds install -p kiddin9 \
  luci-app-diskman \
  parted \
  e2fsprogs \
  luci-app-smbuser \
  shadow-usermod \
  shadow-groupmod \
  luci-app-samba4 \
  samba4-server \
  wsdd2 \
  luci-theme-argon \
  luci-app-lucky \
  lucky \
  luci-i18n-diskman-zh-cn \
  luci-i18n-smbuser-zh-cn \
  luci-i18n-samba4-zh-cn
  

# oaf（主线 nft，不要 iptables-mod-conntrack）
./scripts/feeds install -p oaf oaf luci-app-oaf

# adguardhome 已经在 package/ 下，feeds install 不用管它
# 但它依赖 curl/ca-certificates，从官方源装
./scripts/feeds install curl ca-certificates

# 5. 默认 IP / 主机名
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/cudytr3000/g' package/base-files/files/bin/config_generate

# 6. .config 写入
cat >> .config <<'EOF'
# 主包
CONFIG_PACKAGE_uhttpd=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-smbuser=y
CONFIG_PACKAGE_luci-app-filemanager=y
CONFIG_PACKAGE_luci-app-commands=y
CONFIG_PACKAGE_oaf=y
CONFIG_PACKAGE_luci-app-oaf=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_luci-app-uhttpd=y

# 依赖
CONFIG_PACKAGE_samba4-server=y
CONFIG_PACKAGE_wsdd2=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_shadow-usermod=y
CONFIG_PACKAGE_shadow-groupmod=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_ca-certificates=y
CONFIG_PACKAGE_lucky=y

# 中文
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-commands-zh-cn=y
CONFIG_PACKAGE_luci-i18n-samba4-zh-cn=y
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y
CONFIG_PACKAGE_luci-i18n-smbuser-zh-cn=y
CONFIG_PACKAGE_luci-i18n-filemanager-zh-cn=y
CONFIG_PACKAGE_luci-i18n-uhttpd-zh-cn=y
EOF
