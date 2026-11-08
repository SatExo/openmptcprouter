#
# HyperG meta package: stock OpenMPTCProuter "full" set plus what HyperG adds.
# Selected by upstream build.sh as CONFIG_PACKAGE_$(OMR_DIST)-$(OMR_PACKAGES) = hyperg-full.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=hyperg-full
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

MY_DEPENDS := \
	openmptcprouter-full \
	snmpd luci-app-snmpd \
	modemmanager luci-proto-modemmanager \
	kmod-usb-serial-option kmod-usb-net-qmi-wwan kmod-usb-net-cdc-mbim \
	wireguard-tools \
	hyperg-base

define Package/$(PKG_NAME)
SECTION:=HyperG
CATEGORY:=HyperG
DEPENDS:=$(foreach p,$(MY_DEPENDS),+$(p))
TITLE:=HyperG full package
endef

define Package/$(PKG_NAME)/description
HyperG firmware: OpenMPTCProuter full set plus SNMP, ModemManager, RM500 USB drivers and WireGuard.
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
