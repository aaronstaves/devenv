#!/usr/bin/env bash

/usr/local/bin/default_env.sh

# dev's home directory is actually a shared folder in the docker. Don't actually
# make the home directory ( -M )
groupadd -g $DEVENV_MY_GID dev
useradd -l -d /home/dev -s /bin/bash -M -g $DEVENV_MY_GID -u $DEVENV_MY_UID dev
echo "dev:dev" | chpasswd

service samba start

sleep 4;
echo -ne "dev\ndev\n" | smbpasswd -s -c /etc/samba/smb.conf -a dev

# Tail this forever! :)
tail -f /etc/samba/smb.conf
