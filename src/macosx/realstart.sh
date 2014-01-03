#!/bin/bash

OLDIFS=$IFS
IFS=$'\n'
for f in $(networksetup -listnetworkserviceorder | grep -e "^(.*).\+" | cut -d " " -f2- )
do
	networksetup -setwebproxystate "$f" on
	networksetup -setsecurewebproxystate "$f" on
	networksetup -setwebproxy "$f" "localhost" 7500
	networksetup -setsecurewebproxy "$f" "localhost" 7500
done
IFS=$SAVEIFS
