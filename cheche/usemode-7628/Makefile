include $(TOPDIR)/rules.mk

PKG_NAME:=usemode-7628
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/usemode-7628
  SECTION:=cheche  # 核心修改：改为cheche分区，对应自定义顶级菜单
  CATEGORY:=cheche # 核心修改：归属到cheche菜单，与其他插件统一
  TITLE:=MT7628/7688 set IoT Device/Gateway mode (UART2 enable)
  DEPENDS:=+@KERNEL_DEVMEM_SUPPORT  # 确保内核开启/dev/mem
  # 可选：添加帮助说明，menuconfig按?可查看
  # HELP:=MT7628/7688模式配置工具，支持IoT设备/网关模式切换，开启UART2
endef

define Package/usemode-7628/description
  Tool to set MT7628/7688 EPHY_GPIO_AIO_EN register for single/multi port mode.
  Enables UART2 in single port (IoT Device) mode.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		-o $(PKG_BUILD_DIR)/usemode $(PKG_BUILD_DIR)/usemode.c
endef

define Package/usemode-7628/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/usemode $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/usemode.init $(1)/etc/init.d/usemode
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/usemode.config $(1)/etc/config/usemode
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/network.sh $(1)/usr/sbin/ethmode
endef

$(eval $(call BuildPackage,usemode-7628))