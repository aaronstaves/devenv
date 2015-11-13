#!/bin/bash

/usr/local/bin/default_env.sh

# Need to source this to override DATA_DIR, if it was set
. /etc/default/devenv

groupadd -g $DEVENV_MY_GID dev
useradd -l -d /home/dev -s /bin/bash -m -g $DEVENV_MY_GID -u $DEVENV_MY_UID dev
echo "dev:dev" | chpasswd

mkdir -p /var/run/postgresql/9.4
chown -R dev:dev /var/run/postgresql

mkdir -p /var/log/db/postgresql/9.4
chown -R dev:dev /var/log/db/postgresql

if [ -n "$DATA_DIR_NFS" ]; then
	
	mkdir -p /mnt/nfs
	mount -t nfs $DATA_DIR_NFS /mnt/nfs
fi

echo
echo "DATA_DIR is $DATA_DIR"
echo

# check if postgresql has NOT been setup
if [ ! -d "$DATA_DIR" ]; then

	echo "SETUP"

	echo "* Creating $DATA_DIR"
	mkdir -p "$DATA_DIR"

	echo "* Chown to dev";
	chown -R dev:dev "$DATA_DIR"

	echo "* Chmod 700"
	chmod -R 700 "$DATA_DIR"


	echo "* LS"
	ls -al "$DATA_DIR"

	echo "* initdb"

	su - dev -c "/usr/lib/postgresql/9.4/bin/initdb -D $DATA_DIR"

	echo
	echo "--------------------------------------------------------------------------------";
	ls -l $DATA_DIR
	echo "--------------------------------------------------------------------------------";

	# Over-write pg_hba.conf
	/usr/local/bin/template.sh /tmp/pg_hba.conf.tt "$DATA_DIR/pg_hba.conf"

	# Append config items on the bottom of postgresql.conf
	/usr/local/bin/template.sh /tmp/postgresql.conf.tt "$DATA_DIR/postgresql.conf"

	# Add the project search path to the config
	if [ -n "$DEVENV_SEARCH_PATH" ]; then
		echo "search_path = '$DEVENV_SEARCH_PATH'" >> "$DATA_DIR/postgresql.conf"
	fi

	echo "--------------------------------------------------------------------------------";
	cat "$DATA_DIR/postgresql.conf"
	echo "--------------------------------------------------------------------------------";

	chown dev:dev "$DATA_DIR/pg_hba.conf"
	chown dev:dev "$DATA_DIR/postgresql.conf"

	# Just to make sure
	rm -rf /etc/postgresql/9.4

	su - dev -c "/usr/lib/postgresql/9.4/bin/pg_ctl -t 10 -D $DATA_DIR start"

	sleep 10

	echo " * create dev user";
	su - dev -c "psql --command \"CREATE USER dev WITH SUPERUSER PASSWORD 'dev';\""

	echo " * add extension ... citext";
	su - dev -c "psql -d template1 --command \"CREATE EXTENSION citext;\""

	echo " * add extension ... cube";
	su - dev -c "psql -d template1 --command \"CREATE EXTENSION cube;\""

	echo " * add extension ... earthdistance";
	su - dev -c "psql -d template1 --command \"CREATE EXTENSION earthdistance;\""

	echo " * add extension ... hstore";
	su - dev -c "psql -d template1 --command \"CREATE EXTENSION hstore;\""

	echo " * add extension ... adminpack";
	su - dev -c "psql -d template1 --command \"CREATE EXTENSION adminpack;\""

	echo " * add extension ... plperl";
	su - dev -c "psql -d template1 --command \"CREATE LANGUAGE plperl;\""

	echo " * create dev database";
	su - dev -c "createdb -O dev dev"

	echo "### Stopping PostgreSQL (Setup)";
	su - dev -c "/usr/lib/postgresql/9.4/bin/pg_ctl -D $DATA_DIR stop"

	sleep 5
else

	echo "$DATA_DIR exists"

	chown -R dev:dev "$DATA_DIR"
	chmod -R 700 "$DATA_DIR"
fi

echo "Starting postgres"

su - dev -c "/usr/lib/postgresql/9.4/bin/postgres -D $DATA_DIR"

echo "postgres errored out :("
