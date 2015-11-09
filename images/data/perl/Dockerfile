# vim:set ft=dockerfile:
FROM debian:jessie
MAINTAINER John Walsra

RUN apt-get update
RUN apt-get -yqq install tar
RUN umask 0002

RUN mkdir -p /data/plenv/plugins/perl-build

COPY files/ /tmp/

RUN tar -zxf /tmp/plenv.tgz -C /data
RUN tar -zxf /tmp/perl-build.tgz -C /data/plenv/plugins

RUN rm /tmp/plenv.tgz
RUN rm /tmp/perl-build.tgz

VOLUME [ "/data", "/var/log" ]

ADD scripts/startup.sh /usr/local/bin/startup.sh
RUN chmod 700 /usr/local/bin/startup.sh
CMD /usr/local/bin/startup.sh
