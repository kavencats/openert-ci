#!/bin/bash

# 修改默认 IP 地址
sed -i 's/192.168.1.1/192.168.3.1/g' package/base-files/files/bin/config_generate

# 修改默认主机名
sed -i 's/OpenWrt/TR3000/g' package/base-files/files/bin/config_generate

# 添加 kiddin9 软件源
echo "src-git kiddin9 https://github.com/kiddin9/openwrt-packages.git" >> feeds.conf.default

# 更新 kiddin9 源
./scripts/feeds update kiddin9
