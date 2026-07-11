#!/bin/bash
set -euo pipefail

# ============================================
# diy.sh – Cudy TR3000 v1 256MB NAND
# 场景: 家庭主力 AP + 轻 NAS + 去广告 (AGH主)
# 源码: openwrt/openwrt main
# ============================================

# ---------- 1. 第三方源（修 URL + 单层反代，Actions 9418/git:// 不通）----------
echo "src-git kiddin9 https://github.com/kiddin9/op-packages.git" >> feeds.conf.default
echo "src-git oaf https://github.com/destan19/OpenAppFilter.git" >> feeds.conf.default

# ---------- 2. 更新源（官方先，kiddin9 单独重试，失败即停）----------
export GIT_TERMINAL_PROMPT=0

# 官方源先更（快，不拖累）
./scripts/feeds update packages luci routing telephony video 2>/dev/null || ./scripts/feeds update packages luci

# kiddin9 单独重试（大 feed，容易挂）
for i in 1 2 3; do
  ./scripts/feeds update kiddin9 && break
  echo "::warning::kiddin9 update retry $i failed, sleep 10"
  sleep 10
done
[ -d "feeds/kiddin9/luci-app-diskman" ] || {
  echo "::error::kiddin9 feed unavailable after retries (check URL / proxy)" >&2
  exit 1
}

# oaf
./scripts/feeds update oaf

# ---------- 2b. 清 kiddin9 写坏的包 ----------
rm -rf feeds/kiddin9/webd
# 如后面还报 dump，同理 rm，常见还有 alist/tailscale
./scripts/feeds update kiddin9

# ---------- 3. AGH 单包 → package/ ----------
rm -rf package/luci-app-adguardhome
git clone --depth=1 https://github.com/OneNAS-space/luci-app-adguardhome.git package/luci-app-adguardhome

# ---------- 4. 安装包 ----------

# 4a 官方
./scripts/feeds install \
  uhttpd \
  luci-i18n-base-zh-cn luci-i18n-samba4-zh-cn \
  luci-app-samba4 samba4-server wsdd2 \
  luci-compat \
  kmod-nf-conntrack \
  kmod-mt7915e \
  kmod-nft-offload kmod-ipt-offload \
  zram-swap curl ca-certificates

# 4b kiddin9
./scripts/feeds install -p kiddin9 \
  luci-theme-argon \
  luci-app-diskman block-mount parted e2fsprogs \
  luci-app-lucky lucky \
  luci-i18n-diskman-zh-cn

# 4c oaf
./scripts/feeds install -p oaf oaf luci-app-oaf

# ---------- 5. IP / 主机名 ----------
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/TR3000/g' package/base-files/files/bin/config_generate

# ---------- 6. .config 写入 ----------
cat >> .config <<'EOF'
CONFIG_PACKAGE_uhttpd=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_luci-app-oaf=y
CONFIG_PACKAGE_samba4-server=y
CONFIG_PACKAGE_wsdd2=y
CONFIG_PACKAGE_oaf=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_kmod-mt7915e=y
CONFIG_PACKAGE_kmod-nft-offload=y
CONFIG_PACKAGE_kmod-ipt-offload=y
CONFIG_PACKAGE_zram-swap=y
CONFIG_ZRAM_DEV_SIZE=256
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_ca-certificates=y
CONFIG_PACKAGE_lucky=y
CONFIG_DEFAULT_flow_offloading=y
CONFIG_DEFAULT_hw_flow_offloading=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-samba4-zh-cn=y
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y
EOF

# ---------- 7. 调优段（7a~7e 同你上一版，引号已修，整段粘回）----------
mkdir -p package/base-files/files/etc/hotplug.d/net
cat > package/base-files/files/etc/hotplug.d/net/10-pppoe-rps <<'HOTPLUG'
#!/bin/sh
[ "$ACTION" = "ifup" ] || exit 0
[ "$INTERFACE" = "wan" ] || exit 0
for f in /sys/class/net/pppoe-wan/queues/rx-*/rps_cpus; do
  [ -w "$f" ] && echo 2 > "$f"
done
HOTPLUG
chmod +x package/base-files/files/etc/hotplug.d/net/10-pppoe-rps

FIREWALL_CONFIG="package/network/config/firewall/files/firewall.config"
if [ -f "$FIREWALL_CONFIG" ]; then
  LINE="\toption tcp_mss '1'\n\toption tcp_mss_target '1452'"
  sed -i "/option syn_flood/a\\${LINE}" "$FIREWALL_CONFIG"
fi

mkdir -p package/base-files/files/etc/samba
cat > package/base-files/files/etc/samba/smb-extra.conf <<'SAMBA'
[global]
socket options = IPTOS_LOWDELAY TCP_NODELAY
min receivefile size = 16384
write cache size = 262144
max xmit = 65536
use sendfile = yes
SAMBA

if [ -f package/kernel/mac80211/files/lib/wifi/mac80211.sh ]; then
  sed -i 's/country=".*"/country="CN"/' \
    package/kernel/mac80211/files/lib/wifi/mac80211.sh 2>/dev/null || true
fi

mkdir -p package/base-files/files/etc/config
if [ -f package/base-files/files/etc/config/lucky ]; then
  sed -i 's/option dns_port.*/option dns_port 5533/' \
    package/base-files/files/etc/config/lucky 2>/dev/null || true
  sed -i 's/option dns_enable.*/option dns_enable 0/' \
    package/base-files/files/etc/config/lucky 2>/dev/null || true
else
  cat > package/base-files/files/etc/config/lucky <<'LUCKY'
config lucky 'main'
        option enable '1'
        option dns_enable '0'
        option dns_port '5533'
LUCKY
fi

echo "=== TR3000 家庭小钢炮 diy.sh done ==="
