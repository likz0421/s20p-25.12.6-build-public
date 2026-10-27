#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT/openwrt"

echo "==> apply S20P fixes"
git apply "$ROOT/patches/0001-s20p-supported-devices.patch"
git apply "$ROOT/patches/0002-s20p-uboot-envtools.patch"
git apply "$ROOT/patches/0003-s20p-default-wifi.patch"
git apply "$ROOT/patches/0004-s20p-initramfs.patch"

echo "==> remove duplicate feed packages"
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-fluent
rm -rf feeds/packages/net/open-app-filter

echo "==> install Lucky 3.4.2 XiaoJV core Makefile"
cp "$ROOT/packages/lucky/Makefile" package/lucky/lucky/Makefile

echo "==> set Fluent package version"
sed -i 's/PKG_VERSION:=1.0.8/PKG_VERSION:=1.0.9/' package/luci-theme-fluent/Makefile

echo "==> set LAN IP"
SET_IP="${LAN_IP:-10.1.1.1}"
FLASH_JS=$(find feeds/luci/modules/luci-mod-system -type f -name flash.js | head -n 1)
if [ -n "$FLASH_JS" ]; then
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$SET_IP/g" "$FLASH_JS"
fi
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$SET_IP/g" package/base-files/files/bin/config_generate

echo "==> set default theme and Chinese UI"
THEME="${DEFAULT_THEME:-argon}"
cat > package/base-files/files/etc/uci-defaults/99-set-default-theme <<EOF
#!/bin/sh

THEME="$THEME"

uci set luci.themes.Argon='/luci-static/argon'
uci set luci.themes.Fluent='/luci-static/fluent'

if [ -d "/www/luci-static/\$THEME" ]; then
	uci set luci.main.mediaurlbase="/luci-static/\$THEME"
fi
uci set luci.main.lang='zh_cn'
uci commit luci

exit 0
EOF
chmod 0755 package/base-files/files/etc/uci-defaults/99-set-default-theme

echo "==> done: LAN_IP=$SET_IP THEME=$THEME"
