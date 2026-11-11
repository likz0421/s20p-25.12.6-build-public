# CLX S20P ImmortalWrt 25.12.6 固件构建

CLX / Super Gateway **S20P**（`clx_s20p`，MT7986A Filogic）专用 ImmortalWrt 25.12.6 构建仓库。仓库只放差异、门禁和自定义包，上游源码树按 pinned commit 拉取，不改上游。

- 版本：ImmortalWrt **25.12.6**，内核 **6.12.112**（mac80211/backports 6.18.55）
- 设备：`clx_s20p`（mediatek/filogic），默认 LAN `10.1.1.1`
- 主题：**Argon v3.1.3**（默认），界面 `zh_cn`
- 默认 WiFi：SSID `hanzi`，WPA2-PSK 密码 `hanziwawa`
- 代理：**honk**（Open-Box 的替代，eBPF 透明代理，出厂禁用，需自己加节点/规则后开启）
- 端口灯：**luci-app-ethled**（LuCI 网络 → 网口指示灯），RTL8221B（LAN6 / 2.5G WAN）可逐灯控制
- CLI：`ethled apply|off|on|dump|ports`

## 用 GitHub Actions 构建（推荐）

`.github/workflows/build-s20p.yml`，手动 `workflow_dispatch` 触发，输入：

| 输入 | 默认 | 说明 |
|------|------|------|
| `LAN_IP` | `10.1.1.1` | 出厂 LAN IP |
| `DEFAULT_THEME` | `argon` | 默认主题（唯一可选值） |
| `WIFI_COMBO` | `7673-20260601` | WiFi 驱动+固件组合，可选 `7672-20240823` |
| `UPLOAD_RELEASE` | `true` | 是否发布 GitHub Release |

产物：sysupgrade + initramfs 镜像、`S20P-25.12.6-uboot.zip`（含 U-Boot/引导）、sha256 清单。验证用 `verify-image.yml`（下载指定 release 的 squashfs 镜像做逐项检查）。

## 本地 / 自建服务器构建

```bash
git clone https://github.com/likz0421/s20p-25.12.6-build-public.git
cd s20p-25.12.6-build-public
bash scripts/build-on-server.sh
# 可用环境变量：LAN_IP / DEFAULT_THEME / WIFI_COMBO / REPO_COMMIT / JOBS
```

环境要求：

- **非 root** 用户（脚本会拒绝 root）
- **≥ 40 GB** 空闲磁盘、充足内存
- 先装 OpenWrt 构建环境：`sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'`
- 依赖：`git make gcc python3 rsync unzip zip pahole ccache`

## 可复现性策略

上游源码与第三方包都 **pinned commit** 锁定：

- 上游源码 `chasey-dev/immortalwrt-mt798x-rebase` @ `9f397975…`
- Lucky `gdy666/luci-app-lucky` @ `b07f65c2…`
- honk 相关 `daeuniverse/openwrt-packages` @ `8110e50c…`

pinned commit fetch 不到时 **直接报错退出**（不静默回退到分支 HEAD），保证构建可复现、不漂移。

## 已知限制与风险（务必阅读）

1. **honk 上游为 early alpha**（`v0.1.0-beta.6`）：官方标注预期 breaking changes，升级需重新验证。honk-core 用官方 aarch64 静态 musl 发布版（SHA256 已 pin）。
2. **MT7531 LAN1-5 端口灯寄存器布局无文档**：该板 switch LED 位定义未公开，`ethled` 对 LAN1-5 的写入默认关闭（`switch_lan=0`）。要开启前先用 `ethled dump` 或 LuCI「读取寄存器」对照，确认位布局再打开。LAN6 / WAN 的 RTL8221B 已由内核 patch 735 路径覆盖。
3. **第三方 feed 信任**：`fantastic-packages 25.12` 公钥与仓库已预置（`/etc/apk/keys/`，首次开机写 `customfeeds.list`）。装该 feed 的包等于信任其签名方；**第三方 kmods 可能与本内核不匹配**，建议只用 userspace 包。
4. **不要 `apk upgrade`**：内核与 kmods 是同一镜像整体构建，全量升级可能搞坏系统；装插件用 `apk add <package>`。升级系统走 sysupgrade 或 U-Boot，**不要保留 24.10 的配置**。
5. **`verify-image.yml` 的 LAN IP 检查**：期望值从 release 说明的 `LAN: x.x.x.x` 解析，body 没有时退回默认 `10.1.1.1`。
6. **patch 735 的 `rtl8221b_led_done`** 用 MDIO 地址做位图、只配置一次：当前两个 RTL8221B 在 addr 5/7，无冲突；若将来同一地址挂多个 PHY，需改成按 `phy_device` 记录。接口 down/up 后不重新下发，由 `ethled` 的 `apply_on_link` 兜底。

## 移除的东西（用户要求）

- OAF（`luci-app-oaf` / `kmod-oaf` / `appfilter`）
- Open-Box（无安装器、无自启服务，由 honk 替代）
- Samba / 文件共享、USB 打印、`luci-theme-fluent`

## 构建脚本自检

`build-s20p.yml` 与 `scripts/` 内含大量 `grep` 断言门禁（设备选中、版本 pin、主题版本、honk 哈希、DTS LED 值、BTF/BPF 内核配置、必装/禁装包等），任一不符即报错停止，避免产出错误固件。