#!/bin/bash
yum update -y
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth0 -j ACCEPT
iptables-save > /etc/sysconfig/iptables
systemctl enable iptables
systemctl start iptables