# Jenkins CICD Docker Pipeline Using Ephemeral Slaves and HTTPS

This repository contains custom Docker files for running [Jenkins](https://jenkins.io/) using ephemeral build slaves over a [NGINX](https://www.nginx.com/) reverse proxy. Everything is setup to run on HTTPS using a self-signed certificate ([this needs to be created](./README.md#generating-a-self-signed-certificate-for-nginx)) or optionally a certificate signed by a trusted CA. This is a great way to setup the ultimate Jenkins [CICD pipeline](https://www.docker.com/use-cases/cicd).

Be sure to see the [change log](./CHANGELOG.md) if interested in tracking changes leading to the current release. In addition, please refer to [this article](http://danieleagle.com/2017/01/jenkins-cicd-docker-pipeline-using-ephemeral-slaves-and-https/) for even more details about this project.

## Getting Started

1. Ensure [Docker Compose](https://docs.docker.com/compose/) is installed along with [Docker Engine](https://docs.docker.com/engine/installation/). The included **docker-compose.yml** file uses version 3 so it's possible [an upgrade](https://docs.docker.com/compose/install/#upgrading) of Docker Compose may be required.

2. [Secure the Docker Daemon using TLS](./README.md#securing-the-docker-daemon-using-tls).

3. [Create a Docker network](./README.md#container-network) named `development`.

4. Clone this repository into the desired location.

5. In the [Docker file](./jenkins-master/Dockerfile) for Jenkins Master, modify the `-Duser.timezone` setting found in the `JAVA_OPTS` environment variable to match the desired time zone. For more information, [see this](https://wiki.jenkins-ci.org/display/JENKINS/Change+time+zone).

6. [Generate a self-signed certificate](./README.md#generating-a-self-signed-certificate-for-nginx) to use with the NGINX reverse proxy. If using a certificate from a trusted CA, still refer to the section on generating a self-signed certificate for instructions on where to place the files.

7. Run the following command (geared toward Linux):

   `sudo make build`

8. Run the following command (geared toward Linux):

   `sudo make run`

9. Change the Jenkins URL to specify the HTTP address of the Jenkins installation which is accessible externally (e.g. **https://jenkins.internal.example.com:9155**). This should match the FQDN of the certificate used to secure Jenkins via HTTPS. While logged into Jenkins, go to **Manage Jenkins** -> **Configure System** and then scroll down to the section labeled **Jenkins Location**. Enter the desired URL into the **Jenkins URL** field.

   **Note:** If this step is missed, Jenkins will warn you of an invalid reverse proxy configuration.

10. [Configure Jenkins to use ephemeral build slaves](./README.md#configuring-jenkins-to-use-ephemeral-build-slaves) with [JNLP](https://docs.oracle.com/javase/tutorial/deployment/deploymentInDepth/jnlp.html).

11. Stop Jenkins by running the following command (geared toward Linux):

    `sudo docker stop Jenkins-Master`

    Next, navigate to `./jenkins-master/volume_data/home/plugins/yet-another-docker-plugin/WEB-INF/lib/` and type the following command (geared toward Linux):

    `sudo vim yet-another-docker-plugin.jar`

    Scroll up to the file **com/github/kostyasha/yad/launcher/DockerComputerJNLPLauncher/init.sh** and press enter. Press **:** then **i** to allow for an edit and then scroll to **line 51** and change `if [ "$NO_CERTIFICATE_CHECK" == "true" ]` to `if [ $NO_CERTIFICATE_CHECK = true ]` and then press **:** and then **wq** to write the change and quit. Next, press **:** then **q** to quit.

     Now, start Jenkins by typing the following command:

    `sudo docker start Jenkins-Master`

    This will fix [a bug](https://github.com/KostyaSha/yet-another-docker-plugin/issues/132) with [version 0.1.0-rc31](https://github.com/KostyaSha/yet-another-docker-plugin/releases/tag/0.1.0-rc31) of the Yet Another Docker plugin.

    **Important:** Upgrading to a newer version of this plugin will overwrite this file. It is suggested not to upgrade the plugin until a fix has been officially created. Once this happens, this project will adapt for the fix. If you prefer to install this version of the plugin manually, it can be found [here](./yad-plugin/yet-another-docker-plugin.hpi).

12. Create a new pipeline job and enter the following for the script.

    ```bash
    node ('testslave') {
      stage 'Stage 1'
      sh 'echo "Hello from your favorite test slave!"'
    }
    ```

13. Save and run the job and take note of the results. If everything was setup properly, Docker should dynamically provision a Jenkins slave and then remove it when it's no longer needed.

Please read the rest of the content found within in order to understand additional configuration options.

## Securing the Docker Daemon Using TLS

The following will configure the Docker Daemon using TLS (geared toward Linux). Before proceeding, be sure to research the [official article](https://docs.docker.com/engine/security/https/) from Docker on the subject.

1. Create a directory where the generated keys will be stored during the creation process.

   `cd ~`

   `sudo mkdir docker`

   `cd docker`

2. Create the CA key by running the following commands.

   `sudo openssl genrsa -aes256 -out ca-key.pem 4096`

   The above command will require entering a passphrase to protect *ca-key.pem*. Enter a strong password and make note of what was entered as it'll be needed later. Then enter the next command:

   `sudo openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem`

   The above command will request input in the following areas shown below.

    ``` bash
    Country Name (2 letter code) [AU]:
    State or Province Name (full name) [Some-State]:
    Locality Name (eg, city) []:
    Organization Name (eg, company) [Internet Widgits Pty Ltd]:
    Organizational Unit Name (eg, section) []:
    Common Name (e.g. server FQDN or YOUR name) []:
    Email Address []:

    Please enter the following 'extra' attributes
    to be sent with your certificate request
    A challenge password []:
    An optional company name []:
    ```

    It's important that for *Common Name (e.g. server FQDN or YOUR name)* to enter the hostname that the current OS is using (e.g. **ubuntu-server**). Also, keep in mind that the key will be valid for one year. If longer is desired, change the integer specified after **-days**.

3. Create the server key by running the following commands.

   `sudo openssl genrsa -out server-key.pem 4096`

   Then enter the next command:

   `sudo openssl req -subj "/CN=$HOST" -sha256 -new -key server-key.pem -out server.csr`

   For the above command, replace **$HOST** with the hostname that the current OS is using (e.g. **ubuntu-server**).

   Then enter the next command:

   `echo subjectAltName = IP:$IPADDRESS,IP:127.0.0.1 > extfile.cnf`

   For the above command, replace **$IPADDRESS** with the IP address of the current host. Running the command `ifconfig` should show the current IP address.

   Then enter the next command:

   `sudo openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile extfile.cnf`

   In the above command, keep in mind that the key will be valid for one year. If longer is desired, change the integer specified after **-days**.

4. Create the client key by running the following commands.

   `sudo openssl genrsa -out key.pem 4096`

   Then enter the next command:

   `sudo openssl req -subj '/CN=client' -new -key key.pem -out client.csr`

   Then enter the next command:

   `echo extendedKeyUsage = clientAuth > extfile.cnf`

   Then enter the next command:

   `sudo openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -extfile extfile.cnf`

   In the above command, keep in mind that the key will be valid for one year. If longer is desired, change the integer specified after **-days**.

5. Run the following commands on all files ending with **.pem** (e.g. ca-key.pem, cert.pem, key.pem). This needs to happen for the reasons referenced in [this discussion](https://github.com/jenkinsci/docker-plugin/issues/371).

   `sudo mv ca-key.pem ca-key.bak`

   `sudo mv cert.pem cert.bak`

   `sudo mv key.pem key.bak`

   Then enter the next commands:

   `sudo openssl rsa -in ca-key.bak -text > ca-key.pem`

   `sudo openssl rsa -in cert.bak -text > cert.pem`

   `sudo openssl rsa -in key.bak -text > key.pem`

   Remove the **.bak** files as they are no longer needed.

   `sudo rm ca-key.bak cert.bak key.bak`

6. Remove the certificate signing requests as they are no longer necessary.

   `sudo rm -v client.csr server.csr`

7. Protect the keys and certificates by assigning the appropriate permissions.

   `sudo chmod -v 0400 ca-key.pem key.pem server-key.pem`

   Then enter the next command:

   `sudo chmod -v 0444 ca.pem server-cert.pem cert.pem`

8. Copy the keys into the appropriate folder so Docker can use them.

   `sudo mkdir /etc/docker`

   Then enter the next command:

   `sudo cp ca.pem /etc/docker/.`

   Then enter the next command:

   `sudo cp server*.pem /etc/docker/.`

9. Create and configure the **docker.conf** file by running the following commands.

   `sudo mkdir /etc/systemd/system/docker.service.d`

   Then enter the next command:

   `sudo vim /etc/systemd/system/docker.service.d/docker.conf`

   Next copy and paste the following into the file.

   ```bash
   [Service]
   ExecStart=
   ExecStart=/usr/bin/docker daemon -H unix:///var/run/docker.sock -D --tls=true --tlsverify --tlscacert=/etc/docker/ca.pem --tlscert=/etc/docker/server-cert.pem --tlskey=/etc/docker/server-key.pem -H tcp://0.0.0.0:2376
   ```

10. Reload and restart Docker by running the following commands.

    `sudo service docker stop`

    Then enter the next command:

    `sudo systemctl daemon-reload`

    Then enter the next command:

    `sudo service docker start`

If everything worked correctly, issuing the command `sudo docker ps` should work fine without any errors.

## Generating a Self-Signed Certificate for NGINX

In order to generate a self-signed certificate (using OpenSSL) to secure all HTTP traffic, follow these instructions (geared toward Linux).

1. Run the command `sudo openssl genrsa -out server.key 4096` which will generate a secure server key.

2. Run the command `sudo openssl req -new -key server.key -out server.csr` which will generate the certificate signing request.

3. The above command will request input in the following areas shown below.

    ``` bash
    Country Name (2 letter code) [AU]:
    State or Province Name (full name) [Some-State]:
    Locality Name (eg, city) []:
    Organization Name (eg, company) [Internet Widgits Pty Ltd]:
    Organizational Unit Name (eg, section) []:
    Common Name (e.g. server FQDN or YOUR name) []:
    Email Address []:

    Please enter the following 'extra' attributes
    to be sent with your certificate request
    A challenge password []:
    An optional company name []:
    ```

   It's important that for *Common Name (e.g. server FQDN or YOUR name)* to enter the FQDN used to access Jenkins Master such as `jenkins.internal.example.com`.

4. Run the command `sudo openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt` to create the signed certificate. The certificate will be valid for one year unless the value used for days is different.

5. Delete the leftover certificate signing request file: `sudo rm server.csr`.

6. Create a folder named `./jenkins-nginx/volume_data/ssl` by typing (geared toward Linux) the following command: `sudo mkdir -p /jenkins-nginx/volume_data/ssl`. Be sure to run this command in the root of the folder where you cloned this repository.

7. Copy both **server.crt** and **server.key** into `./jenkins-nginx/volume_data/ssl`. These files will be used by the Jenkins NGINX container to secure the Jenkins Master instance via HTTPS.

## Configuring Jenkins to Use Ephemeral Build Slaves

With the Docker Daemon secured using TLS and Jenkins Master running behind a NGINX reverse proxy using HTTPS, work can proceed to configure the Jenkins slave options.

1. While in Jenkins (e.g. https://192.168.1.50:9155), on the left sidebar go to **Credentials** and then on the sidebar below Credentials, click **System**.

2. Click on **Global credentials (unrestricted)** and then click **Add Credentials** in the left sidebar.

3. For **Kind**, select **Docker Host Certificate Authentication** and for the **Scope**, choose **Global (Jenkins, nodes, items, all child items, etc)**.

4. Locate the client key used to secure the Docker Daemon. If it wasn't deleted, it should still be in **/home/user/docker**. Check by issuing the following commands.

   `cd ~/docker`

   `ls`

   If **key.pem** is there then proceed to the next step. Otherwise, revisit [Securing the Docker Daemon Using TLS](./README.md#securing-the-docker-daemon-using-tls).

5. Copy the contents of **key.pem** and paste into the **Client Key** field in Jenkins.

6. Locate the client certificate used to secure the Docker Daemon. It should be in **/etc/docker/**. Copy the contents of **cert.pem** and paste into the **Client Certificate** field in Jenkins.

7. Locate CA certificate used to secure the Docker Daemon. It should be in **/etc/docker/**. Copy the contents of **ca.pem** and paste into the **Server CA Certificate** field in Jenkins.

8. Click **OK** when finished.

9. On the left sidebar, click **Manage Jenkins** then **Configure System**.

10. Scroll down to the section titled **Cloud** and find **Yet Another Docker**. For the **Cloud Name** field, enter a desired name (e.g. hostname of Docker Machine) and for the **Docker URL** field, enter `tcp://192.168.1.50:2376`. Be sure to replace the IP address with that of the one running Docker Machine.

11. Under the **Host Credentials** field, select the recently added credentials created in the previous steps.

12. Under the **Type** field, select **NETTY** and then click on the **Test Connection** button. If no errors are displayed, move on to the next step. Otherwise, retrace/retry previous steps.

13. Under the **Max Containers** field, the default is **50**. This is the maximum amount of Jenkins slave containers that will be provisioned at any given time. Change this value to the desired amount or leave it as default.

14. Under the **Images** section, click the **Add Docker Template** button and select **Docker Template**. For the **Docker Image Name**, enter `danieleagle/jenkins-slave:1.0.1-ubuntu-16.04`.

15. For the **Pull Strategy** field, select **Pull never**. Since the image is local there is no need to pull it, so ensure this setting is set correctly.

16. Under the **Remove Container Settings** section, click the **Create Container Settings** button. Scroll down to **Network Mode** and enter `development` into the field.

17. Under the **Remove Container Settings** section, check **Remove volumes**.

18. For the **Labels** field, enter `testslave`. **Note:** This will likely be a different name later on when moving past the testing phase of this initial setup. This name should match the node found in the pipeline script.

19. Under the **Usage** field, select **Only build jobs with label expressions matching this node**.

20. Under the **Launch method** field, select **Docker JNLP launcher**.

21. Under the **Linux user** field, enter `jenkins`.

22. Under the **Slave JVM options** field, enter `-Xmx8192m -Djava.awt.headless=true -Duser.timezone=America/Chicago`. Be sure the change the timezone to the appropriate value.

23. Under the **Different jenkins master URL** field, enter `https://jenkins-nginx`. Now tick the box **Ignore certificate check** ([see this](./README.md#note-about-certificates) for important information).

24. When done with everything, click the **Save** button at the bottom of the page.

## Jenkins Secure Email with TLS

When setting up email using TLS for notifications, alerts, etc., be sure to uncheck SSL but instead use port 587. This will still send email securely using TLS and get around any resulting errors from checking the SSL box but using it with TLS. The [Dockerfile](./jenkins-master/Dockerfile) for Jenkins Master adds `-Dmail.smtp.starttls.enable=true` to the **JAVA_OPTS** environment variable to ensure TLS will work.

## Forwarding JNLP Traffic

Since Jenkins Master is configured to use a NGINX reverse proxy with HTTPS, all HTTP traffic directed at Jenkins will go through this proxy so that HTTPS is enforced. In addition, a special configuration setting had to be specified for NGINX to forward the appropriate JNLP traffic for use by Jenkins slaves. This was configured by adding the following to the [nginx.conf](./jenkins-nginx/config/nginx.conf) file.

```bash
stream {
  server {
    listen 50000;
    proxy_pass jenkins;
  }

  upstream jenkins {
    server jenkins-master:50000;
  }
}
```

## Container Network

The network specified (can be changed to the desired value) by these Docker containers is named `development`. It is assumed that this network has already been created prior to using the included Docker Compose file. The reason for this is to avoid generating a default network so that other Docker containers can access the services these containers expose using the [Docker embedded DNS server](https://docs.docker.com/engine/userguide/networking/#/docker-embedded-dns-server).

If no network has been created, run the following Docker command (geared toward Linux): `sudo docker network create network-name`. Be sure to replace *network-name* with the name of the desired network. For more information on this command, go [here](https://docs.docker.com/engine/reference/commandline/network_create/).

## Port Mapping

The external ports used to map to the internal ports that Jenkins uses are 9155 (maps to 443 for HTTPS) and 9156 (maps to 50000 for JNLP). These ports can certainly be changed but please be mindful of the effects. Additional configuration may be required as a result. In addition, even though JNLP is being exposed as port 9156 it may not be needed. In other words, currently it's being used internally. However, it has been exposed externally incase the need to use it that way presents itself.

## Data Volumes

It is possible to change the data volume folders mapped to the Jenkins Master container to something other than `volume_data/x` if desired. It is recommended to choose a naming scheme that is easy to recognize.

## Notes About the Included Make File

Instead of accessing Docker Compose directly, a [makefile](./makefile) is included and should be used instead. The reason for this is that the Jenkins slave shouldn't be running right away; it should only run when it's required. All that will be handled dynamically by the [Yet Another Docker Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Yet+Another+Docker+Plugin) which is included with the Jenkins Master container. Thus, using the **makefile** will prevent the Jenkins slave from running right away.

## Included Logrotate Examples

In order to properly rotate the logs that Jenkins outputs, [logrotate](https://support.rackspace.com/how-to/understanding-logrotate-utility/) can be used. Included is an [example logrotate file](./jenkins-master/config/logrotate/jenkins) for Jenkins Master as well as [a file](./jenkins-nginx/config/logrotate/nginx) for Jenkins NGINX that can be copied to **/etc/logrotate.d** so that the logs get rotated based on the settings specified in those files.

Also, another approach would be to create a file with logrotate settings for all Docker containers and copy it to **/etc/logrotate.d**. This would rotate all the logs for all Docker containers.

```bash
/var/lib/docker/containers/*/*.log {
  rotate 52
  weekly
  compress
  size=1M
  missingok
  delaycompress
  copytruncate
}
```

## Jenkins Plugins

The file [plugins.txt](./jenkins-master/config/plugins.txt) is used to install plugins for Jenkins when creating the Jenkins Master container. Additional plugins can be added (they can be removed as well) to this file before creating the container. Also, from time to time the plugins listed within this file may become out of date and require specifying the newest versions.

## Jenkins Slave OS

It is possible to use a different OS for Jenkins slaves. However, it will require a specific configuration that works for the desired OS. In addition, the OS should work with the plugin used for the Jenkins slaves, [Yet Another Docker Plugin](https://github.com/KostyaSha/yet-another-docker-plugin). An example discussion on using Alpine Linux as the OS for this can be found [here](https://github.com/KostyaSha/yet-another-docker-plugin/pull/96).

## Jenkins Slave Tools

The included Jenkins slave container doesn't have all the tools needed for a given objective or build task. It will need to be modified to include the appropriate tools. In addition, certain Jenkins plugins may need to be installed in order to achieve a specific task to complement the Jenkins slave.

## Note About Certificates

There are certain situations that will present themselves depending on whether the certificate being used is self-signed or signed by a trusted CA. Below are the various scenarios that can happen. Please make note of them.

* By accessing Jenkins from `https://192.168.1.50:9155` a certificate error will result stating the FQDN in the URL doesn't match that listed on the certificate. This is to be expected since an IP address is being used in the URL.

* By accessing Jenkins from `https://jenkins.internal.example.com:9155` using the proper FQDN specified when creating a self-signed certificate, an error will result stating the certificate was signed using a CA that isn't trusted. This is normal behavior for a self-signed certificate and this error can be suppressed by importing it into the trusted root CA ([shown here for Windows](https://blogs.technet.microsoft.com/sbs/2008/05/08/installing-a-self-signed-certificate-as-a-trusted-root-ca-in-windows-vista/)).

* By accessing Jenkins from `https://jenkins.internal.example.com:9155` using the proper FQDN specified when using a certificate obtained or signed from a trusted CA, no error will be presented. This is ideal for production use in larger deployments.

* By accessing Jenkins from `https://jenkins.internal.example.com:9155` but the certificate (any type, self-signed, etc.) being used has a FQDN specified that doesn't match what's being entered in the address bar of the browser, an error will result stating the certificate's FQDN doesn't match.

Taking note of the last bullet point, a problem occurs which is discussed below.

### Jenkins Slave Must Ignore Certificate Checks

Using [Yet Another Docker Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Yet+Another+Docker+Plugin), when the Jenkins Slave starts it will download the slave agent program (**slave.jar**) and then execute it ([see this article](https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds#Distributedbuilds-WriteyourownscripttolaunchJenkinsslaves)). However, behind the scenes the plugin uses wget or curl to download slave.jar from Jenkins Master. In order to do this, wget/curl will use the URL specified for Jenkins Master. Since the context wget/curl runs is in a container (Jenkins Slave) away from Jenkins Master, it will not be able to use the external FQDN for Jenkins (this is due to the container being isolated in its own internal Docker network).

This is why a different URL is specified for Jenkins Master in the JNLP Launcher Options which is a part of the Yet Another Docker Plugin. Using `https://jenkins-nginx` will ensure wget/curl downloads slave.jar using a URL for Jenkins Master that can be resolved. This is because the internal Docker Naming Service will resolve `jenkins-nginx` to the internal IP for that container by using the default port of 443 which is internally exposed. External connections communicate with this same port using another port via port mapping.

The reason the certificate checks must be ignored via an option in the Yet Another Docker Plugin is because wget/curl will perform a certificate check by default and find that the FQDN `jenkins-nginx` doesn't match the FQDN of the certificate, for example `jenkins.internal.example.com`. In that case, the wget/curl operation will fail. It would be possible to import the certificate into the trusted certificate store for Jenkins Master and not have to ignore certificate checks but this would involve storing secrets inside an image and isn't recommended.

## Further Reading

This solution was inspired from an article by Maxfield Stewart from Riot Games found [here](https://engineering.riotgames.com/news/building-jenkins-inside-ephemeral-docker-container). He also offers a repository that complements the article found [here](https://github.com/maxfields2000/dockerjenkins_tutorial/tree/master/jenkins2).

## Special Thanks

Special thanks goes to [David Hale](https://github.com/vorpleblade) for streamlining the process to secure the Docker Daemon and [Maxfield Stewart](https://github.com/maxfields2000) as mentioned above for his amazing article that served as inspiration for this solution.
