#!/usr/bin/env bash

# Add the user, so we can log in
useradd -l -d /data/home/dev -s /bin/bash -M -g $(cat /tmp/mygroup) -u $(cat /tmp/myid) dev
echo "dev:dev" | chpasswd

echo -ne "dev\ndev\n" | smbpasswd -s -c /etc/samba/smb.conf -a dev

service samba start

# Tail this forever! :)
tail -f /etc/samba/smb.conf
