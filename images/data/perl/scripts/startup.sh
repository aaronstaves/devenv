#!/usr/bin/env bash

/usr/local/bin/default_env.sh

groupadd -g $DEVENV_MY_GID dev
useradd -l -d /data/home/dev -s /bin/bash -m -g $DEVENV_MY_GID -u $DEVENV_MY_UID dev
echo "dev:dev" | chpasswd

chown -R dev:dev /data

# 0
false
