S20P 25.12.6 U-Boot 刷机包
==========================

目录：
  firmware/
    *-squashfs-sysupgrade.bin   U-Boot Web 首选固件（25.12.6 闭源 Wi-Fi）
    *-initramfs-kernel.bin      recovery / 临时启动镜像
    *.manifest                  软件包清单
  bootloader/                   可选，只有需要更新/恢复 U-Boot 或重建 GPT 时才用
    mt7986_clx_s20p-fip_legacy-and-fit_20241010.bin
    clx_s20p_rootfs512M_production512M-gpt.bin   闭源 .bin 布局，512M rootfs
    clx_s20p_rootfs1024M_production1024M-gpt.bin 开源 .itb 布局，1024M rootfs
  lgs-说明.txt                  lgs2007m 原始说明
  README-uboot.txt              本文件

U-Boot Web 刷机：
1. 网线插 LAN1-5 中的一个口，电脑 IPv4 设为 192.168.1.2/24。
2. 按住 reset 键上电，等 SYS 灯由闪烁变为常亮后松开 reset。
3. 浏览器打开 http://192.168.1.1。
4. 先刷 firmware/ 里的 *-squashfs-sysupgrade.bin，等待页面显示 complete，然后重启。
5. 如果 Web 不接受 sysupgrade，先刷 *-initramfs-kernel.bin 临时启动，再在 LuCI/SSH 里 sysupgrade 那个 sysupgrade.bin。

可选：从当前系统更新 U-Boot fip（有风险，先备份）：
  dd if=bootloader/mt7986_clx_s20p-fip_legacy-and-fit_20241010.bin \
     of=$(blkid -t PARTLABEL=fip -o device) conv=fsync
  md5sum $(blkid -t PARTLABEL=fip -o device)
  # 正确 md5: 211b89848fbe383f371433e7cb1889ab

可选：重建 GPT（危险，仅全新分区或扩容 permanent_config 时使用；会改分区表）：
  # 25.12 闭源 Wi-Fi 用 512M rootfs 布局
  md5sum bootloader/clx_s20p_rootfs512M_production512M-gpt.bin
  # 正确 md5: ccfd75bea7d8d2f4d5d75fc2d139cd8a
  dd if=bootloader/clx_s20p_rootfs512M_production512M-gpt.bin of=/dev/mmcblk0 bs=512 count=34 conv=fsync
  sgdisk -e -n 0:0:-1G -c 0:permanent_config \
    -t 0:0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
    -u 0:5F73EF09-196E-4847-BE1E-69F2BD87E8B1 -p /dev/mmcblk0
  # 然后重新进 U-Boot 刷固件，启动后格式化：
  mkfs.ext4 $(blkid -t PARTLABEL=permanent_config -o device)

注意：
- fip/GPT 来自 lgs2007m 的 CLX-S20P_Tutorial-Files，只有需要时才刷；普通升级不要碰。
- 刷 fip/GPT 前先备份 factory、fip、GPT 和原厂 kernel/rootfs。
- 25.12 是闭源 Wi-Fi 的 .bin 固件，使用 512M rootfs 的 GPT；1024M 是开源 .itb 布局，不要混用。
- 首次从 24.10 跨到 25.12，不保留配置；默认 Wi-Fi 为 hanzi / hanziwawa，LAN 为 10.1.1.1。
