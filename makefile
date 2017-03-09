build:
	@docker-compose build 
run:
	@docker-compose up -d jenkins-nginx jenkins-master
stop:
	@docker-compose stop
clean:	stop
	@docker-compose rm jenkins-master jenkins-nginx
clean-images:
	@docker rmi `docker images -q -f "dangling=true"`
