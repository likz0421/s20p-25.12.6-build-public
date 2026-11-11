#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT/openwrt"

echo "==> drop unused video feed (its packages.adb is often truncated)"
sed -i '/^src-git.* video /d' feeds.conf.default


echo "==> luci-app-lucky (pinned)"
rm -rf package/lucky
git clone --depth 1 https://github.com/gdy666/luci-app-lucky.git package/lucky
git -C package/lucky fetch --depth 1 origin b07f65c28bb5fa3da1fea4b8af5ce24a1488e79a \
	|| { echo "ERROR: pinned Lucky commit is not fetchable; refusing to use a moving HEAD"; exit 1; }
git -C package/lucky checkout --detach b07f65c28bb5fa3da1fea4b8af5ce24a1488e79a

echo "==> Argon v3.1.3 (默认主题)"
rm -rf package/luci-theme-argon
git clone --depth 1 --branch v3.1.3 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
grep -q 'PKG_VERSION:=3.1.3' package/luci-theme-argon/Makefile || { echo "ERROR: Argon is not 3.1.3"; exit 1; }

echo "==> luci-app-quickfile (same file manager as 24.10, pinned)"
rm -rf package/quickfile
git clone --depth 1 https://github.com/sbwml/luci-app-quickfile.git package/quickfile
git -C package/quickfile fetch --depth 1 origin ef2ca5d16ad1156539930d8763c3069f6ac4eb12 \
	|| { echo "ERROR: pinned quickfile commit is not fetchable; refusing to use a moving HEAD"; exit 1; }
git -C package/quickfile checkout --detach ef2ca5d16ad1156539930d8763c3069f6ac4eb12

echo "==> honk + luci apps (daeuniverse/openwrt-packages, pinned)"
rm -rf /tmp/daeuniverse
git clone --depth 1 https://github.com/daeuniverse/openwrt-packages.git /tmp/daeuniverse
git -C /tmp/daeuniverse fetch --depth 1 origin 8110e50c4ca762e13aa57875ef1d6cc4dbdc1074 \
	|| { echo "ERROR: pinned daeuniverse commit is not fetchable; refusing to use a moving HEAD"; exit 1; }
git -C /tmp/daeuniverse checkout --detach 8110e50c4ca762e13aa57875ef1d6cc4dbdc1074
for p in honk luci-app-honk luci-lib-daeuniverse; do
	rm -rf "package/$p"
	cp -a "/tmp/daeuniverse/$p" package/
	[ -d "package/$p" ] || { echo "ERROR: $p is not in daeuniverse/openwrt-packages"; exit 1; }
done
# upstream builds honk-core from source with a pinned Rust nightly, bpf-linker and
# cross-compiled BoringSSL/SQLite; the firmware build installs the official static
# musl release instead, so only the Makefile is replaced and files/ stays upstream.
rm -f package/honk/build.sh
cp "$ROOT/packages/honk/Makefile" package/honk/Makefile
for f in files/honk.init files/honk.config files/config.dae; do
	[ -f "package/honk/$f" ] || { echo "ERROR: upstream honk $f is missing"; exit 1; }
done

echo "==> luci-app-ethled (S20P 网口指示灯开关)"
rm -rf package/luci-app-ethled
cp -a "$ROOT/packages/luci-app-ethled" package/
for f in files/ethled files/ethled.config files/ethled.init files/ethled.hotplug \
	Makefile root/htdocs/luci-static/resources/view/ethled/main.js \
	root/usr/share/luci/menu.d/luci-app-ethled.json \
	root/usr/share/rpcd/acl.d/luci-app-ethled.json; do
	[ -f "package/luci-app-ethled/$f" ] || { echo "ERROR: luci-app-ethled $f is missing"; exit 1; }
done
grep -q 'call BuildPackage' package/luci-app-ethled/Makefile || { echo "ERROR: luci-app-ethled Makefile lacks BuildPackage call"; exit 1; }

echo "==> package versions"
git -C package/lucky rev-parse --short HEAD
git -C package/luci-theme-argon describe --tags --always
git -C /tmp/daeuniverse describe --tags --always
