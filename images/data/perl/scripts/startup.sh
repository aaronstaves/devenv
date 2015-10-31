#!/usr/bin/env bash

/usr/local/bin/default_env.sh

export 

echo "UID = $DEVENV_MY_UID"
echo "GID = $DEVENV_MY_GID"

chown -R $DEVENV_MY_UID:$DEVENV_MY_GID /data

# 0
false
