# SPDX-License-Identifier: MIT

include $(TOPDIR)/rules.mk

PKG_NAME:=openbox-installer
PKG_VERSION:=0.1.371
PKG_RELEASE:=1

PKG_LICENSE:=Proprietary
PKG_LICENSE_FILES:=files/LICENSE
PKG_MAINTAINER:=Open-Box upstream

include $(INCLUDE_DIR)/package.mk

define Package/openbox-installer
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Open-Box official installer (downloads proprietary package)
  DEPENDS:=+curl +ca-bundle +kmod-tun +kmod-veth +kmod-nft-queue +kmod-nft-nat +ip-full
  URL:=https://github.com/liandu2024/Open-Box
endef

define Package/openbox-installer/description
 Installs the official Open-Box installer and a one-shot first-boot service.
 The proprietary Open-Box package is downloaded from the official GitHub
 Release and is not redistributed in this firmware.
endef

define Build/Compile
endef

define Package/openbox-installer/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/init.d $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/usr/share/licenses/openbox-installer
	$(INSTALL_BIN) ./files/openbox-install $(1)/usr/sbin/openbox-install
	$(INSTALL_BIN) ./files/openbox-autoinstall $(1)/etc/init.d/openbox-autoinstall
	$(INSTALL_BIN) ./files/99-enable-openbox-autoinstall $(1)/etc/uci-defaults/99-enable-openbox-autoinstall
	$(INSTALL_DATA) ./files/LICENSE $(1)/usr/share/licenses/openbox-installer/LICENSE
endef

$(eval $(call BuildPackage,openbox-installer))
