#!/bin/bash
set -euo pipefail

# ============================================
# diy.sh – TR3000 v1
# 官方主线 + kiddin9(argon+diskman) + USB+Samba
# 注意：kiddin9 src-git 已提前写在 feeds.conf.default，update -a 已由 YAML 做完
# ============================================

# ---------- 2. IP / 主机名 ----------
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/TR3000/g' package/base-files/files/bin/config_generate

# ---------- 3. .config 追加（argon + diskman + USB + Samba + 中文 + HNAT）----------
cat >> .config <<'EOF'
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-ntfs=y
CONFIG_PACKAGE_kmod-fs-exfat=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_blockd=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_ntfs-3g=y

CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_samba4-server=y
CONFIG_PACKAGE_wsdd2=y
CONFIG_PACKAGE_luci-compat=y

CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

CONFIG_DEFAULT_flow_offloading=y
CONFIG_DEFAULT_hw_flow_offloading=y
EOF

# ---------- 4. Samba 缓存调优 ----------
mkdir -p package/base-files/files/etc/samba
cat > package/base-files/files/etc/samba/smb-extra.conf <<'SAMBA'
[global]
socket options = IPTOS_LOWDELAY TCP_NODELAY
min receivefile size = 16384
write cache size = 262144
max xmit = 65536
use sendfile = yes
SAMBA

echo "=== diy.sh done ==="
