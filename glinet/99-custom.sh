#!/bin/sh

exec >/tmp/99-custom.log 2>&1
set -x

echo "========== 99-custom START $(date) =========="

#################################################

# Hostname

#################################################

uci set system.@system[0].hostname='DulWiFi-TK'
uci commit system

#################################################

# Root Password

#################################################

if command -v chpasswd >/dev/null 2>&1; then
echo 'root:password' | chpasswd
fi

#################################################

# LAN IP

#################################################

uci set network.lan.ipaddr='192.168.9.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

#################################################

# WiFi

#################################################

IDX=0

while uci -q get wireless.@wifi-iface[$IDX] >/dev/null 2>&1
do

```
DEVICE=$(uci -q get wireless.@wifi-iface[$IDX].device)

uci set wireless.@wifi-iface[$IDX].disabled='0'
uci set wireless.@wifi-iface[$IDX].encryption='psk2'
uci set wireless.@wifi-iface[$IDX].key='a1111111'

case "$DEVICE" in
    radio0)
        uci set wireless.@wifi-iface[$IDX].ssid='DulWiFi-2.4G'
    ;;
    radio1)
        uci set wireless.@wifi-iface[$IDX].ssid='DulWiFi-5G'
    ;;
    *)
        uci set wireless.@wifi-iface[$IDX].ssid='DulWiFi'
    ;;
esac

IDX=$((IDX+1))
```

done

uci commit wireless

#################################################

# Firmware Description

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

# NPS Auto Config

#################################################

if [ -f /etc/config/nps ] && [ -f /etc/init.d/nps ]; then

```
sleep 5

WAN_DEV=$(uci -q get network.wan.device)

[ -z "$WAN_DEV" ] && \
WAN_DEV=$(ip route | awk '/default/ {print $5; exit}')

WAN_MAC=$(cat /sys/class/net/$WAN_DEV/address 2>/dev/null)

echo "WAN_DEV=$WAN_DEV"
echo "WAN_MAC=$WAN_MAC"

if [ -n "$WAN_MAC" ]; then

    NPS_KEY=$(echo "$WAN_MAC" | tr -d ':' | tr '[:lower:]' '[:upper:]')

    echo "NPS_KEY=$NPS_KEY"

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
```

fi

#################################################

# Apply

#################################################

/etc/init.d/network restart

sleep 3

wifi reload

sync

logger -t 99-custom "DulWiFi init success"

echo "========== 99-custom END $(date) =========="

exit 0
