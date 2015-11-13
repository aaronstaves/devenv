#!/usr/bin/env bash

echo "=================";
export
echo "=================";

SRC=$1
DEST=$2

if [ ! -f "$SRC" ]; then
	echo "Could not find $SRC template file"
	exit 1;
fi

echo "# template.sh $SRC > $DEST"

cp "$SRC" /tmp/_template_file.tt

declare -A ENV
for e in $(env); do
	name=$(echo $e | cut -d "=" -f 1 )
	value=$(echo $e | cut -d "=" -f 2- )
	
	ENV[$name]="$value"
done
for name in "${!ENV[@]}"; do

	#echo "# * $name = ${ENV[$name]}"
	
	match="\[% $name %\]"
	value=${ENV[$name]}

	sed -i -E "s#$match#$value#" /tmp/_template_file.tt
done	

mv /tmp/_template_file.tt $DEST
