#
# HyperG base: own web root (/www-hyperg, interface at /cgi-bin/hyperg/), first-boot
# defaults and the HyperG settings file /etc/config/hyperg.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=hyperg-base
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
SECTION:=HyperG
CATEGORY:=HyperG
TITLE:=HyperG base (web root, defaults, settings)
DEPENDS:=+luci-base +uhttpd
PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
Serves the web interface at /cgi-bin/hyperg/ from its own web root, sets HyperG defaults
without overwriting operator changes, and provides /etc/config/hyperg.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/hyperg
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/uci-defaults $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/libexec/hyperg $(1)/usr/share/hyperg/www-static/cgi-bin
	$(INSTALL_CONF) ./files/etc/config/hyperg $(1)/etc/config/
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-hyperg-base $(1)/etc/uci-defaults/
	$(INSTALL_BIN) ./files/etc/init.d/hyperg-www $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/usr/libexec/hyperg/sync-www $(1)/usr/libexec/hyperg/
	$(INSTALL_BIN) ./files/usr/libexec/hyperg/apply-web-path $(1)/usr/libexec/hyperg/
	$(INSTALL_BIN) ./files/www-hyperg-static/cgi-bin/hyperg $(1)/usr/share/hyperg/www-static/cgi-bin/
	$(INSTALL_DATA) ./files/www-hyperg-static/index.html $(1)/usr/share/hyperg/www-static/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
