#!/bin/bash
set -euo pipefail

# ============================================
# diy.sh – Cudy TR3000 v1 256MB NAND
# 场景: 家庭主力 AP + 轻 NAS + 去广告 (AGH主)
# 机型: MT7981BA / 512MB RAM / 256MB NAND
# 源码: openwrt/openwrt main
# ============================================

# ---------- 1. 第三方源 ----------
echo "src-git kiddin9 https://github.com/kiddin9/op-packages.git" >> feeds.conf.default
echo "src-git oaf https://github.com/destan19/OpenAppFilter.git" >> feeds.conf.default

# ---------- 2. 更新源（重试 + 失败即停）----------
export GIT_TERMINAL_PROMPT=0
for i in 1 2 3; do
  ./scripts/feeds update -a && break
  sleep 8
done

# ---------- 2b. 清 kiddin9 里 Makefile 写坏的包（webd 已知）----------
rm -rf feeds/kiddin9/webd
./scripts/feeds update kiddin9

# ---------- 3. AdGuardHome 单包 → package/（非 feed）----------
rm -rf package/luci-app-adguardhome
git clone --depth=1 https://github.com/OneNAS-space/luci-app-adguardhome.git package/luci-app-adguardhome

# ---------- 4. 安装包（官方 main 包名对齐）----------

# 4a. 官方源
./scripts/feeds install \
  uhttpd \
  luci-i18n-base-zh-cn luci-i18n-samba4-zh-cn \
  luci-app-samba4 samba4-server wsdd2 \
  luci-compat \
  kmod-nf-conntrack \
  kmod-mt7915e \
  kmod-nft-offload kmod-ipt-offload \
  zram-swap curl ca-certificates

# 4b. kiddin9
./scripts/feeds install -p kiddin9 \
  luci-theme-argon \
  luci-app-diskman block-mount parted e2fsprogs \
  luci-app-lucky lucky \
  luci-i18n-diskman-zh-cn

# 4c. oaf 家用可砍，要就解注
./scripts/feeds install -p oaf oaf luci-app-oaf

# ---------- 5. 默认 IP / 主机名 ----------
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/TR3000/g' package/base-files/files/bin/config_generate

# ---------- 6. .config 写入 ----------
cat >> .config <<'EOF'

# ===== 主包（方案 A：AGH 主 DNS）=====
CONFIG_PACKAGE_uhttpd=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_luci-app-oaf=y

# ===== 依赖 =====
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

# ===== HNAT / 流卸载（MT7981 双开）=====
CONFIG_DEFAULT_flow_offloading=y
CONFIG_DEFAULT_hw_flow_offloading=y

# ===== 中文 =====
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-samba4-zh-cn=y
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y

# ===== 可砍 =====
# CONFIG_PACKAGE_opkg=n
# CONFIG_PACKAGE_telnet=n
# CONFIG_PACKAGE_ppp=n
EOF

# ---------- 7. TR3000 家庭 AP 调优（编译期植入）----------

# 7a. PPPoE RPS hotplug
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

# 7b. 防火墙 MSS clamping（PPPoE 1492 → 1452）— 用 echo + sed 避免复杂转义
FIREWALL_CONFIG="package/network/config/firewall/files/firewall.config"
if [ -f "$FIREWALL_CONFIG" ]; then
  # 先生成一个临时行，然后用 sed 插入到 option syn_flood 后面
  LINE="\toption tcp_mss '1'\n\toption tcp_mss_target '1452'"
  sed -i "/option syn_flood/a\\${LINE}" "$FIREWALL_CONFIG"
fi

# 7c. Samba4 缓存调优
mkdir -p package/base-files/files/etc/samba
cat > package/base-files/files/etc/samba/smb-extra.conf <<'SAMBA'
[global]
socket options = IPTOS_LOWDELAY TCP_NODELAY
min receivefile size = 16384
write cache size = 262144
max xmit = 65536
use sendfile = yes
SAMBA

# 7d. 无线：5G 80MHz / CN
if [ -f package/kernel/mac80211/files/lib/wifi/mac80211.sh ]; then
  sed -i 's/country=".*"/country="CN"/' \
    package/kernel/mac80211/files/lib/wifi/mac80211.sh 2>/dev/null || true
fi

# 7e. AGH + Lucky DNS 防打架：Lucky DNS 改 5533，53 留 AGH
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

echo "=== TR3000 家庭小钢炮 (openwrt/main) diy.sh done ==="
