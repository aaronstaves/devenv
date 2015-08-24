# vim:set ft=dockerfile:
FROM debian:jessie
MAINTAINER John Walsra

RUN apt-get update
RUN apt-get -yqq install nginx
RUN apt-get -yqq install avahi-daemon avahi-discover libnss-mdns

EXPOSE 80

ADD files/http.service.tt /tmp/http.service.tt

ADD scripts/startup.sh /usr/local/bin/startup.sh
CMD  /usr/local/bin/startup.sh
