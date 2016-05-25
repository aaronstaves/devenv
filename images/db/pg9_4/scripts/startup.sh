#!/bin/bash

/usr/local/bin/default_env.sh

if [ ! -d "/home/dev" ]; then
	groupadd -g $DEVENV_MY_GID dev
	useradd -l -d /home/dev -s /bin/bash -m -g $DEVENV_MY_GID -u $DEVENV_MY_UID dev
	echo "dev:dev" | chpasswd
fi

mkdir -p /var/run/postgresql/9.4
chown -R postgres:postgres /var/run/postgresql

mkdir -p /var/log/db/postgresql/9.4
chown -R postgres:postgres /var/log/db/postgresql

# check if postgresql has NOT been setup
if [ ! -d "$DATA_DIR" ]; then

	mkdir -p $DATA_DIR
	chown -R postgres:postgres $DATA_DIR
	chmod -R 700 $DATA_DIR

	su - postgres -c "/usr/lib/postgresql/9.4/bin/initdb -D $DATA_DIR"

	ls -l $DATA_DIR

	# Over-write pg_hba.conf
	/usr/local/bin/template.sh /tmp/pg_hba.conf.tt $DATA_DIR/pg_hba.conf
	/usr/local/bin/template.sh /tmp/postgresql.conf.tt $DATA_DIR/postgresql.conf

	# Add the project search path to the config
	echo "search_path = '${SLPENV_PG_SCHEMA_SEARCH}'" >> $DATA_DIR/postgresql.conf

	cat $DATA_DIR/postgresql.conf

	chown postgres:postgres $DATA_DIR/pg_hba.conf
	chown postgres:postgres $DATA_DIR/postgresql.conf

	# Just to make sure
	rm -rf /etc/postgresql/9.4

	su - postgres -c "/usr/lib/postgresql/9.4/bin/pg_ctl -t 10 -D $DATA_DIR start"

	sleep 10

	echo " * add extension ... citext";
	su - postgres -d template1 -c "psql --command \"CREATE EXTENSION citext;\""

	echo " * add extension ... cube";
	su - postgres -d template1 -c "psql --command \"CREATE EXTENSION cube;\""

	echo " * add extension ... earthdistance";
	su - postgres -d template1 -c "psql --command \"CREATE EXTENSION earthdistance;\""

	echo " * add extension ... hstore";
	su - postgres -d template1 -c "psql --command \"CREATE EXTENSION hstore;\""

	echo " * add extension ... adminpack";
	su - postgres -d template1 -c "psql --command \"CREATE EXTENSION adminpack;\""

	echo " * add extension ... plperl";
	su - postgres -d template1 -c "psql --command \"CREATE LANGUAGE plperl;\""

	echo " * create dev user";
	su - postgres -c "psql --command \"CREATE USER dev WITH SUPERUSER PASSWORD 'dev';\""

	echo " * create dev database";
	su - postgres -c "createdb -O dev dev"

	echo "### Stopping PostgreSQL (Setup)";
	su - postgres -c "/usr/lib/postgresql/9.4/bin/pg_ctl -D $DATA_DIR stop"

	sleep 5
else

	chown -R postgres:postgres $DATA_DIR
	chmod -R 700 $DATA_DIR
fi

su - postgres -c "/usr/lib/postgresql/9.4/bin/postgres -D $DATA_DIR"
