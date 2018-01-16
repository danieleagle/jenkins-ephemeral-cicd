FROM nginx:1.13.8-alpine
LABEL maintainer="Daniel Eagle"

# Remove unnecessary default file
RUN rm /etc/nginx/conf.d/default.conf

# Add configuration files
COPY config/jenkins.conf /etc/nginx/conf.d/jenkins.conf
COPY config/nginx.conf /etc/nginx/nginx.conf

# Remove write access from config files to protect from accidental damage
RUN chmod -v 0444 /etc/nginx/conf.d/jenkins.conf \
  && chmod -v 0444 /etc/nginx/nginx.conf

# Create volume to persist SSL data
VOLUME /etc/ssl/certs/nginx

# Open port for JNLP traffic forwarding
EXPOSE 50000
