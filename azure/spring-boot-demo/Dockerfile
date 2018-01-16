FROM maven:3.5-jdk-8-alpine
LABEL maintainer="Daniel Eagle"

# Begin -> Define environment variables and arguments
ENV SPRING_BOOT_USER=springboot

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
RUN mkdir -p /var/opt/spring-boot-demo

# Install Tini
RUN apk add --no-cache tini

# Copy settings file so proper private Maven repository is used (use server cache for pulling dependencies, etc.)
#COPY maven-settings.xml /usr/share/maven/ref/settings.xml

# Change owner and group on home and application folder to Spring Boot user/group
RUN chown -R ${SPRING_BOOT_USER} ${homeDirectory} /var/opt/spring-boot-demo \
	&& chgrp -R ${SPRING_BOOT_USER} ${homeDirectory} /var/opt/spring-boot-demo

# Switch to the Spring Boot user
USER $SPRING_BOOT_USER

# Copy necessary files to build application
COPY . /var/opt/spring-boot-demo

# Change working directory
WORKDIR /var/opt/spring-boot-demo

# Build the application and skip tests
RUN mvn install -DskipTests

# Open port 8090
EXPOSE 8090

# Use Tini as init system
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/mvn-entrypoint.sh"]

# Launch the application as a default command
CMD ["java", "-jar", "./target/spring-boot-demo-latest.jar", "--server.port=8090"]
