FROM nginx:1.11.8-alpine
MAINTAINER Daniel Eagle

# Remove unnecessary default file
RUN rm /etc/nginx/conf.d/default.conf

# nginx volumes to persist data
VOLUME /etc/nginx

# Add default configuration
COPY config/jenkins.conf /etc/nginx/conf.d/jenkins.conf
COPY config/nginx.conf /etc/nginx/nginx.conf

# Remove write access from config files to protect from accidental damage
RUN chmod -v 0444 /etc/nginx/conf.d/jenkins.conf \
  && chmod -v 0444 /etc/nginx/nginx.conf

# Create SSL directory
RUN mkdir /etc/nginx/ssl

# Copy SSL files
COPY config/ssl/server.crt /etc/nginx/ssl/server.crt
COPY config/ssl/server.key /etc/nginx/ssl/server.key

# Remove write access from SSL files to protect from accidental damage
RUN chmod -v 0444 /etc/nginx/ssl/server.crt \
  && chmod -v 0444 /etc/nginx/ssl/server.key
