#!/bin/bash

OLDIFS=$IFS
IFS=$'\n'
for f in $(networksetup -listnetworkserviceorder | grep -e "^(.*).\+" | cut -d " " -f2- )
do
	networksetup -setwebproxystate "$f" off
	networksetup -setsecurewebproxystate "$f" off
	#networksetup -setwebproxy "$f" "localhost" 13370
	#networksetup -setsecurewebproxy "$f" "localhost" 13370
done
IFS=$SAVEIFS
