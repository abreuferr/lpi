#!/bin/bash

IPTABLES=/sbin/iptables

# recover IPs
ETH0IP=`ifconfig wlan0 | grep "inet addr:" | sed 's/.*inet addr://' | cut -d ' ' -f 1`
ETH1IP=`ifconfig eth0 | grep "inet addr:" | sed 's/.*inet addr://' | cut -d ' ' -f 1`
ETH2IP=`ifconfig wlan1 | grep "inet addr:" | sed 's/.*inet addr://' | cut -d ' ' -f 1`

# clean all possible old mess
$IPTABLES -F 
$IPTABLES -t nat -F 
$IPTABLES -t mangle -F

# masquerading
$IPTABLES -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward

# opening all 
$IPTABLES -P INPUT ACCEPT
$IPTABLES -P OUTPUT ACCEPT
$IPTABLES -P FORWARD ACCEPT

$IPTABLES -t nat -P POSTROUTING ACCEPT
$IPTABLES -t nat -P PREROUTING ACCEPT
$IPTABLES -t filter -P FORWARD ACCEPT


# squid server IP
SQUID_SERVER="192.168.0.1"
# Interface connected to Internet
INTERNET="wlan0"
# Interface connected to LAN
LAN_IN="eth0"
# Squid port
SQUID_PORT="3128"
# DNAT port 80 request comming from LAN systems to squid 3128 ($SQUID_PORT) aka transparent proxy
iptables -t nat -A PREROUTING -i $LAN_IN -p tcp --dport 80 -j DNAT --to $SQUID_SERVER:$SQUID_PORT
# if it is same system
iptables -t nat -A PREROUTING -i $INTERNET -p tcp --dport 80 -j REDIRECT --to-port $SQUID_PORT
