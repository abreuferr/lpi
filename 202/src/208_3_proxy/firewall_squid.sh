#!/bin/bash

IPTABLES=/sbin/iptables

# clean all possible old mess
$IPTABLES -F 
$IPTABLES -t nat -F 
$IPTABLES -t mangle -F

# masquerading
$IPTABLES -t nat -A POSTROUTING -o ens32 -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward

# opening all 
$IPTABLES -P INPUT ACCEPT
$IPTABLES -P OUTPUT ACCEPT
$IPTABLES -P FORWARD ACCEPT

$IPTABLES -t nat -P POSTROUTING ACCEPT
$IPTABLES -t nat -P PREROUTING ACCEPT
$IPTABLES -t filter -P FORWARD ACCEPT

# web proxy squid
# ens32 - interface externa
# ens34 - interface interna
$IPTABLES -t nat -A PREROUTING -i ens32 -p tcp --dport 80 -j DNAT --to 192.168.0.2:3128
$IPTABLES -t nat -A PREROUTING -i ens34 -p tcp --dport 80 -j REDIRECT --to-port 3128
