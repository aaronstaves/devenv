#!/bin/bash

echo "Removing containers ..."

# kill any active containers
docker ps -a -q | xargs docker rm -f

echo "Removing non-tagged images ..."

# remove non-tagged images
docker rmi $(docker images | grep "^<none>" | awk '{print $3}')


if [ -d "/etc/apt/" ]; then 

	echo "Cleaning APT ..."
	sudo aptitude clean
fi

echo "Shrinking drive spaced used ..."

cat /dev/zero > zero.fill
sync
sleep 1
sync
rm -f zero.fill
