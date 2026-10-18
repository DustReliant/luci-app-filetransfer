#
# Copyright (C) 2024 DustReliant
#
# This is free software, licensed under the MIT License.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-filetransfer
PKG_VERSION:=1.3.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=DustReliant

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

# 依赖说明:
#   luci-base        - LuCI 框架(所有版本)
#   luci-compat      - OpenWrt 22.03+/23.05+ 的 ucode 版 LuCI 需要,
#                      它会拉入 luci-lua-runtime 以支持 Lua 控制器/CBI/模板;
#                      旧版(19.07/21.02)原生支持 Lua,此包存在但非必需
#   luci-lib-nixio   - nixio.fs 文件操作
#   luci-lib-jsonc   - JSON 编解码(http.write_json)
define Package/luci-app-filetransfer
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=LuCI File Transfer and Management Tool
	DEPENDS:=+luci-base +luci-compat +luci-lib-nixio +luci-lib-jsonc
	# 纯 Lua/脚本包,不含体系结构相关代码,所有目标平台共用同一个 ipk。
	# 注意:PKGARCH 必须写在 Package 定义内,否则会被 Package/Default 重置
	PKGARCH:=all
endef

define Package/luci-app-filetransfer/description
	A comprehensive LuCI web interface for file transfer and management.
	Features include: file upload/download, file management, IPK installation,
	real-time logging, error monitoring, and security controls.
endef

# 无源码包:跳过常规的解包/编译步骤
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/luci-app-filetransfer/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/filetransfer
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config

	$(INSTALL_BIN) ./root/etc/init.d/filetransfer $(1)/etc/init.d/filetransfer
	$(INSTALL_CONF) ./root/etc/config/filetransfer $(1)/etc/config/filetransfer

	$(INSTALL_DATA) ./luasrc/controller/filetransfer.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DATA) ./luasrc/model/cbi/filetransfer.lua $(1)/usr/lib/lua/luci/model/cbi/
	$(INSTALL_DATA) ./luasrc/view/filetransfer/*.htm $(1)/usr/lib/lua/luci/view/filetransfer/

	# 预编译的语言文件(避免构建机额外依赖 po 工具链)
	$(INSTALL_DATA) ./po/*.lmo $(1)/usr/lib/lua/luci/i18n/
endef

$(eval $(call BuildPackage,luci-app-filetransfer))
