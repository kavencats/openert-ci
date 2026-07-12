#!/bin/bash
set -euo pipefail

# ============================================
# diy.sh – TR3000 v1
# 场景: 官方主线 + argon 单包(kiddin9) + diskman(GUI挂盘) + Samba4 共享
# ============================================

# ---------- 1. 追加 kiddin9 源（仅用于 argon + diskman）----------
echo "src-git kiddin9 https://github.com/kiddin9/op-packages.git" >> feeds.conf.default

# ---------- 2. 更新官方源 + kiddin9 ----------
export GIT_TERMINAL_PROMPT=0
./scripts/feeds update packages luci routing telephony
for i in 1 2 3; do
  ./scripts/feeds update kiddin9 && break
  sleep 8
done

# ---------- 3. 装 argon + diskman（kiddin9 只这两个包）----------
#./scripts/feeds install -p kiddin9 luci-theme-argon luci-app-diskman

# ---------- 4. 默认 IP / 主机名 ----------
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/TR3000/g' package/base-files/files/bin/config_generate

# ---------- 5. .config 补 argon + diskman + USB/Samba + 中文 ----------
cat >> .config <<'EOF'
# ===== HNAT 双开（MT7981）=====
CONFIG_DEFAULT_flow_offloading=y
CONFIG_DEFAULT_hw_flow_offloading=y
EOF

# ---------- 6. Samba4 缓存调优（USB3 + 2.5G LAN 轻 NAS）----------
mkdir -p package/base-files/files/etc/samba
cat > package/base-files/files/etc/samba/smb-extra.conf <<'SAMBA'
[global]
socket options = IPTOS_LOWDELAY TCP_NODELAY
min receivefile size = 16384
write cache size = 262144
max xmit = 65536
use sendfile = yes
SAMBA

echo "=== TR3000 官方+argon+diskman+Samba diy.sh done ==="
