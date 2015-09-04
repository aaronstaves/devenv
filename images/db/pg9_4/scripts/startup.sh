#!/bin/bash

/usr/local/bin/default_env.sh

groupadd -g $DEVENV_MY_GID dev
useradd -l -d /data/home/dev -s /bin/bash -m -g $DEVENV_MY_GID -u $DEVENV_MY_UID dev
echo "dev:dev" | chpasswd

# check if postgresql has NOT been setup
if [ ! -d "$DATA_DIR" ]; then

	mkdir -p /var/run/postgresql/9.4
	chown -R postgres:postgres /var/run/postgresql

	# /var/log is shared via the data container, so append db in path
	mkdir -p /var/log/db/postgresql/9.4
	chown -R postgres:postgres /var/log/db/postgresql

	mkdir -p $DATA_DIR
	chown -R postgres:postgres $DATA_DIR
	chmod -R 700 $DATA_DIR

	su - postgres -c "/usr/lib/postgresql/9.4/bin/initdb -D $DATA_DIR"

	ls -l $DATA_DIR

	# Over-write pg_hba.conf
	cp /usr/local/share/postgresql/9.4/pg_hba.conf $DATA_DIR


	# Append config items on the bottom of postgresql.conf
	cat /usr/local/share/postgresql/9.4/postgresql.conf >> $DATA_DIR/postgresql.conf

	# Add the project search path to the config
	echo "search_path = '${SLPENV_PG_SCHEMA_SEARCH}'" >> $DATA_DIR/postgresql.conf

	cat $DATA_DIR/postgresql.conf

	chown postgres:postgres $DATA_DIR/pg_hba.conf
	chown postgres:postgres $DATA_DIR/postgresql.conf

	# Just to make sure
	rm -rf /etc/postgresql/9.4

	su - postgres -c "/usr/lib/postgresql/9.4/bin/pg_ctl -t 10 -D $DATA_DIR start"

	sleep 10

	echo " * create dev user";
	su - postgres -c "psql --command \"CREATE USER dev WITH SUPERUSER PASSWORD 'dev';\""

	echo " * create dev database";
	su - postgres -c "createdb -O dev dev"

	echo " * add extension ... citext";
	su - postgres -c "psql --command \"CREATE EXTENSION citext;\""

	echo " * add extension ... cube";
	su - postgres -c "psql --command \"CREATE EXTENSION cube;\""

	echo " * add extension ... earthdistance";
	su - postgres -c "psql --command \"CREATE EXTENSION earthdistance;\""

	echo " * add extension ... hstore";
	su - postgres -c "psql --command \"CREATE EXTENSION hstore;\""

	echo " * add extension ... adminpack";
	su - postgres -c "psql --command \"CREATE EXTENSION adminpack;\""

	echo " * add extension ... plperl";
	su - postgres -c "psql --command \"CREATE LANGUAGE plperl;\""

	echo "### Stopping PostgreSQL (Setup)";
	su - postgres -c "/usr/lib/postgresql/9.4/bin/pg_ctl -D $DATA_DIR stop"

	sleep 5
fi

su - postgres -c "/usr/lib/postgresql/9.4/bin/postgres -D $DATA_DIR"
