#!/usr/bin/env bash

/usr/local/bin/default_env.sh

# dev's home directory is actually a shared folder in the docker. Don't actually
# make the home directory ( -M )
groupadd -g $DEVENV_MY_GID dev
useradd -l -d /home/dev -s /bin/bash -M -g $DEVENV_MY_GID -u $DEVENV_MY_UID dev
echo "dev:dev" | chpasswd

if [ ! -f "/home/dev/.bashrc" ]; then

    cp --no-clobber /etc/skel/.* /home/dev
fi

if grep --quiet devenv /home/dev/.profile; then

	echo "Found source of devenv"

else

    echo ""                          >> /home/dev/.profile
    echo ". /etc/default/devenv"     >> /home/dev/.profile
fi

echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devenv

/usr/sbin/sshd -D
