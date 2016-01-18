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

RUN apt-get -yqq install vim
RUN apt-get -qqy install net-tools
RUN apt-get -qqy install telnet
RUN apt-get -qqy install sudo
RUN apt-get -qqy install curl

RUN apt-get -yqq install openssh-server
RUN sed -i "s/^UsePAM yes/UsePAM no/" /etc/ssh/sshd_config
RUN mkdir /var/run/sshd

EXPOSE 22

ADD tmp/default_env.sh   /usr/local/bin/default_env.sh
ADD tmp/hosts_rebuild.sh /usr/local/bin/hosts_rebuild.sh

ADD scripts/startup.sh /usr/local/bin/startup.sh
RUN chmod 755 /usr/local/bin/startup.sh
CMD /usr/local/bin/startup.sh
