#!/bin/sh

set -x
exec >/tmp/99-custom.log 2>&1

LOGFILE="/tmp/99-custom.log"

echo "===== 99-CUSTOM START $(date) ====="

#################################################

# Hostname

#################################################

uci set system.@system[0].hostname='DulWiFi-TK'
uci commit system

#################################################


 # LAN口设置静态IP
    uci set network.lan.proto='static'
    # 多网口设备 支持修改为别的管理后台地址 在Github Action 的UI上自行输入即可 
    uci set network.lan.netmask='255.255.255.0'
    # 设置路由器管理后台地址
    IP_VALUE_FILE="/etc/config/custom_router_ip.txt"
    if [ -f "$IP_VALUE_FILE" ]; then
        CUSTOM_IP=$(cat "$IP_VALUE_FILE")
        # 用户在UI上设置的路由器后台管理地址
        uci set network.lan.ipaddr=$CUSTOM_IP
        echo "custom router ip is $CUSTOM_IP" >> $LOGFILE
    else
        uci set network.lan.ipaddr='192.168.9.1'
        echo "default router ip is 192.168.9.1" >> $LOGFILE
    fi
    
# WiFi

#################################################

for iface in $(uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1)
do
uci set wireless.$iface.disabled='0'
uci set wireless.$iface.ssid='DulWiFi'
uci set wireless.$iface.encryption='psk2'
uci set wireless.$iface.key='password'
done

uci commit wireless

#################################################

# 固件信息

#################################################

cat >/etc/openwrt_release <<EOF
DISTRIB_ID='TK-Live'
DISTRIB_RELEASE='24.10.0'
DISTRIB_REVISION='DulWiFi'
DISTRIB_TARGET='mediatek/filogic'
DISTRIB_ARCH='aarch64_cortex-a53'
DISTRIB_DESCRIPTION='DulWiFi TikTok by jontao'
DISTRIB_TAINTS=''
EOF

#################################################
# NPS
#################################################

if [ -f /etc/config/nps ] && [ -f /etc/init.d/nps ]; then

    sleep 5

    echo "Start configure NPS..."

    WAN_DEV=$(uci -q get network.wan.device)

    if [ -z "$WAN_DEV" ]; then
        WAN_DEV=$(ip route | awk '/default/ {print $5; exit}')
    fi

    echo "WAN_DEV=$WAN_DEV"

    WAN_MAC=""

    if [ -n "$WAN_DEV" ] && [ -f "/sys/class/net/$WAN_DEV/address" ]; then
        WAN_MAC=$(cat /sys/class/net/$WAN_DEV/address)
    fi

    # PPPoE场景
    if [ -z "$WAN_MAC" ] || [ "$WAN_MAC" = "00:00:00:00:00:00" ]; then

        LOWER_DEV=$(basename "$(readlink -f /sys/class/net/$WAN_DEV/lower_* 2>/dev/null)" 2>/dev/null)

        if [ -n "$LOWER_DEV" ] && [ -f "/sys/class/net/$LOWER_DEV/address" ]; then
            WAN_MAC=$(cat /sys/class/net/$LOWER_DEV/address)
            echo "Use lower device MAC: $LOWER_DEV"
        fi
    fi

    if [ -n "$WAN_MAC" ]; then

        echo "WAN MAC=$WAN_MAC"

        NPS_KEY=$(echo "$WAN_MAC" | tr -d ':' | tr '[:lower:]' '[:upper:]')

        echo "NPS KEY=$NPS_KEY"

        uci set nps.@nps[0].enabled='1'
        uci set nps.@nps[0].server_addr='47.83.9.208'
        uci set nps.@nps[0].server_port='8024'
        uci set nps.@nps[0].protocol='tcp'
        uci set nps.@nps[0].compress='1'
        uci set nps.@nps[0].crypt='1'
        uci set nps.@nps[0].vkey="$NPS_KEY"

        uci commit nps

        /etc/init.d/nps enable
        /etc/init.d/nps restart

        echo "NPS configured successfully"

    else

        echo "ERROR: WAN MAC not found"

    fi

fi

# Root密码

#################################################

sed -i 's#^root:[^:]*:#root:$1$WAnoUrSu$/rheUDNlavU8.79MKH6eB.:#' /etc/shadow

sync


#################################################

# 应用配置

#################################################

wifi reload

logger -t 99-custom "DulWiFi init success"

echo "===== 99-CUSTOM END ====="

exit 0
