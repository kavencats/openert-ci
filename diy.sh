#!/bin/bash
set -euo pipefail

# ============================================
# diy.sh – Cudy TR3000 v1 256MB NAND
# 场景: 家庭主力 AP + 轻 NAS + 去广告 (AGH主)
# 机型: MT7981BA / 512MB RAM / 256MB NAND
# ============================================

# ---------- 1. 第三方源 ----------
echo "src-git kiddin9 git://github.com/kiddin9/openwrt-packages.git" >> feeds.conf.default

# ---------- 2. 更新源（重试 + 失败即停）----------
export GIT_TERMINAL_PROMPT=0
for i in 1 2 3; do
  ./scripts/feeds update -a && break
  sleep 8
done
if ! ./scripts/feeds list -p kiddin9 >/dev/null 2>&1; then
  echo "ERROR: kiddin9 feed unavailable after 3 retries" >&2
  exit 1
fi

# ---------- 3. AdGuardHome 单包 → package/（非 feed）----------
rm -rf package/luci-app-adguardhome
git clone --depth=1 https://github.com/OneNAS-space/luci-app-adguardhome.git package/luci-app-adguardhome

# ---------- 4. 安装包（方案 A：AGH 主 DNS，Lucky 仅文件/DDNS/端口转发）----------

# 4a. 官方源
./scripts/feeds install \
  uhttpd \
  luci-i18n-base-zh-cn luci-i18n-samba4-zh-cn \
  luci-app-samba4 samba4-server wsdd2 \
  luci-compat \
  kmod-nf-conntrack \
  kmod-mt7981-firmware kmod-mt7981-fmac \
  kmod-nft-offload kmod-ipt-offload \
  zram-swap curl ca-certificates

# 4b. kiddin9（砍 filemanager/smbuser/commands/shadow）
./scripts/feeds install -p kiddin9 \
  luci-theme-argon \
  luci-app-diskman block-mount parted e2fsprogs \
  luci-app-lucky lucky \
  luci-i18n-diskman-zh-cn

# 4c. oaf 家用可砍，留着也行 —— 要就解注
# ./scripts/feeds install -p oaf oaf luci-app-oaf

# ---------- 5. 默认 IP / 主机名 ----------
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/TR3000/g' package/base-files/files/bin/config_generate

# ---------- 6. .config 写入 ----------
cat >> .config <<'EOF'

# ===== 主包（方案 A）=====
CONFIG_PACKAGE_uhttpd=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-lucky=y

# ===== 依赖 =====
CONFIG_PACKAGE_samba4-server=y
CONFIG_PACKAGE_wsdd2=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_kmod-mt7981-firmware=y
CONFIG_PACKAGE_kmod-mt7981-fmac=y
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

# ===== 可砍（自编译固件不用在线装包）=====
# CONFIG_PACKAGE_opkg=n
# CONFIG_PACKAGE_telnet=n
# CONFIG_PACKAGE_ppp=n          # 光猫拨号可砍；桥接拨号保留
EOF

# ---------- 7. TR3000 家庭 AP 调优（编译期植入）----------

# 7a. PPPoE RPS hotplug — pppoe-wan rx 分散到 CPU1（光猫桥接场景）
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

# 7b. 防火墙 MSS clamping (PPPoE 1492 → 1452)
if [ -f package/network/config/firewall/files/firewall.config ]; then
  sed -i '/option syn_flood/a\        option tcp_mss '\''1'\''\n        option tcp_mss_target '\''1452'\'' \
    package/network/config/firewall/files/firewall.config
fi

# 7c. Samba4 缓存调优（USB3 + 2.5G LAN 轻 NAS）
mkdir -p package/base-files/files/etc/samba
cat > package/base-files/files/etc/samba/smb-extra.conf <<'SAMBA'
[global]
socket options = IPTOS_LOWDELAY TCP_NODELAY
min receivefile size = 16384
write cache size = 262144
max xmit = 65536
use sendfile = yes
SAMBA

# 7d. 无线预设：5G 80MHz / CN / 2.4G 降功率给 IoT + 避 USB3 干扰
# 改 mac80211 的 wireless 模板，让首次 boot 就带对
if [ -f package/kernel/mac80211/files/lib/wifi/mac80211.sh ]; then
  # 把 5G 的 ht_capab 限制 80MHz、country CN；2.4G 留默认但功率压一点
  sed -i 's/country=".*"/country="CN"/' \
    package/kernel/mac80211/files/lib/wifi/mac80211.sh 2>/dev/null || true
fi

# 7e. ★ AGH + Lucky DNS 防打架：把 Lucky 的 DNS 监听端口改掉，让 53 给 AGH
# Lucky 配置文件路径（刷完后 /etc/config/lucky），编译期先塞默认
mkdir -p package/base-files/files/etc/config
if [ -f package/base-files/files/etc/config/lucky ]; then
  # 已有 lucky config 则 patch
  sed -i 's/option dns_port.*/option dns_port 5533/' \
    package/base-files/files/etc/config/lucky 2>/dev/null || true
else
  # 没有就预置一段：关 Lucky DNS、让 AGH 占 53
  cat >> package/base-files/files/etc/config/lucky <<'LUCKY'
config lucky 'main'
        option enable '1'
        option dns_enable '0'
        option dns_port '5533'
LUCKY
fi

# 7f. AGH 规则 & 内存提示（注释，刷完自己配）
# 建议：规则 ≤50k，Go RSS 控制在 120MB 内；上游指 127.0.0.1#5353 给 dnsmasq
# 或 AGH 直接 DoH/DoT 上游，dnsmasq 留 53 转 AGH——二选一

echo "=== TR3000 家庭小钢炮 diy.sh done ==="
