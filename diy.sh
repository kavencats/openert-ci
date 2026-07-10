#!/bin/bash
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate
sed -i 's/OpenWrt/TR3000/g' package/base-files/files/bin/config_generate
if grep -q "luci-app-ssr-plus" .config; then
  echo 'src-git helloworld https://github.com/fw876/helloworld' >> feeds.conf.default
  ./scripts/feeds update helloworld
  ./scripts/feeds install -a -p helloworld
fi
