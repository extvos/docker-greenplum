FROM ubuntu:18.04

MAINTAINER "Mingcai SHEN <archsh@gmail.com>"

# explicitly set user/group IDs
RUN groupadd -r postgres --gid=999 && useradd -m -r -g postgres --uid=999 postgres

# Install GreenPlum
RUN apt-get update \
  && apt-get install -y iputils-ping software-properties-common sudo locales \
  && add-apt-repository -y ppa:greenplum/db \
  && apt-get update \
  && apt-get install -y greenplum-db \
  && rm -rf /var/cache/apt/*

# Configure locale
RUN locale-gen en_US.UTF-8 \
  && update-locale LANG=en_US.UTF-8

# Create gpadmin user and add the user to the sudoers
RUN useradd -md /home/gpadmin/ -s /bin/bash gpadmin \
 && mkdir -p /data \
 && chown gpadmin -R /data \
 && echo "source /opt/greenplum-db-6.8.1/greenplum_path.sh" > /home/gpadmin/.profile \
 && chown gpadmin:gpadmin /home/gpadmin/.profile \
 && su - gpadmin bash -c 'mkdir /home/gpadmin/.ssh' \
 && echo "gpadmin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
 && echo "root ALL=NOPASSWD: ALL" >> /etc/sudoers

RUN mkdir /run/sshd

ADD entrypoint.sh /
ADD initial-configure.sh /
RUN chmod +x /entrypoint.sh /initial-configure.sh

USER gpadmin

VOLUME /data

ENV SEGMENTS 2
ENV ARRAY_NAME "Greenplum Data Platform"
ENV SEG_PREFIX gpsne
ENV PORT_BASE 6000
ENV MASTER_PORT 5432
ENV MASTER_HOSTNAME green-master
ENV DATABASE_NAME testdb

ENTRYPOINT /entrypoint.sh

CMD bash