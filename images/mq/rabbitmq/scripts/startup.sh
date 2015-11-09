#!/bin/bash

export RABBITMQ_MNESIA_BASE=/data/var/mq/rabbitmq
export RABBITMQ_CONFIG_FILE=/data/etc/mq/rabbitmq/rabbitmq
export CONFIG_FILE=$RABBITMQ_CONFIG_FILE
export RABBITMQ_LOG_BASE=/var/log/mq/rabbitmq
export LOG_BASE=$RABBITMQ_LOG_BASE

echo "CONFIG_FILE=$CONFIG_FILE" >  /etc/rabbitmq/rabbitmq-env.conf
echo "LOG_BASE=$LOG_BASE"       >> /etc/rabbitmq/rabbitmq-env.conf

mkdir -p /data/etc/mq/rabbitmq
cp /tmp/rabbitmq.config /data/etc/mq/rabbitmq/rabbitmq.config

rm -f /etc/rabbitmq/rabbitmq.config
ln -sf /data/etc/mq/rabbitmq/rabbitmq.config  /etc/rabbitmq/rabbitmq.config

if [ ! -d /data/var/mq/rabbitmq ]; then

	mkdir -p $RABBITMQ_MNESIA_BASE
	chmod 777 $RABBITMQ_MNESIA_BASE
fi

if [ ! -d /var/log/mq/rabbitmq ]; then

	mkdir -p /var/log/mq/rabbitmq
	chmod 777 /var/log/mq/rabbitmq
fi

/usr/sbin/rabbitmq-server
