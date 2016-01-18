#!/usr/bin/env bash

DOCKER_HOSTS="${HOME}/.devenv/info/${INSTANCE_NAME}/docker_hosts"
MY_HOSTS="${HOME}/.devenv/info/${INSTANCE_NAME}/hosts"
CURL=$(which curl)
WGET=$(which wget)

echo "127.0.0.1	localhost"                         > /tmp/hosts
echo "::1	localhost ip6-localhost ip6-loopback" >> /tmp/hosts
echo "fe00::0 ip6-localnet"                       >> /tmp/hosts
echo "ff00::0 ip6-mcastprefix"                    >> /tmp/hosts
echo "ff02::1 ip6-allnodes"                       >> /tmp/hosts
echo "ff02::2 ip6-allrouters"                     >> /tmp/hosts
echo ""                                           >> /tmp/hosts

if [ -f $DOCKER_HOSTS ]; then

	echo "# DOCKER HOSTS" >> /tmp/hosts
	cat $DOCKER_HOSTS     >> /tmp/hosts
	echo ""               >> /tmp/hosts
	echo ""               >> /tmp/hosts

else 

	echo "Cannot find hosts entries from Docker"
fi

if [ ! -z "$GATEWAY" ]; then

	if [ ! -z "$CURL" ]; then

		echo "# LOCAL DOMAINS" >> /tmp/hosts
		$CURL –s http://$DEVENV_GATEWAY:$DEVENV_HELPER_PORT/action_hosts > /tmp/host_tmp
		cat /tmp/host_tmp >> /tmp/hosts
		rm /tmp/host_tmp

	elif [ ! -z "$WGET" ]; then

		echo "# LOCAL DOMAINS" >> /tmp/hosts
		$WGET –quiet http://$DEVENV_GATEWAY:$DEVENV_HELPER_PORT/action_hosts -O /tmp/host_tmp
		cat /tmp/host_tmp >> /tmp/hosts
		rm /tmp/host_tmp
	fi
fi

if [ -f "$MY_HOSTS" ]; then

	echo "# MY HOSTS" >> /tmp/hosts
	cat $MY_HOSTS     >> /tmp/hosts
fi

sudo cp /tmp/hosts /etc/hosts
