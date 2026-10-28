#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT/openwrt"

echo "==> drop unused video feed (its packages.adb is often truncated)"
sed -i '/^src-git.* video /d' feeds.conf.default

echo "==> OAF v7.0.1"
rm -rf package/OpenAppFilter
git clone --depth 1 --branch v7.0.1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter

echo "==> luci-app-lucky (pinned)"
rm -rf package/lucky
git clone --depth 1 https://github.com/gdy666/luci-app-lucky.git package/lucky
if git -C package/lucky fetch --depth 1 origin 295115bd07a6748f4137e1bdf98600bc99625d01; then
	git -C package/lucky checkout --detach 295115bd07a6748f4137e1bdf98600bc99625d01
else
	echo "WARNING: pinned Lucky commit is not fetchable; using branch HEAD"
fi

echo "==> Argon v3.1.0"
rm -rf package/luci-theme-argon
git clone --depth 1 --branch v3.1.0 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon

echo "==> Fluent v1.0.9"
rm -rf /tmp/luci-theme-fluent
git clone --depth 1 --branch v1.0.9 https://github.com/LazuliKao/luci-theme-fluent.git /tmp/luci-theme-fluent
cp -a /tmp/luci-theme-fluent/package/* package/

echo "==> luci-app-quickfile (same file manager as 24.10)"
rm -rf package/quickfile
git clone --depth 1 https://github.com/sbwml/luci-app-quickfile.git package/quickfile

echo "==> Open-Box official installer"
rm -rf package/openbox-installer
cp -a "$ROOT/packages/openbox-installer" package/

echo "==> package versions"
git -C package/OpenAppFilter describe --tags --always
git -C package/lucky rev-parse --short HEAD
git -C package/luci-theme-argon describe --tags --always
git -C /tmp/luci-theme-fluent describe --tags --always
