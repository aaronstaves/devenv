#!/usr/bin/env bash

/usr/local/bin/default_env.sh

export PLENV_ROOT=/data/plenv

groupadd -g $DEVENV_MY_GID dev
useradd -l -d /data/home/dev -s /bin/bash -m -g $DEVENV_MY_GID -u $DEVENV_MY_UID dev
echo "dev:dev" | chpasswd

if [ ! -f "/data/home/dev/.bashrc" ]; then

    cp --no-clobber /etc/skel/.* /data/home/dev
fi

if grep --quiet devenv /data/home/dev/.profile; then

	echo "Found source of devenv"

else

    echo ""                          >> /data/home/dev/.profile
    echo ". /etc/default/devenv"     >> /data/home/dev/.profile
fi

/usr/sbin/sshd -D
