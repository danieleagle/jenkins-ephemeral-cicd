
# Stage 1 - Begin
FROM maven:3.5-jdk-8-alpine
LABEL maintainer="Daniel Eagle"

# Begin -> Define environment variables and arguments
ARG springBootProjectFolder=spring-boot-app
ENV JAVA_OPTS="-Duser.home=/var/maven"
ARG homeDirectory=/var/maven

# change this to local cache folder via volume (e.g. ~/.m2:/var/maven/.m2) if desired
ENV MAVEN_CONFIG=/var/maven/.m2
# End -> Define environment variables and arguments

# Make application directory
RUN mkdir -p /var/opt/${springBootProjectFolder}

# Copy settings file so proper private Maven repository is used (use server cache for pulling dependencies, etc.).
# Do not store credentials in this file. Rather, bind mount different version of settings.xml with credentials
# when running container for deployments.
COPY settings.xml /usr/share/maven/ref/settings.xml

# Copy necessary files to build application
COPY . /var/opt/${springBootProjectFolder}

# Change working directory
WORKDIR /var/opt/${springBootProjectFolder}

# Build the application and skip tests
RUN mvn install -s /usr/share/maven/ref/settings.xml -DskipTests
# Stage 1 - End

# ----------------------------------------------------------------------------------------------------------

# Stage 2 - Begin
FROM openjdk:8u151-jre-alpine
LABEL maintainer="Daniel Eagle"

# Environment Variables and Arguments
ARG uid=1000
ARG shell=/bin/sh
ENV SPRING_BOOT_USER=springboot
ARG springBootProjectFolder=spring-boot-app

# Install Tini
RUN apk add --no-cache tini

# Create Spring Boot user and group
RUN addgroup -g ${uid} $SPRING_BOOT_USER \
  && adduser -u ${uid} -G ${SPRING_BOOT_USER} -s ${shell} -D ${SPRING_BOOT_USER}

# Make application directory
RUN mkdir -p /var/opt/${springBootProjectFolder}

# Change owner and group on application folder to Spring Boot user/group
RUN chown -R ${SPRING_BOOT_USER} /var/opt/${springBootProjectFolder} \
	&& chgrp -R ${SPRING_BOOT_USER} /var/opt/${springBootProjectFolder}

# Switch to the Spring Boot user
USER $SPRING_BOOT_USER

# Change working directory
WORKDIR /var/opt/${springBootProjectFolder}

# Copy jar from previous stage
COPY --from=0 /var/opt/${springBootProjectFolder}/target/spring-boot-demo-latest.jar ./spring-boot-demo-latest.jar

# Open port 8080
EXPOSE 8080

# Use Tini as init system
ENTRYPOINT ["/sbin/tini", "--"]

# Launch the application as a default command
CMD ["java", "-jar", "./target/spring-boot-demo-latest.jar", "--server.port=8090"]
# Stage 2 - End
