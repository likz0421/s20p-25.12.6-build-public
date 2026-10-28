# SPDX-License-Identifier: MIT
# Custom core package for Lucky 3.5.0 XiaoJV (official binary is not in the GitHub build source).

include $(TOPDIR)/rules.mk

PKG_NAME:=lucky
PKG_VERSION:=3.5.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=GDY666 <gdy666@foxmail.com>

LUCKY_ARCH:=arm64
PKG_SOURCE:=lucky_3.5.0_Linux_arm64_xiaojv.tar.gz
PKG_SOURCE_URL:=https://release.66666.host/v3.5.0/3.5.0_xiaojv
PKG_HASH:=fa0ed690ae591a10ed426b37bd6a2b584704ed1c7e9ab2a180a8bf3643a0eee4
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/lucky
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Lucky network utility (3.5.0 XiaoJV)
  DEPENDS:=@aarch64
  URL:=https://github.com/gdy666/lucky
endef

define Package/lucky/description
 Lucky provides IPv4/IPv6 port forwarding, DDNS, Wake-on-LAN,
 reverse proxy, ACME automation and related network services.
endef

define Package/lucky/conffiles
/etc/config/lucky
endef

define Build/Prepare
	gzip -dc $(DL_DIR)/$(PKG_SOURCE) | $(HOST_TAR) -C $(PKG_BUILD_DIR) -xf -
	$(Build/Patch)
endef

define Build/Compile
endef

define Package/lucky/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lucky $(1)/usr/bin/lucky
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/lucky-call $(1)/usr/libexec/lucky-call
	$(INSTALL_BIN) ./files/lucky-watchdog $(1)/usr/libexec/lucky-watchdog
	$(INSTALL_DIR) $(1)/usr/share/lucky
	echo '$(LUCKY_ARCH)' > $(1)/usr/share/lucky/arch
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/lucky.init $(1)/etc/init.d/lucky
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/luckyuci $(1)/etc/config/lucky
endef

define Package/lucky/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || /usr/libexec/lucky-watchdog sync
endef

define Package/lucky/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ] && [ "$${PKG_UPGRADE}" != 1 ]; then
	/etc/init.d/lucky stop
	/usr/libexec/lucky-watchdog remove
fi
endef

$(eval $(call BuildPackage,lucky))
