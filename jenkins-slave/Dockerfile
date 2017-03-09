FROM ubuntu:16.04
MAINTAINER Daniel Eagle

# Install the python script required for "add-apt-repository",
# add the OpenJDK 8 repo, and Install OpenJDK 8 and other applicable packages
RUN apt-get update && apt-get install -y software-properties-common \
  && add-apt-repository ppa:openjdk-r/ppa \
  && apt-get update && apt-get install -y openjdk-8-jdk curl

# Define env variables
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
ENV SHELL=/bin/bash
ENV JENKINS_HOME=/home/jenkins
ENV JENKINS_USER=jenkins

# Create Jenkins home directory and create Jenkins user
RUN mkdir -p /home/jenkins \
  && useradd -d $JENKINS_HOME -s $SHELL $JENKINS_USER

# Apply permissions
RUN chown -R $JENKINS_USER $JENKINS_HOME \
  && chgrp -R $JENKINS_USER $JENKINS_HOME

# Set name servers
COPY config/resolv.conf /etc/resolv.conf

# Switch to the jenkins user
USER ${JENKINS_USER}
