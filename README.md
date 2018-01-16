# Jenkins CICD Docker Pipeline Using Ephemeral Slaves and HTTPS

This repository contains custom Docker files for running [Jenkins](https://jenkins.io/) using ephemeral build slaves over a [NGINX](https://www.nginx.com/) reverse proxy. Everything is setup to run on HTTPS using a self-signed certificate ([this needs to be created](./README.md#generating-a-self-signed-certificate-using-a-private-ca-for-nginx)) or optionally a certificate signed by a trusted CA. This is a great way to setup the ultimate Jenkins [CICD pipeline](https://www.docker.com/use-cases/cicd).

Alternatively, if you wish to setup a highly available complete CICD solution running in Azure, see [this article](https://danieleagle.com/2017/10/setting-up-a-private-cicd-solution-in-azure/). It contains a plethora of information that will greatly complement the text within. The Azure specific Jenkins files can be found in the [azure](./azure/) folder within this repository.

## Latest Changes

Be sure to see the [change log](./CHANGELOG.md) if interested in tracking changes leading to the current release. In addition, please refer to [this article](http://danieleagle.com/2017/01/jenkins-cicd-docker-pipeline-using-ephemeral-slaves-and-https/) for even more details about this project.

## Assumed Environment

It is assumed that the environment being used is Linux. The instructions within have been tested successfully on [Ubuntu](https://www.ubuntu.com/) 16.10 and 17.04.

## Getting Started

**Important:** It is imperative to follow these instructions in exact order as not doing so will result in potential problems.

1. Ensure [Docker Compose](https://docs.docker.com/compose/) is installed along with [Docker Engine](https://docs.docker.com/engine/installation/). The included **docker-compose.yml** file uses version 3 so it's possible [an upgrade](https://docs.docker.com/compose/install/#upgrading) of Docker Compose may be required.

2. Make sure the **Java keytool** is available for use. This can be accomplished by installing the [openjdk-8-jre-headless](http://packages.ubuntu.com/yakkety/openjdk-8-jre-headless) package (e.g. **sudo apt-get install openjdk-8-jre-headless**).

3. [Secure the Docker Daemon using TLS](./README.md#securing-the-docker-daemon-using-tls).

4. [Create a Docker network](./README.md#container-network) named `development`.

5. Clone this repository into the desired location which will serve as the working directory moving forward.

6. In the [Docker file](./jenkins-master/Dockerfile) for Jenkins Master, modify the `-Duser.timezone` setting found in the `JAVA_OPTS` environment variable to match the desired time zone. For more information, [see this](https://wiki.jenkins-ci.org/display/JENKINS/Change+time+zone).

7. [Generate a self-signed certificate using a private CA](./README.md#generating-a-self-signed-certificate-using-a-private-ca-for-nginx) to use with the NGINX reverse proxy. If using a certificate from a trusted CA (non-private), still refer to the section on generating a self-signed certificate for instructions on where to place the files and other necessary changes.

8. Build the images by running the following command:

   `sudo make build`

9. [Prepare Jenkins Slave for successful certificate validation](./README.md#preparing-jenkins-slave-for-successful-certificate-validation) to use a different trust store so the certificate is successfully validated.

   **Note:** This step can be skipped if using a certificate generated from a trusted CA (non-private). If you paid for a certificate from a trusted company, that certificate is likely already trusted by the default trust store.

10. Run the following command to create the Jenkins Master and NGINX containers:

    `sudo make run`

11. Change the Jenkins URL to specify the address of the Jenkins installation which is accessible externally (e.g. **https://jenkins.dev.internal.example.com:52443**). This should match the FQDN of the certificate used to secure Jenkins via HTTPS. While logged into Jenkins, go to **Manage Jenkins** -> **Configure System** and then scroll down to the section labeled **Jenkins Location**. Enter the desired URL into the **Jenkins URL** field.

    **Note:** If this step is missed, Jenkins will warn you of an invalid reverse proxy configuration.

12. [Configure Jenkins to use ephemeral build slaves](./README.md#configuring-jenkins-to-use-ephemeral-build-slaves) with [JNLP](https://docs.oracle.com/javase/tutorial/deployment/deploymentInDepth/jnlp.html).

13. Create a new pipeline job and enter the following for the script.

    ```bash
    node ('jenkins-slave-node') {
      stage 'Stage 1'
      sh 'echo "Hello from your favorite test slave!"'
    }
    ```

14. Save and run the job and take note of the results. If everything was setup properly, Docker should dynamically provision a Jenkins slave and then remove it when it's no longer needed.

Please read the rest of the content found within in order to understand additional configuration options.

## Securing the Docker Daemon Using TLS

The following will configure the Docker Daemon using TLS. Before proceeding, be sure to research the [official article](https://docs.docker.com/engine/security/https/) from Docker on the subject.

1. Create a directory where the generated keys will be stored during the creation process.

   `cd ~`

   `sudo mkdir .docker`

   `cd .docker`

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

   `sudo mv key.pem key.bak`

   Then enter the next commands:

   `sudo openssl rsa -in ca-key.bak -text > ca-key.pem`

   `sudo openssl rsa -in key.bak -text > key.pem`

   Remove the **.bak** files as they are no longer needed.

   `sudo rm ca-key.bak key.bak extfile.cnf`

6. Remove the certificate signing requests as they are no longer necessary.

   `sudo rm -v client.csr server.csr`

7. Protect the keys and certificates by assigning the appropriate permissions.

   `sudo chmod -v 0400 ca-key.pem key.pem server-key.pem`

   Then enter the next command:

   `sudo chmod -v 0444 ca.pem server-cert.pem cert.pem`

8. Create and configure the **docker.conf** file by running the following commands.

   `sudo mkdir /etc/systemd/system/docker.service.d`

   Then enter the next command:

   `sudo vim /etc/systemd/system/docker.service.d/docker.conf`

   Next copy and paste the following into the file.

   ```bash
   [Service]
   ExecStart=
   ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2376
   ```

9. Create and configure the **daemon.conf** file by running the following commands.

   `sudo vim /etc/docker/daemon.json`

   Next copy and paste the following into the file.

   ```bash
   {
    "tls": true,
    "tlsverify": true,
    "tlscacert": "/home/spacely-eng-admin/.docker/ca.pem",
    "tlscert": "/home/spacely-eng-admin/.docker/server-cert.pem",
    "tlskey": "/home/spacely-eng-admin/.docker/server-key.pem",
    "dns": ["8.8.8.8", "8.8.4.4"]
   }
   ```

   Replace **spacely-eng-admin** with the appropriate user account. Also, replace the DNS IP address entries with the ones of your choice.

10. Modify **docker.service** and remove uncessary items by running the following command.

    `sudo vim /lib/systemd/system/docker.service`

    Scroll down and find the line **ExecStart=/usr/bin/dockerd -H fd://**. Remove **-H fd://** from the line and save.

11. Reload and restart Docker by running the following commands.

    `sudo service docker stop`

    Then enter the next command:

    `sudo systemctl daemon-reload`

    Then enter the next command:

    `sudo service docker start`

If everything worked correctly, issuing the command `sudo docker ps` should work fine without any errors.

## Generating a Self-Signed Certificate Using a Private CA for NGINX

Following these instructions will create a private Certificate Authority with a server key. This key will be signed by the newly created Certificate Authority. In addition, [Subject Alternate Names](https://en.wikipedia.org/wiki/Subject_Alternative_Name) will be included so that one certificate can apply to multiple domain names and even IP addresses.

**Note:** If using a certificate generated from a trusted CA (e.g. non-private, you paid for a certificate from a trusted company), that certificate is likely already trusted by the default trust store. Therefore, this section may not apply (except for where to place the certificate files). However, it's important to ensure the certificate is configured in such a way that will work with the setup shown below. Please review this section carefully before requesting and paying for a certificate.

1. Make the necessary directories by running the following commands:

   `sudo mkdir ca`

   `cd ca`

   `sudo mkdir certs keys config`

   **Important:** Be sure to keep track of the absolute path of the CA folder. This will later be referred to as `path_to_ca_files`. Also, the absolute path used to clone this repository into will be referred to as `path_to_repo_files`. Be sure to replace both of these with the proper paths.

2. Copy [server.cnf](./ca-config/server.cnf) and [ca.cnf](./ca-config/ca.cnf) into the config folder (e.g. **/path_to_ca_files/config**).

3. Edit **server.cnf** to include the appropriate domains under the **alt_names** section. Below is what is currently listed with an explanation.

   ```bash
   [ alt_names ]
   DNS.1                            = jenkins.dev.internal.example.com
   DNS.2                            = *.internal.example.com
   DNS.3                            = *.dev.internal.example.com
   IP.1                             = 192.168.1.50
   ```

   The **DNS.1** entry is the primary FQDN that will be used externally (outside of the internal Docker network the containers use) to access Jenkins. Feel free to change this to your liking. However, be sure to update any [wildcard](https://en.wikipedia.org/wiki/Wildcard_certificate) entries to match. It is important to ensure the first entry is a FQDN and not in the form of a wildcard or problems may occur.

   The additional DNS entries can each be a wildcard but keep in mind the asterisk will only apply to sub-domains at its current level. This is why **DNS.2** and **DNS.3** are formatted the way they are. For example, in the **DNS.2** entry, the certificate will be valid for **murmur.internal.example.com** or **gitlab.internal.example.com** but not **silly.dev.internal.example.com** (in that case DNS.3 takes care of matching the sub-domain that **silly** is defined at).

   Finally, change the **IP.1** entry to match the IP address of the host running Docker. This will allow you to go to **https://192.168.1.50:52443** without any warnings, assuming the certificate is trusted.

   **Note:** Setting up a private DNS server may help with certain use cases. Please see [this repository](https://github.com/GetchaDEAGLE/bind-private-dns-docker) for help with that if applicable.

3. Based on the results from the previous step, modify [docker-compose.yml](./docker-compose.yml) to ensure each network alias for each service matches the domain naming scheme being used. For example, the name of each service network alias by default is **jenkins-master.dev.internal.example.com** and **jenkins-nginx.dev.internal.example.com**. The reason the service network aliases use this format is it allows the applicable containers to securely communicate using HTTPS using a certificate that matches these names (in this case, the **DNS.3** entry will match these).

   Each service network alias works with the Docker Internal Name Resolution Service. In other words, inside the Docker internal network the containers run in, making a call to **jenkins-nginx.dev.internal.example.com** (this won't work externally) will resolve to the internal IP address that the Jenkins NGINX container uses. In order to prevent ignoring certificate validations, each service network alias must match any of the DNS entries defined in **server.cnf**.

4. Edit [jenkins.conf](./jenkins-nginx/config/jenkins.conf) and change line 21 to properly match the service network alias defined in **docker-compose.yml** for Jenkins Master.

   Default Line 21 Entry: `proxy_pass         http://jenkins-master.dev.internal.example.com:8080;`

   Only change the FQDN and keep **http://** and **:8080;** intact.

5. Edit [nginx.conf](./jenkins-nginx/config/nginx.conf) and change line 20 to properly match the service network alias defined in **docker-compose.yml** for Jenkins Master.

   Default Line 20 Entry: `server jenkins-master.dev.internal.example.com:50000;`

   Only change the FQDN and keep **:50000;** intact.

6. Create the CA by running the following commands:

   `sudo openssl genrsa -aes256 -out /path_to_ca_files/keys/ca-key.pem 4096`

   You will be prompted to enter a password for **ca-key.pem** to protect it. Make sure to enter a good one and don't lose it.

   `sudo openssl req -new -x509 -config /path_to_ca_files/config/ca.cnf -days 365 -key /path_to_ca_files/keys/ca-key.pem -out /path_to_ca_files/certs/ca-cert.pem`

   **Note:** Feel free to change the integer after **-days** to match the length of time desired for the CA certificate to be valid.

   You will be prompted to enter information such as Country Name, Organization Name, etc. Below are example entries.

   ```bash
   countryName             = "US"
   stateOrProvinceName     = "Texas"
   localityName            = "Austin"
   organizationName        = "Spacely Space Sprockets Inc."
   organizationalUnitName  = "Spacely Space Sprockets CA"
   commonName              = "Spacely Space Sprockets CA"
   ```

7. Create the server key and certificate signing request by running the following commands:

   `sudo openssl genrsa -out /path_to_ca_files/keys/server-key.pem 4096`

   `sudo openssl req -subj "/CN=jenkins.dev.internal.example.com/O=server/" -sha256 -new -key /path_to_ca_files/keys/server-key.pem -out server.csr`

   Be sure the change **jenkins.dev.internal.example.com** to match the FQDN used to access Jenkins externally (this is different than the internal service network aliases defined in docker-compose.yml) as discussed in the previous steps (e.g. DNS.1 entry in server.cnf).

8. Sign the public key with the CA and create the server certificate by running the following command:

   ```bash
   sudo openssl x509 -req -days 365 -sha256 -in server.csr -CA /path_to_ca_files/certs/ca-cert.pem -CAkey /path_to_ca_files/keys/ca-key.pem \
       -CAcreateserial -out /path_to_ca_files/certs/server-cert.pem -extfile /path_to_ca_files/config/server.cnf -extensions v3_req
   ```

   **Note:** Feel free to change the integer after **-days** to match the length of time desired for the server certificate to be valid.

9. Remove the certificate signing request by typing the following command:

   `sudo rm -v /path_to_ca_files/server.csr`

10. Convert the CA certificate to **DER encoded binary x.509** format by running the following command:

    `sudo openssl x509 -outform der -in /path_to_ca_files/certs/ca-cert.pem -out /path_to_ca_files/certs/ca-cert.crt`

11. Protect the generated keys by making them readable only by you by typing the following command:

    `sudo chmod -v 0400 /path_to_ca_files/keys/ca-key.pem /path_to_ca_files/keys/server-key.pem`

12. Protect the generated certificates by making them read only by typing the following command:

    `sudo chmod -v 0444 /path_to_ca_files/certs/ca-cert.pem /path_to_ca_files/certs/ca-cert.crt /path_to_ca_files/certs/server-cert.pem`

13. Import the CA certificate into each applicable machine accessing Jenkins so as to prevent the certificate warning from being shown in the browser.

    **For Windows**

    Copy **ca-cert.crt** to each machine and then import it into the Trusted Root CA Certificates in **certmgr**. Go to run then type **certmgr.msc** then expand **Trusted Root Certificatation Authorities**. Right click on the folder named **Certificates** then select **All Tasks** -> **Import**. Find the **ca-cert.crt** copied to the machine and use that file for the import.

    Restart the browser accessing the secured resource. The certificate warning message should no longer be present.

    **All Others**

    The steps to do this in other operating systems varies. If using Chrome, [this article](http://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate) has many tips that will likely apply to most operating systems. It is suggested to do the necessary research based on your situation to accomplish this task since there is no one-sized fits all solution.

14. Copy the certificate files to the appropriate location by running the following commands:

    `sudo mkdir -p /path_to_repo_files/jenkins-nginx/volume_data/ssl`

    `sudo cp /path_to_ca_files/certs/server-cert.pem /path_to_ca_files/keys/server-key.pem /path_to_repo_files/jenkins-nginx/volume_data/ssl`

## Preparing Jenkins Slave For Successful Certificate Validation

**Important:** Be sure to keep track of the absolute path of the CA folder. This will later be referred to as `path_to_ca_files`. Also, the absolute path used to clone this repository into will be referred to as `path_to_repo_files`. Be sure to replace both of these with the proper paths.

1. Create the directory to hold the new trust store ([cacerts](https://s3.amazonaws.com/smhelpcenter/smhelp940/classic/Content/security/concepts/what_is_a_cacerts_file.htm)) by running the following command:

   `sudo mkdir -p /path_to_repo_files/jenkins-slave/volume_data/ssl`

2. Copy the default **cacerts** file from Jenkins Slave to the newly created folder from the previous step by running the following commands:

   `sudo su`

   `docker run --rm --entrypoint cat danieleagle/jenkins-slave:8u151-jre-alpine /usr/lib/jvm/java-1.8-openjdk/jre/lib/security/cacerts > /path_to_repo_files/jenkins-slave/volume_data/ssl/cacerts`

   `exit`

3. Import the CA certificate created earlier (not the server certificate) into the new trust store by running the following command:

   `sudo keytool -noprompt -storepass changeit -keystore /path_to_repo_files/jenkins-slave/volume_data/ssl/cacerts -import -file /path_to_ca_files/certs/ca-cert.pem -alias MyPrivateCA`

   Feel free to give a more descriptive alias than *MyPrivateCA*.

4. Change the updated trust store to ready only to prevent accidental changes by running the following command:

   `sudo chmod -v 0444 /path_to_repo_files/jenkins-slave/volume_data/ssl/cacerts`

Additional settings will be specified later when configuring the Yet Another Docker plugin to ensure the updated trust store is used by the Jenkins Slave.

## Configuring Jenkins to Use Ephemeral Build Slaves

With the Docker Daemon secured using TLS and Jenkins Master running behind a NGINX reverse proxy using HTTPS, work can proceed to configure the Jenkins slave options.

**Important:** Be sure to keep track of the absolute path used to clone this repository. It will be referred to as `path_to_repo_files`. Be sure to replace this with the proper paths.

1. While in Jenkins (e.g. https://jenkins.dev.internal.example.com:52443), on the left sidebar go to **Credentials** and then on the sidebar below Credentials, click **System**.

2. Click on **Global credentials (unrestricted)** and then click **Add Credentials** in the left sidebar.

3. For **Kind**, select **Docker Host Certificate Authentication** and for the **Scope**, choose **Global (Jenkins, nodes, items, all child items, etc)**.

4. Locate the client key used to secure the Docker Daemon. If it wasn't deleted, it should still be in **/home/user/.docker**. Check by issuing the following commands.

   `cd ~/.docker`

   `ls`

   If **key.pem** is there then proceed to the next step. Otherwise, revisit [Securing the Docker Daemon Using TLS](./README.md#securing-the-docker-daemon-using-tls).

5. Copy the contents of **key.pem** and paste into the **Client Key** field in Jenkins.

6. Locate the client certificate used to secure the Docker Daemon. It should be in **/home/user/.docker**. Copy the contents of **cert.pem** and paste into the **Client Certificate** field in Jenkins.

7. Locate CA certificate used to secure the Docker Daemon. It should be in **/home/user/.docker**. Copy the contents of **ca.pem** and paste into the **Server CA Certificate** field in Jenkins.

8. Click **OK** when finished.

9. On the left sidebar, click **Manage Jenkins** then **Configure System**.

10. Scroll down to the section titled **Cloud** and find **Yet Another Docker**. For the **Cloud Name** field, enter a desired name (e.g. hostname of Docker Machine) and for the **Docker URL** field, enter `tcp://192.168.1.50:2376`. Be sure to replace the IP address with that of the one running Docker Machine.

11. Under the **Host Credentials** field, select the recently added credentials created in the previous steps.

12. Under the **Type** field, select **NETTY** and then click on the **Test Connection** button. If no errors are displayed, move on to the next step. Otherwise, retrace/retry previous steps.

13. Under the **Max Containers** field, the default is **50**. This is the maximum amount of Jenkins slave containers that will be provisioned at any given time. Change this value to the desired amount or leave it as default.

14. Under the **Images** section, click the **Add Docker Template** button and select **Docker Template**. For the **Docker Image Name**, enter `danieleagle/jenkins-slave:8u151-jre-alpine`.

15. Under the **Pull Image Settings** section, locate the **Pull Strategy** field and select **Pull never**. Since the image is local there is no need to pull it, so ensure this setting is set correctly.

16. Under the **Create Container Settings** section, click the **Create Container settings...** button. Scroll down to **Volumes** and enter `/path_to_repo_files/jenkins-slave/volume_data/ssl:/etc/ssl/java/truststore:ro` into the field. Change **path_to_repo_files** to the folder where you cloned this repository. It's important to make sure to use the [absolute path instead of relative](http://www.linuxnix.com/abslute-path-vs-relative-path-in-linuxunix/).

    **Note:** This step can be skipped if using a certificate generated from a trusted CA (non-private). If you paid for a certificate from a trusted company, that certificate is likely already trusted by the default trust store. In that case, referring to a different trust store is likely unnecessary.

17. While still in the **Create Container Settings** section, scroll down to **Network Mode** and enter `development` into the field.

18. Under the **Remove Container Settings** section, check **Remove volumes**.

19. For the **Labels** field, enter `jenkins-slave-node`.

    **Note:** This name should match the node found in the pipeline script.

20. Under the **Usage** field, select **Only build jobs with label expressions matching this node**.

21. Under the **Launch method** field, select **Docker JNLP launcher**.

22. Under the **Linux user** field, enter `jenkins`.

23. Under the **Slave (slave.jar) options** field, enter `-workDir /home/jenkins`.

24. Under the **Slave JVM options** field, enter `-Xmx8192m -Djava.awt.headless=true -Duser.timezone=America/Chicago -Djavax.net.ssl.trustStore=/etc/ssl/java/truststore/cacerts`. Be sure the change the timezone to the appropriate value.

    **Note:** If using a certificate generated from a trusted CA (non-private), the string **-Djavax.net.ssl.trustStore=/etc/ssl/java/truststore/cacerts** can be omitted. If you paid for a certificate from a trusted company, that certificate is likely already trusted by the default trust store. In that case, referring to a different trust store is likely unnecessary.

25. Under the **Different jenkins master URL** field, enter `https://jenkins-nginx.dev.internal.example.com`. Be sure to change the format of this URL based on the applicable domain being used (defined as the Jenkins NGINX service network alias in **docker-compose.yml**). This was discussed earlier when [creating a self-signed certificate](./README.md#generating-a-self-signed-certificate-using-a-private-ca-for-nginx) using a private CA.

26. When done with everything, click the **Save** button at the bottom of the page.

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
    server jenkins-master.dev.internal.example.com:50000;
  }
}
```

## Container Network

The network specified (can be changed to the desired value) by these Docker containers is named `development`. It is assumed that this network has already been created prior to using the included Docker Compose file. The reason for this is to avoid generating a default network so that other Docker containers can access the services these containers expose using the [Docker embedded DNS server](https://docs.docker.com/engine/userguide/networking/#/docker-embedded-dns-server).

If no network has been created, run the following Docker command: `sudo docker network create network-name`. Be sure to replace *network-name* with the name of the desired network. For more information on this command, go [here](https://docs.docker.com/engine/reference/commandline/network_create/).

## Port Mapping

The external ports used to map to the internal ports that Jenkins uses are 52443 (maps to 443 for HTTPS) and 50000 (maps to 50000 for JNLP). These ports can certainly be changed but please be mindful of the effects. Additional configuration may be required as a result.

## Data Volumes

It is possible to change the data volume folders mapped to the Jenkins Master container to something other than `./volume_data/x` if desired. It is recommended to choose a naming scheme that is easy to recognize. Additional configuration may be required as a result.

## Notes About the Included Make File

Instead of accessing Docker Compose directly, a [makefile](./makefile) is included and should be used instead. The reason for this is that the Jenkins slave shouldn't be running right away; it should only run when it's required. All that will be handled dynamically by the [Yet Another Docker Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Yet+Another+Docker+Plugin) which is included with the Jenkins Master container. Thus, using the **makefile** will prevent the Jenkins Slave from running right away.

## Logging

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

Finally, if running in a production environment where logs are closely monitored, it's recommended to use something like [Fluentd](http://www.fluentd.org/). This aggregates all your logs and makes them easily searchable. Granted, Fluentd does much more than this so it's recommended to check out the official docs. The great news is Docker has a [native Fluentd logging driver](https://docs.docker.com/engine/admin/logging/fluentd/).

If Fluentd has been setup and you wish to use it, **docker-compose.yml** will need to be modified to ensure it uses it instead of the default logging driver. Under each defined service, add the following:

```bash
logging:
  driver: fluentd
  options:
    fluentd-address: localhost:24224
    tag: "{{.ImageName}}/{{.Name}}/{{.ID}}"
```

## Jenkins Plugins

The file [plugins.txt](./jenkins-master/config/plugins.txt) is used to install plugins for Jenkins when creating the Jenkins Master container. Additional plugins can be added (they can be removed as well) to this file before creating the container. Also, from time to time the plugins listed within this file may become out of date and require specifying the newest versions.

## Jenkins Slave OS

It is possible to use a different OS for Jenkins slaves. However, it will require a specific configuration that works for the desired OS. In addition, the OS should work with the plugin used for the Jenkins slaves, [Yet Another Docker Plugin](https://github.com/KostyaSha/yet-another-docker-plugin). Thus, it will need to make use of [OpenJDK](http://openjdk.java.net/).

## Jenkins Slave Tools

The included Jenkins slave container doesn't have all the tools needed for every given objective or build task. It will need to be modified to include the appropriate tools. In addition, certain Jenkins plugins may need to be installed in order to achieve a specific task to complement the Jenkins Slave.

## Using This Solution with Docker Swarm

It is possible to adapt this solution for use with [Docker Swarm](https://docs.docker.com/engine/swarm/). Take a look at [this article](https://danieleagle.com/2017/10/setting-up-a-private-cicd-solution-in-azure/) for details.

## Further Reading

This solution was inspired from an article by Maxfield Stewart from Riot Games found [here](https://engineering.riotgames.com/news/building-jenkins-inside-ephemeral-docker-container). He also offers a repository that complements the article found [here](https://github.com/maxfields2000/dockerjenkins_tutorial/tree/master/jenkins2).

## Special Thanks

Special thanks goes to [David Hale](https://github.com/vorpleblade) for streamlining the process to secure the Docker Daemon and [Maxfield Stewart](https://github.com/maxfields2000) as mentioned above for his amazing article that served as inspiration for this solution.
