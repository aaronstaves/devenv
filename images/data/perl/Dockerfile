# vim:set ft=dockerfile:
FROM debian:jessie
MAINTAINER John Walsra

RUN apt-get update
RUN apt-get -yqq install tar
RUN umask 0002

RUN mkdir -p /data/plenv/plugins/perl-build
RUN mkdir -p /data/home
RUN mkdir -p /data/work

COPY files/ /tmp/
RUN tar -zxf /tmp/plenv.tgz -C /data/plenv
RUN tar -zxf /tmp/perl-build.tgz -C /data/plenv/plugins

RUN rm /tmp/plenv.tgz
RUN rm /tmp/perl-build.tgz

ADD tmp/myid /tmp/myid
ADD tmp/mygroup /tmp/mygroup
RUN chown -R $(cat /tmp/myid):$(cat /tmp/mygroup) /data

VOLUME [ "/data", "/var/log" ]
