FROM ubuntu:16.04
MAINTAINER Daniel Eagle

# Install the python script required for "add-apt-repository"
RUN apt-get update && apt-get install -y software-properties-common

# Add the OpenJDK 8 repo
RUN add-apt-repository ppa:openjdk-r/ppa

# Install OpenJDK 8 and other applicable packages
RUN apt-get update && apt-get install -y openjdk-8-jdk curl

# Define env variables and arguments
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
ARG shell=/bin/sh
ARG jenkins_home=/home/jenkins
ARG jenkins_user=jenkins

# Create Jenkins home directory and create Jenkins user
RUN mkdir -p /home/jenkins \
  && useradd -d $jenkins_home -s $shell $jenkins_user

# Apply permissions
RUN chown -R $jenkins_user $jenkins_home \
  && chgrp -R $jenkins_user $jenkins_home

# Set name servers
COPY config/resolv.conf /etc/resolv.conf

# Create SSL folder
RUN mkdir -p /etc/ssl

# Copy SSL certificate
COPY config/ssl/server.crt /etc/ssl/server.crt

# Remove write access from SSL files to protect from accidental damage
RUN chmod -v 0444 /etc/ssl/server.crt

# Symlink self-signed certificate into /usr/share/ca-certificates,
# add to ca-certificates.conf, and update ca-certificates
RUN ln -s /etc/ssl/server.crt /usr/share/ca-certificates/server.crt \
  && echo "server.crt" >> /etc/ca-certificates.conf \
  && update-ca-certificates --fresh
