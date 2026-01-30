#!/bin/sh
# MT7688单网口专用版：仅支持单网口模式（IoT设备模式，支持UART2）
# 支持参数：dhcpwan（WAN DHCP自动获取）、staticwan（WAN静态IP）、lanstatic（纯LAN模式）
# 核心：单网口配置，禁用VLAN，支持UART2多路串口

# ===================== 自定义配置区（按需修改！）=====================
# WAN静态IP配置（staticwan模式用，根据上级路由修改）
WAN_STATIC_IP="192.168.0.100"
WAN_STATIC_MASK="255.255.255.0"
WAN_STATIC_GW="192.168.0.1"
WAN_DNS="223.5.5.5 114.114.114.114"
# LAN静态IP配置（lanstatic模式用）
LAN_IP="192.168.1.1"
LAN_NETMASK="255.255.255.0"
# ====================================================================

# 颜色提示（可选，无IO占用）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 备份配置（网络+防火墙，防止出错）
backup_config() {
    [ ! -f /etc/config/network.bak ] && cp -f /etc/config/network /etc/config/network.bak
    [ ! -f /etc/config/firewall.bak ] && cp -f /etc/config/firewall /etc/config/firewall.bak
    echo -e "${YELLOW}[提示] 已备份网络/防火墙配置${NC}"
}

# 88端口放行（单网口WAN模式专用）
# 警告：此操作会在WAN口开放88端口，请确保已配置其他安全措施（如防火墙、强密码等）
open_port88() {
    echo -e "${YELLOW}[操作] 放行88端口(TCP+UDP)${NC}"
    echo -e "${YELLOW}[警告] WAN口88端口将对外开放，请确保已配置安全措施${NC}"
    # 删除原有88端口规则，防止重复
    uci delete firewall.rule88_tcp 2>/dev/null
    uci delete firewall.rule88_udp 2>/dev/null
    # 放行路由器本机88端口（WAN均可访问）
    uci set firewall.rule88_tcp="rule"
    uci set firewall.rule88_tcp.name="Allow-TCP-88"
    uci set firewall.rule88_tcp.src="wan"
    uci set firewall.rule88_tcp.proto="tcp"
    uci set firewall.rule88_tcp.dport="88"
    uci set firewall.rule88_tcp.target="ACCEPT"
    uci set firewall.rule88_tcp.family="ipv4"

    uci set firewall.rule88_udp="rule"
    uci set firewall.rule88_udp.name="Allow-UDP-88"
    uci set firewall.rule88_udp.src="wan"
    uci set firewall.rule88_udp.proto="udp"
    uci set firewall.rule88_udp.dport="88"
    uci set firewall.rule88_udp.target="ACCEPT"
    uci set firewall.rule88_udp.family="ipv4"
    # 保存防火墙配置
    uci commit firewall
    /etc/init.d/firewall restart 2>/dev/null
}

# 关闭88端口规则
close_port88() {
    uci delete firewall.rule88_tcp 2>/dev/null
    uci delete firewall.rule88_udp 2>/dev/null
    uci commit firewall
    /etc/init.d/firewall restart 2>/dev/null
    echo -e "${GREEN}[提示] 88端口规则已删除${NC}"
}

# 单网口IoT设备模式硬件初始化
init_iot_device_mode() {
    reg w 10000064 0x550
    reg w 1000003c 0xfe01ff
    echo "$1" | dd bs=1 seek=1000 count=1 of=/dev/mtdblock1 2>/dev/null
}

# UCI配置提交并检查
commit_network_config() {
    if ! uci commit network; then
        echo -e "${RED}[错误] 网络配置提交失败${NC}"
        return 1
    fi
    if ! uci commit dhcp; then
        echo -e "${RED}[错误] DHCP配置提交失败${NC}"
        return 1
    fi
    return 0
}

# 禁用VLAN并删除VLAN配置（单网口模式核心）
disable_vlan() {
    # 禁用VLAN（如果switch存在）
    uci set network.@switch[0].enable_vlan=0 2>/dev/null
    # 删除所有switch_vlan配置，防止eth0.x接口被创建
    while uci delete network.@switch_vlan[0] 2>/dev/null; do :; done
}

# 核心模式配置
case "$1" in
# ============= 单网口WAN DHCP模式（默认推荐）=============
dhcpwan)
    echo -e "${GREEN}mode DHCP-WAN (单网口WAN自动获取IP + 放行88端口)${NC}"
    backup_config
    # 单网口配置：禁用VLAN，WAN=eth0直接
    uci delete network.lan.ifname 2>/dev/null
    disable_vlan
    uci set network.wan.ifname=eth0
    uci set network.wan6.ifname=eth0
    # WAN口DHCP自动获取（核心）
    uci set network.wan.proto="dhcp"
    uci set network.wan6.proto="dhcpv6"
    # 禁用LAN（单网口WAN模式不需要LAN）
    uci set network.lan.proto="none"
    uci set dhcp.lan.ignore=1
    uci set dhcp.wan.ignore=1
    # 保存网络配置
    if ! commit_network_config; then
        exit 1
    fi
    # 单网口IoT设备模式寄存器操作
    init_iot_device_mode 1
    # 完全重启网络以应用VLAN配置变更
    /etc/init.d/network restart
    # 放行88端口
    open_port88
    ;;
# ============= 单网口WAN静态IP模式 =============
staticwan)
    echo -e "${GREEN}mode STATIC-WAN (单网口WAN静态IP + 放行88端口)${NC}"
    backup_config
    # 单网口配置：禁用VLAN，WAN=eth0直接
    uci delete network.lan.ifname 2>/dev/null
    disable_vlan
    uci set network.wan.ifname=eth0
    uci set network.wan6.ifname=eth0
    # WAN口静态IP（核心）
    uci set network.wan.proto="static"
    uci set network.wan.ipaddr="${WAN_STATIC_IP}"
    uci set network.wan.netmask="${WAN_STATIC_MASK}"
    uci set network.wan.gateway="${WAN_STATIC_GW}"
    uci set network.wan.dns="${WAN_DNS}"
    uci set network.wan6.proto="dhcpv6"
    # 禁用LAN（单网口WAN模式不需要LAN）
    uci set network.lan.proto="none"
    uci set dhcp.lan.ignore=1
    uci set dhcp.wan.ignore=1
    # 保存网络配置
    if ! commit_network_config; then
        exit 1
    fi
    # 单网口IoT设备模式寄存器操作
    init_iot_device_mode 1
    # 完全重启网络以应用VLAN配置变更
    /etc/init.d/network restart
    # 放行88端口
    open_port88
    ;;
# ============= 单网口LAN静态IP模式 =============
lanstatic)
    echo -e "${GREEN}mode LAN-STATIC (单网口纯LAN静态IP + 插线直访WEB)${NC}"
    backup_config
    # 单网口配置：禁用VLAN，LAN=eth0
    uci set network.lan.ifname=eth0
    disable_vlan
    uci delete network.wan.ifname 2>/dev/null
    uci delete network.wan6.ifname 2>/dev/null
    # LAN口静态IP（核心，电脑直访）
    uci set network.lan.proto="static"
    uci set network.lan.ipaddr="${LAN_IP}"
    uci set network.lan.netmask="${LAN_NETMASK}"
    # 清空WAN配置
    uci set network.wan.proto="none"
    uci set network.wan6.proto="none"
    # 开启LAN口DHCP（电脑自动获取IP）
    uci set dhcp.lan.ignore=0
    uci set dhcp.lan.start=100
    uci set dhcp.lan.limit=150
    uci set dhcp.lan.leasetime=12h
    # 保存配置
    if ! commit_network_config; then
        exit 1
    fi
    # 单网口IoT设备模式寄存器操作
    init_iot_device_mode 3
    # 完全重启网络以应用VLAN配置变更
    /etc/init.d/network restart
    ;;
# ============= 备用命令：关闭88端口 =============
closeport88)
    close_port88
    ;;
# ============= 无效参数提示 =============
*)
    echo -e "${YELLOW}使用说明（单网口模式）：${NC}"
    echo "  ethmode dhcpwan      - 单网口WAN DHCP自动获取（推荐，默认）"
    echo "  ethmode staticwan    - 单网口WAN静态IP"
    echo "  ethmode lanstatic    - 单网口纯LAN静态（无WAN，管理用）"
    echo "  ethmode closeport88  - 关闭88端口放行"
    echo ""
    echo -e "${YELLOW}注意：本版本仅支持单网口模式，多网口不支持UART2${NC}"
    exit 1
    ;;
esac

# 配置完成通用提示
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}模式配置完成！${NC}"
case "$1" in
dhcpwan|staticwan)
    echo -e "${GREEN}WAN模式：通过WAN口连接网络${NC}"
    echo -e "${GREEN}管理：通过88端口访问${NC}"
    ;;
lanstatic)
    echo -e "${GREEN}LAN模式：WEB管理地址 http://${LAN_IP}${NC}"
    ;;
esac
echo -e "${GREEN}=====================================${NC}"
exit 0
