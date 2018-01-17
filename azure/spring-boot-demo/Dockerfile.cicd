FROM maven:3.5-jdk-8-alpine
LABEL maintainer="Daniel Eagle"

# Begin -> Define environment variables and arguments
ENV SPRING_BOOT_USER=springboot
ARG springBootProjectFolder=spring-boot-project

# change this to local cache folder via volume (e.g. ~/.m2:/var/maven/.m2) if desired
ENV MAVEN_CONFIG=/var/maven/.m2

ENV JAVA_OPTS="-Duser.home=/var/maven"
ARG homeDirectory=/var/maven
ARG uid=1000
ARG shell=/bin/sh
# End -> Define environment variables and arguments

# Create Spring Boot user and group
RUN addgroup -g ${uid} $SPRING_BOOT_USER \
  && adduser -h ${homeDirectory} -u ${uid} -G ${SPRING_BOOT_USER} -s ${shell} -D ${SPRING_BOOT_USER}

# Make application directory
RUN mkdir -p /var/opt/${springBootProjectFolder}

# Install Tini
RUN apk add --no-cache tini

# Copy settings file so proper private Maven repository is used (use server cache for pulling dependencies, etc.).
# Do not store credentials in this file. Rather, bind mount different version of settings.xml with credentials
# when running container for deployments.
COPY settings.xml /usr/share/maven/ref/settings.xml

# Change owner and group on home and application folder to Spring Boot user/group
RUN chown -R ${SPRING_BOOT_USER} ${homeDirectory} /var/opt/${springBootProjectFolder} \
	&& chgrp -R ${SPRING_BOOT_USER} ${homeDirectory} /var/opt/${springBootProjectFolder}

# Switch to the Spring Boot user
USER $SPRING_BOOT_USER

# Copy necessary files to build application
COPY . /var/opt/${springBootProjectFolder}

# Change working directory
WORKDIR /var/opt/${springBootProjectFolder}

# Build the application and skip tests
RUN mvn install -s /usr/share/maven/ref/settings.xml -DskipTests

# Use Tini as init system
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/mvn-entrypoint.sh"]
