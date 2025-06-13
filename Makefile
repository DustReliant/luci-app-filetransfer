include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-filetransfer
PKG_VERSION=1.0
# 使用 Git 提交数量作为 PKG_RELEASE 的值
PKG_RELEASE:=$(shell git rev-list --count HEAD 2>/dev/null || echo "1")

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-filetransfer
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=file transfer tool
	PKGARCH:=all
	DEPENDS:=+luci-base
endef

define Package/luci-app-filetransfer/description
	This package contains LuCI configuration pages for file transfer.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/root/etc/filetransfer/config
	mkdir -p $(PKG_BUILD_DIR)/root/usr/share/filetransfer/backup
	#cp -f "$(PKG_BUILD_DIR)/root/etc/config/filetransfer" "$(PKG_BUILD_DIR)/root/usr/share/filetransfer/backup/filetransfer" >/dev/null 2>&1
endef

define Build/Configure
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		PO_DIR="$(CURDIR)/po" \
		PO_LANGUAGES="en zh-cn" \
		PO_TEMPLATE="$(CURDIR)/po/templates/filetransfer.pot" \
		PO_PACKAGE="$(PKG_NAME)"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/cbi
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	
	$(INSTALL_DATA) ./luasrc/model/cbi/updownload.lua $(1)/usr/lib/lua/luci/model/cbi/updownload.lua
	$(INSTALL_DATA) ./luasrc/model/cbi/log.lua $(1)/usr/lib/lua/luci/model/cbi/log.lua
	$(INSTALL_DATA) ./luasrc/controller/filetransfer.lua $(1)/usr/lib/lua/luci/controller/filetransfer.lua
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/po/*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(INSTALL_DATA) ./luasrc/view/cbi/* $(1)/usr/lib/lua/luci/view/cbi/
endef


$(eval $(call BuildPackage,$(PKG_NAME)))
