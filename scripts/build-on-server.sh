#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPO_URL=${REPO_URL:-https://github.com/chasey-dev/immortalwrt-mt798x-rebase}
REPO_BRANCH=${REPO_BRANCH:-25.12}
REPO_COMMIT=${REPO_COMMIT:-9f397975c7b47ce6986a6e39529d2f72fd5c729d}
LAN_IP=${LAN_IP:-10.1.1.1}
DEFAULT_THEME=${DEFAULT_THEME:-argon}
WIFI_COMBO=${WIFI_COMBO:-7673-20260601}
JOBS=${JOBS:-2}
OPENWRT_DIR="$ROOT/openwrt"

if [ "$(id -u)" -eq 0 ]; then
	echo "Do not build as root."
	exit 1
fi

if [ ! -d "$ROOT/scripts" ] || [ ! -f "$ROOT/configs/s20p.config" ]; then
	echo "Run this script from the build repo: bash scripts/build-on-server.sh"
	exit 1
fi

for cmd in git make gcc python3 rsync unzip; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Missing build dependency: $cmd"
		echo "Install the OpenWrt build environment first:"
		echo "  sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'"
		exit 1
	fi
done

echo "==> disk"
df -h "$ROOT"
AVAIL_KB=$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')
if [ "$AVAIL_KB" -lt $((40 * 1024 * 1024)) ]; then
	echo "ERROR: at least 40GB free is recommended."
	exit 1
fi

echo "==> memory"
free -h

if [ ! -d "$OPENWRT_DIR/.git" ]; then
	echo "==> clone source"
	git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$OPENWRT_DIR"
	if git -C "$OPENWRT_DIR" fetch --depth 1 origin "$REPO_COMMIT"; then
		git -C "$OPENWRT_DIR" checkout --detach "$REPO_COMMIT"
	else
		echo "WARNING: pinned source commit is not fetchable; using branch HEAD"
	fi
else
	echo "==> using existing source: $OPENWRT_DIR"
	git -C "$OPENWRT_DIR" log -1 --oneline
fi

chmod +x "$ROOT/scripts/diy-part1.sh" "$ROOT/scripts/diy-part2.sh"

echo "==> third-party packages"
"$ROOT/scripts/diy-part1.sh"

echo "==> feeds update"
cd "$OPENWRT_DIR"
./scripts/feeds update -a

echo "==> S20P fixes and defaults"
LAN_IP="$LAN_IP" DEFAULT_THEME="$DEFAULT_THEME" "$ROOT/scripts/diy-part2.sh"

echo "==> feeds install"
./scripts/feeds install -a

echo "==> load config"
cp "$ROOT/configs/s20p.config" .config

if [ "$WIFI_COMBO" = "7672-20240823" ]; then
	sed -i 's/^CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7673=y/# CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7673 is not set/' .config
	sed -i 's/^CONFIG_MTK_MT_WIFI_MT7986_20260601=y/# CONFIG_MTK_MT_WIFI_MT7986_20260601 is not set/' .config
	sed -i 's|^CONFIG_MTK_MT_WIFI_FIRMWARE_PATH_MT7986=.*|CONFIG_MTK_MT_WIFI_FIRMWARE_PATH_MT7986="mt7986-fw-20240823"|' .config
	{
		echo 'CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7672=y'
		echo 'CONFIG_MTK_MT_WIFI_MT7986_20240823=y'
	} >> .config
fi

make defconfig

for pkg in kmod-mt_wifi luci-app-mtwifi-cfg luci-app-oaf luci-app-lucky luci-theme-argon luci-theme-fluent luci-app-usb-printer luci-app-firewall luci-app-package-manager openbox-installer; do
	if ! grep -q "^CONFIG_PACKAGE_${pkg}=y$" .config; then
		echo "ERROR: package ${pkg} was dropped by make defconfig"
		exit 1
	fi
done

grep -E 'CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_clx_s20p|CONFIG_VERSION_NUMBER|CONFIG_MTK_MT_WIFI_(DRIVER_VERSION|MT7986_202|FIRMWARE_PATH)' .config

echo "==> download"
make download -j"$JOBS"

echo "==> build"
make -j"$JOBS" || make -j1 || make -j1 V=s

echo "==> collect"
cd bin/targets/mediatek/filogic
mkdir -p "$ROOT/out"
cp -v *clx_s20p* "$ROOT/out/"
cp -v config.buildinfo feeds.buildinfo profiles.json sha256sums "$ROOT/out/" 2>/dev/null || true
cd "$ROOT/out"
rm -f sha256sums-s20p.txt
sha256sum * > sha256sums-s20p.txt

echo "==> done: $ROOT/out"
ls -lh
