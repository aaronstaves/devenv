#!/usr/bin/env bash

/usr/local/bin/default_env.sh

echo "UID = $DEVENV_MY_UID"
echo "GID = $DEVENV_MY_GID"

chown $DEVENV_MY_UID:$DEVENV_MY_GID /data
chown -R $DEVENV_MY_UID:$DEVENV_MY_GID /data/plenv

# 0
false
