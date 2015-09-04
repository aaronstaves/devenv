#!/usr/bin/env bash

SRC=$1
DEST=$2

cp "$1" /tmp/template_file.tt

declare -A ENV
REGEX="^DEVENV_"
for e in $(env); do
    if [[ $e =~ $REGEX ]]; then
        clean=$(echo $e | cut -d "_" -f 2- )
		name=$(echo $clean | cut -d "=" -f 1 )
		value=$(echo $clean | cut -d "=" -f 2- )
		
		ENV[$name]="$value"
    fi
done
for name in "${!ENV[@]}"; do
	
	match="\[% $name %\]"
	value=${ENV[$name]}

	sed -i -E "s/$match/$value/" /tmp/template_file.tt
done	

mv /tmp/template_file.tt $DEST
