FROM openjdk:8u151-jre-alpine
LABEL maintainer="Daniel Eagle"

# Add required packages
RUN apk update \
  && apk add --no-cache openssl ca-certificates git shadow docker py-pip \
  && pip install docker-compose

# Define env variables and arguments
ENV JENKINS_HOME=/home/jenkins
ENV JENKINS_USER=jenkins
ARG uid=1000
ARG shell=/bin/sh

# Create Jenkins home directory and create Jenkins group and user
RUN mkdir -p /home/jenkins \
  && addgroup -g ${uid} $JENKINS_USER \
  && adduser -h $JENKINS_HOME -u ${uid} -G ${JENKINS_USER} -s ${shell} -D ${JENKINS_USER}

# Add the jenkins user to sudoers
RUN echo "${JENKINS_USER}    ALL=(ALL)    ALL" >> /etc/sudoers

# Set name servers
COPY config/resolv.conf /etc/resolv.conf

# Define new truststore location
ARG trustStore=/etc/ssl/java/truststore

# Create folder to store new cacerts location
RUN mkdir -p ${trustStore}

# Apply permissions
RUN chown -R $JENKINS_USER $JENKINS_HOME ${trustStore} \
  && chgrp -R $JENKINS_USER $JENKINS_HOME ${trustStore}

# Create volume to persist data
VOLUME /etc/ssl/java/truststore

# Switch to the jenkins user
USER ${JENKINS_USER}
