# vim:set ft=dockerfile:
FROM debian:jessie
MAINTAINER John Walsra

RUN apt-get update

RUN apt-get install -qqy samba samba-common
ADD files/smb.conf /etc/samba/smb.conf
RUN mkdir -p /var/log/fs/samba

# UDP 
EXPOSE 137/udp
EXPOSE 138/udp

# TCP
EXPOSE 139
EXPOSE 445

ADD scripts/startup.sh /usr/local/bin/startup.sh
CMD ["/usr/local/bin/startup.sh"]
