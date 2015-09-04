#!/usr/bin/env bash

DEST=$1
if [ -z "$DEST" ]; then

  DEST="/etc/default/devenv"
fi

REGEX="^DEVENV_"
echo "# Docker ENV" > $DEST
for e in $(env); do
    # these var than need to changed to their real name
    if [[ $e =~ $REGEX ]]; then
        new_name=$(echo $e | cut -d "_" -f 2- )
        echo "export $new_name" >> $DEST
        echo "export $e"        >> $DEST
    fi
done
