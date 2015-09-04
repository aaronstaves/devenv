#!/bin/bash

export RABBITMQ_MNESIA_BASE=/data/var/mq/rabbitmq
export RABBITMQ_CONFIG_FILE=/data/etc/mq/rabbitmq
export CONFIG_FILE=$RABBITMQ_CONFIG_FILE

if [ ! -d /data/var/mq/rabbitmq ]; then

	echo "CONFIG_FILE=$CONFIG_FILE" >> /etc/rabbitmq/rabbitmq-env.conf

	mkdir -p /data/etc/mq/rabbitmq
	cp /tmp/rabbitmq.config /data/etc/mq/rabbitmq/rabbitmq.config

	mkdir -p /data/var/mq/rabbitmq
	chmod 777 /data/var/mq/rabbitmq
fi

/usr/sbin/rabbitmq-server
