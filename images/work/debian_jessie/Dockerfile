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
RUN apt-get -qqy install uuid
RUN apt-get -qqy install lsof
RUN apt-get -qqy install git
RUN apt-get -qqy install gcc make
RUN apt-get -qqy install curl
RUN apt-get -qqy install apgdiff
RUN apt-get -qqy install bzip2
RUN apt-get -qqy install tar
RUN apt-get -qqy install libexpat1-dev
RUN apt-get -qqy install libxml2-dev
RUN apt-get -qqy install unzip
RUN apt-get -qqy install iputils-ping
RUN apt-get -qqy install dh-make
RUN apt-get -qqy install carton
RUN apt-get -qqy install telnet
RUN apt-get -qqy install sudo

RUN apt-get -qqy install tmux
RUN apt-get -qqy install screen
RUN chmod a+s /usr/bin/screen
RUN echo "hardstatus alwayslastline" >> /etc/screenrc
RUN echo "hardstatus string '%{= kG}[ %{G}%H %{g} %1][%= %{=kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B}%Y-%m-%d %{W}%c %{g}]'" >> /etc/screenrc

# install postgresql 9.0
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN apt-get -qqy install wget
RUN wget --no-check-certificate https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN apt-key add ACCC4CF8.asc
RUN echo "Package: *" > /etc/apt/preferences.d/pgdg.pref
RUN echo "Pin: release o=apt.postgresql.org" >> /etc/apt/preferences.d/pgdg.pref
RUN echo "Pin-Priority: 500" >> /etc/apt/preferences.d/pgdg.pref
RUN apt-get -qq update
RUN apt-get -qqy --force-yes install pgdg-keyring
RUN apt-get -qqy --force-yes install \
	postgresql-contrib-9.4 \
	postgresql-client-9.4 \
	postgresql-server-dev-9.4
RUN rm ACCC4CF8.asc

RUN apt-get -yqq install openssh-server
RUN sed -i "s/^UsePAM yes/UsePAM no/" /etc/ssh/sshd_config
RUN mkdir /var/run/sshd

EXPOSE 22
EXPOSE 3000

ADD tmp/default_env.sh /usr/local/bin/default_env.sh
ADD tmp/template.sh    /usr/local/bin/template.sh

ADD scripts/startup.sh /usr/local/bin/startup.sh
RUN chmod 755 /usr/local/bin/startup.sh
CMD /usr/local/bin/startup.sh
