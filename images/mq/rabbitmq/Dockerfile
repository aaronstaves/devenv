# vim:set ft=dockerfile:
FROM debian:jessie
MAINTAINER John Walsra

RUN apt-get update

RUN apt-get -y install rabbitmq-server
RUN /usr/sbin/rabbitmq-plugins enable rabbitmq_management
RUN /usr/sbin/rabbitmq-plugins enable rabbitmq_management_visualiser

EXPOSE 5672 15672 4369

ADD files/rabbitmq.config /tmp/rabbitmq.config

ADD scripts/startup.sh /usr/local/bin/startup.sh
CMD [ "/usr/local/bin/startup.sh" ]
