include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-filetransfer
PKG_VERSION:=1.2.0
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
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/usr/share/filetransfer

	

	$(INSTALL_DATA) ./luasrc/model/cbi/filetransfer.lua $(1)/usr/lib/lua/luci/model/cbi/filetransfer.lua
	$(INSTALL_DATA) ./luasrc/controller/filetransfer.lua $(1)/usr/lib/lua/luci/controller/filetransfer.lua

	
	# 安装 init.d 脚本并设置执行权限
	$(INSTALL_BIN) ./root/etc/init.d/filetransfer $(1)/etc/init.d/filetransfer
	
	# 安装配置文件
	$(INSTALL_CONF) ./root/etc/config/filetransfer $(1)/etc/config/filetransfer
	
	# 安装其他文件
	$(INSTALL_DATA) ./root/usr/share/filetransfer/log.sh $(1)/usr/share/filetransfer/log.sh

	
	# 安装视图文件
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/filetransfer
	$(INSTALL_DATA) ./luasrc/view/filetransfer/* $(1)/usr/lib/lua/luci/view/filetransfer/
endef

# 添加 i18n 支持
define Package/luci-i18n-filetransfer-zh-cn
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=4. Translations
	TITLE:=filetransfer Chinese Simplified
	PKGARCH:=all
	DEPENDS:=luci-app-filetransfer
endef

define Package/luci-i18n-filetransfer-zh-cn/description
	Translation for luci-app-filetransfer - 简体中文 (Chinese Simplified)
endef

define Package/luci-i18n-filetransfer-zh-cn/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) ./po/filetransfer.zh-cn.lmo $(1)/usr/lib/lua/luci/i18n/filetransfer.zh-cn.lmo
endef

define Package/luci-i18n-filetransfer-en
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=4. Translations
	TITLE:=filetransfer English
	PKGARCH:=all
	DEPENDS:=luci-app-filetransfer
endef

define Package/luci-i18n-filetransfer-en/description
	Translation for luci-app-filetransfer - English
endef

define Package/luci-i18n-filetransfer-en/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) ./po/filetransfer.en.lmo $(1)/usr/lib/lua/luci/i18n/filetransfer.en.lmo
endef

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,$(PKG_NAME)))
$(eval $(call BuildPackage,luci-i18n-filetransfer-zh-cn))
$(eval $(call BuildPackage,luci-i18n-filetransfer-en))