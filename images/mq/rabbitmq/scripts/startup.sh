#!/bin/bash

export RABBITMQ_MNESIA_BASE=/data/var/mq/rabbitmq
export RABBITMQ_CONFIG_FILE=/data/etc/mq/rabbitmq
export CONFIG_FILE=$RABBITMQ_CONFIG_FILE

if [ ! -f /etc/.installed ]; then

	echo "CONFIG_FILE=$CONFIG_FILE" >> /etc/rabbitmq/rabbitmq-env.conf

	mkdir -p /data/etc/mq/rabbitmq
	cp /tmp/rabbitmq.config /data/etc/mq/rabbitmq/rabbitmq.config
fi

if [ ! -d /data/var/mq/rabbitmq ]; then

	mkdir -p $RABBITMQ_MNESIA_BASE
	chmod 777 $RABBITMQ_MNESIA_BASE
fi

if [ ! -d /var/log/rabbitmq ]; then

	mkdir -p /var/log/rabbitmq
	chmod 777 /var/log/rabbitmq
fi

/usr/sbin/rabbitmq-server
