# vim:set ft=dockerfile:
FROM debian:jessie
MAINTAINER John Walsra

RUN apt-get update

RUN cp /usr/share/zoneinfo/CST6CDT /etc/localtime
RUN apt-get -qqy install locales
RUN echo "en_US ISO-8859-1"               > /etc/locale.gen
RUN echo "en_US.ISO-8859-15 ISO-8859-15" >> /etc/locale.gen
RUN echo "en_US.UTF-8 UTF-8"             >> /etc/locale.gen
RUN echo "LANG=en_US.UTF-8"   >> /etc/default/locale
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
RUN echo "LANGUAGE=en_US:en"  >> /etc/default/locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# 9.4 is part of debian/jessie
RUN apt-get -qqy --force-yes install \
	postgresql-9.4 \
	postgresql-contrib-9.4 \
	postgresql-client-9.4 \
	postgresql-server-dev-9.4 \
	postgresql-plperl-9.4

# Allow DATA_DIR to be NFS mounted
RUN apt-get -qqy install nfs-common

ADD tmp/myid           /tmp/myid
ADD tmp/mygroup        /tmp/mygroup
ADD tmp/default_env.sh /usr/local/bin/default_env.sh
ADD tmp/template.sh    /usr/local/bin/template.sh

COPY files/pg_hba.conf.tt     /tmp/pg_hba.conf.tt
COPY files/postgresql.conf.tt /tmp/postgresql.conf.tt

# This is the default path. This can overridden via the project config.
ENV DATA_DIR /data/var/db/postgresql/9.4/main

EXPOSE 5432
VOLUME [ "/var/log/db/postgresql/9.4", "/data/etc/db/postgresql/9.4" ]

ADD scripts/startup.sh /usr/local/bin/startup.sh
RUN chmod 755 /usr/local/bin/startup.sh
CMD /usr/local/bin/startup.sh
