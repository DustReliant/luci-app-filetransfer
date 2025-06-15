include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-filetransfer
PKG_VERSION=1.0
# 使用 Git 提交数量作为 PKG_RELEASE 的值
PKG_RELEASE:=$(shell git rev-list --count HEAD 2>/dev/null || echo "1")

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

PKG_MAINTAINER:=DustReliant
PKG_LICENSE:=MIT

LUCI_TITLE:=LuCI Support for File Transfer
LUCI_DEPENDS:=+luci-compat +luci-lib-jsonc +luci-lib-nixio
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/conffiles
/etc/config/filetransfer
endef

define Package/$(PKG_NAME)/description
	LuCI Support for File Transfer Management System.
	Provides a web interface for file upload, download and management.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./luasrc $(PKG_BUILD_DIR)/
	$(CP) ./root $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
	
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/filetransfer $(1)/etc/config/
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/filetransfer $(1)/etc/init.d/
	
	$(INSTALL_DIR) $(1)/tmp/upload
	chmod 755 $(1)/tmp/upload
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
