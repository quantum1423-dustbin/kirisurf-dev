#!/bin/bash

#GNOME 2
gconftool-2 --type string --set /system/http_proxy/host 127.0.0.1
gconftool-2 --type string --set /system/http_proxy/port $1
gconftool-2 --type string --set /system/proxy/secure_host 127.0.0.1
gconftool-2 --type string --set /system/proxy/secure_port $1
gconftool-2 --type string --set /system/proxy/mode manual
#GNOME 3
echo mode
dconf write /system/proxy/mode "'manual'"
echo host
dconf write /system/proxy/http/host "'127.0.0.1'"
echo port
dconf write /system/proxy/http/port $1
echo enabled
dconf write /system/proxy/https/host "'127.0.0.1'"
echo port
dconf write /system/proxy/https/port $1
echo enabled
dconf write /system/proxy/http/enabled true
echo usp
dconf write /system/proxy/use-same-proxy true

#KDE
CF="${HOME}/.kde/share/config/kioslaverc"
sed -e "s/ProxyType=[0-9]/ProxyType=1/" \
	    -e "s/httpProxy=.*/httpProxy=http:\/\/127.0.0.1:$1/" \
	    -e "s/httpsProxy=.*/httpsProxy=http:\/\/127.0.0.1:$1/" -i ${CF}