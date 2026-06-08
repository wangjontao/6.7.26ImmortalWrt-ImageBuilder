#!/bin/sh

set -x
exec >/tmp/99-custom.log 2>&1

LOGFILE="/tmp/99-custom.log"

echo "===== 99-CUSTOM START $(date) ====="

# Hostname
#################################################

uci set system.@system[0].hostname='DulWiFi'
uci commit system

#################################################
# Root密码
#################################################

echo 'root:password' | chpasswd

#################################################
# WiFi
#################################################

for iface in $(uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1)
do
    uci set wireless.$iface.disabled='0'
    uci set wireless.$iface.ssid='A'
    uci set wireless.$iface.encryption='psk2'
    uci set wireless.$iface.key='a1111111'
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

    WAN_DEV=$(uci -q get network.wan.device)

    [ -z "$WAN_DEV" ] && WAN_DEV=$(ip route | awk '/default/ {print $5; exit}')

    WAN_MAC=$(cat /sys/class/net/$WAN_DEV/address 2>/dev/null)

    if [ -n "$WAN_MAC" ]; then

        NPS_KEY=$(echo "$WAN_MAC" | tr -d ':' | tr '[:lower:]' '[:upper:]')

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

    fi

fi

#################################################
# 应用配置
#################################################

wifi reload

logger -t 99-custom "DulWiFi init success"

echo "===== 99-CUSTOM END ====="

exit 0
