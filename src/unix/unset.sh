#!/bin/bash

gconftool-2 --type string --set /system/proxy/mode none
#GNOME 3
dconf write /system/proxy/mode "'none'"
#fallback
#iptables -t nat --flush
CF="${HOME}/.kde/share/config/kioslaverc"
sed -e "s/ProxyType=[0-9]/ProxyType=0/" -i ${CF}