#!/bin/bash

# For this script to work, you must clone every desired repository to its associated folder in DockerVolumes
# Ex.  for rpebpp, you must clone ssh://git@stash.mailserviceslc.com:7999/rp/rpebpp.git to /Code/DockerVolumes/rpebpp

# Repository Folders are:

# rpebpp
# blaster
# docflow
# dfdig
# mcgmobile
# mcgwebsite
# mswebsite
# ozarkwebsite
# pspwebsite
# qpswebsite
# nevada
# rpebppLaravel
# voltron

# This line is run just to initialize a directory to copy files over.

mkdir -p /home/centos/Code

# Now that the Code directory exists, you can SCP everything over and change permissions.

sudo chown centos:centos -R /home/centos/Code

sudo echo "if [ -f ~/.bashrc ]; then" > ~/.bash_profile
sudo echo "source ~/.bashrc" >> ~/.bash_profile
sudo echo "fi" >> ~/.bash_profile

sudo echo "sudo systemctl restart httpd.service" >> ~/.bashrc
sudo echo "sudo systemctl restart docker.service" >> ~/.bashrc
sudo echo "source ~/storingOldIPs.sh" >> ~/.bash_profile
sudo echo "sudo sh ~/storingOldIPs.sh" >> ~/.bashrc

sudo echo -e '#!/bin/bash' > ~/storingOldIPs.sh

# Set Hostname

sudo hostname www01.dockerhost01.opnstk01.dev.mailserviceslc.com

# Add locate feature

sudo yum -y update
sudo yum -y install mlocate
sudo updatedb

# Create folder for Database

sudo mkdir -p /var/lib/mysql

# Get current IP

host=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)

# Create Clear Logs Script for Debugging

sudo echo "sudo echo \"\" > /var/log/httpd/access_log" > ~/clearLogs.sh
sudo echo "sudo echo \"\" > /var/log/httpd/error_log" >> ~/clearLogs.sh
sudo echo "sudo echo \"\" > /var/log/httpd/ssl_error_log" >> ~/clearLogs.sh
sudo echo "sudo echo \"\" > /var/log/httpd/ssl_access_log" >> ~/clearLogs.sh
sudo echo "sudo echo \"\" > /var/log/httpd/ssl_request_log" >> ~/clearLogs.sh
sudo echo "sudo service httpd restart" >> ~/clearLogs.sh
sudo cp ~/clearLogs.sh /etc/clearLogs.sh

# Install Apache

sudo yum clean all
sudo yum -y update
sudo yum -y install httpd
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload

#Configuring rysnc backup system for relaying Code to /var/www/html

cd ~/
sudo echo -e '#!/bin/bash\nxmodmap "keysym Alt_R = Multi_key"' > rsyncBackup.sh
sudo echo "while true " >> rsyncBackup.sh
sudo echo "do" >> rsyncBackup.sh
sudo echo "    rsync --delete -avz /home/centos/Code/* /var/www/html/" >> rsyncBackup.sh
sudo echo "    sleep 1s" >> rsyncBackup.sh
sudo echo "done" >> rsyncBackup.sh
sudo mv rsyncBackup.sh /etc/rsyncBackup.sh
sudo cp -R /home/centos/Code/* /var/www/html/
sudo rm -rf /home/centos/Code

# Set Up Cron

echo "@reboot sudo sh /etc/rsyncBackup.sh" >> cron

crontab cron
yes Y | rm cron

# Install epel

sudo rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm

#Configure Global SSL

cd ~/

sudo yum install -y ca-certificates
sudo update-ca-trust enable

sudo yum install -y mod_ssl openssl
openssl genrsa -out ca.key 2048

sudo echo "echo \"US\"" > sslConfigs.sh
sudo echo "echo \"IA\"" >> sslConfigs.sh
sudo echo "echo \"Urbandale\"" >> sslConfigs.sh
sudo echo "echo \"Mail Services\"" >> sslConfigs.sh
sudo echo "echo \"NA\"" >> sslConfigs.sh
sudo echo "echo \"$host\"" >> sslConfigs.sh
sudo echo "echo \"NA\"" >> sslConfigs.sh
sudo echo "echo \"password\"" >> sslConfigs.sh
sudo echo "echo \"Mail Services\"" >> sslConfigs.sh

sh sslConfigs.sh | openssl req -new -key ca.key -out ca.csr
openssl x509 -req -days 365 -in ca.csr -signkey ca.key -out ca.crt
sudo cp ca.key /etc/pki/tls/private/ca.key
sudo cp ca.crt /etc/pki/tls/certs/ca.crt
sudo cp ca.csr /etc/pki/tls/private/ca.csr

sudo yes Y | sudo cp ca.crt /etc/pki/ca-trust/source/anchors/

sudo rm -rf ca.key
sudo rm -rf ca.crt
sudo rm -rf ca.csr

sudo yes Y | rm -rf sslConfigs.sh

sudo sed -i  's/#DocumentRoot/DocumentRoot/g' /etc/httpd/conf.d/ssl.conf
sudo sed -i  's/#ServerName/ServerName/g' /etc/httpd/conf.d/ssl.conf
echo "sudo sed -i  's/www.example.com:443/$host/g' /etc/httpd/conf.d/ssl.conf" > ~/sslSHCommands.sh
sudo sh ~/sslSHCommands.sh
sudo rm -rf ~/sslSHCommands.sh
sudo sed -i 's/\/etc\/httpd\/ssl\/apache.crt/\/etc\/pki\/tls\/certs\/ca.crt/g' /etc/httpd/conf.d/ssl.conf
sudo sed -i 's/\/etc\/httpd\/ssl\/apache.key/\/etc\/pki\/tls\/private\/ca.key/g' /etc/httpd/conf.d/ssl.conf
sudo sed -i 's/\/etc\/pki\/tls\/certs\/localhost.crt/\/etc\/pki\/tls\/certs\/ca.crt/g' /etc/httpd/conf.d/ssl.conf
sudo sed -i 's/\/etc\/pki\/tls\/private\/localhost.key/\/etc\/pki\/tls\/private\/ca.key/g' /etc/httpd/conf.d/ssl.conf

sudo update-ca-trust extract

# Configure httpd.conf

sudo cp /etc/httpd/conf/httpd.conf ~/httpd.conf
cd ~/
sudo sed -i 's/User apache/User apache/g' httpd.conf
echo "sudo sed -i 's/#ServerName www.example.com:80/ServerName $host/g' httpd.conf" > ~/httpdSHCommands.sh
sudo sh ~/httpdSHCommands.sh
sudo rm -rf ~/httpdSHCommands.sh
sudo chown centos:centos httpd.conf
sudo chown root:root httpd.conf
yes Y | sudo cp ~/httpd.conf /etc/httpd/conf/httpd.conf 
sudo systemctl restart httpd.service

#Configure Permissions/Context for Selinux

sudo chown -R apache:apache /var/www/html/DockerVolumes
sudo chcon -Rv --type=httpd_sys_content_t /var/www/html
sudo systemctl restart httpd.service

# Adding Ports for Docker to Selinux

sudo semanage port -a -t http_port_t -p tcp 2376
sudo semanage port -a -t http_port_t -p tcp 9891
sudo semanage port -a -t http_port_t -p tcp 9892
sudo semanage port -a -t http_port_t -p tcp 9893
sudo semanage port -a -t http_port_t -p tcp 9894
sudo semanage port -a -t http_port_t -p tcp 9895
sudo semanage port -a -t http_port_t -p tcp 9896
sudo semanage port -a -t http_port_t -p tcp 9897
sudo semanage port -a -t http_port_t -p tcp 9898
sudo semanage port -a -t http_port_t -p tcp 9899
sudo semanage port -a -t http_port_t -p tcp 9900
sudo semanage port -a -t http_port_t -p tcp 9901
sudo semanage port -a -t http_port_t -p tcp 9902
sudo semanage port -a -t http_port_t -p tcp 9903
sudo semanage port -a -t http_port_t -p tcp 9904
sudo semanage port -a -t http_port_t -p tcp 9905
sudo semanage port -a -t http_port_t -p tcp 9906
sudo semanage port -a -t http_port_t -p tcp 9907
sudo semanage port -a -t http_port_t -p tcp 9908
sudo semanage port -a -t http_port_t -p tcp 9909
sudo semanage port -a -t http_port_t -p tcp 9910
sudo semanage port -a -t http_port_t -p tcp 10010
sudo semanage port -a -t http_port_t -p tcp 10011
sudo semanage port -a -t http_port_t -p tcp 10012
sudo semanage port -a -t http_port_t -p tcp 10013
sudo semanage port -a -t http_port_t -p tcp 10014
sudo semanage port -a -t http_port_t -p tcp 10015
sudo semanage port -a -t http_port_t -p tcp 10016
sudo semanage port -a -t http_port_t -p tcp 10017
sudo semanage port -a -t http_port_t -p tcp 10018
sudo semanage port -a -t http_port_t -p tcp 10019
sudo semanage port -a -t http_port_t -p tcp 10020
sudo semanage port -a -t http_port_t -p tcp 10021
sudo semanage port -a -t http_port_t -p tcp 10022
sudo semanage port -a -t http_port_t -p tcp 10023
sudo semanage port -a -t http_port_t -p tcp 10024
sudo semanage port -a -t http_port_t -p tcp 10025
sudo semanage port -a -t http_port_t -p tcp 10026
sudo semanage port -a -t http_port_t -p tcp 10027
sudo semanage port -a -t http_port_t -p tcp 10028
sudo semanage port -a -t http_port_t -p tcp 10029
sudo semanage port -a -t http_port_t -p tcp 10030

# Configure Docker Ports for iptables

sudo firewall-cmd --zone=public --add-port=2376/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9891/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9892/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9893/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9894/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9895/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9896/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9897/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9898/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9899/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9900/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9901/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9902/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9903/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9904/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9905/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9906/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9907/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9908/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9909/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9910/tcp --permanent

sudo firewall-cmd --zone=public --add-port=10010/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10011/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10012/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10013/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10014/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10015/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10016/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10017/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10018/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10019/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10020/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10021/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10022/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10023/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10024/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10025/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10026/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10027/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10028/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10029/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10030/tcp --permanent

sudo firewall-cmd --zone=external --add-forward-port=port=9891:proto=tcp:toport=10010
sudo firewall-cmd --zone=external --add-forward-port=port=9892:proto=tcp:toport=10011
sudo firewall-cmd --zone=external --add-forward-port=port=9893:proto=tcp:toport=10012
sudo firewall-cmd --zone=external --add-forward-port=port=9894:proto=tcp:toport=10013
sudo firewall-cmd --zone=external --add-forward-port=port=9895:proto=tcp:toport=10014
sudo firewall-cmd --zone=external --add-forward-port=port=9896:proto=tcp:toport=10015
sudo firewall-cmd --zone=external --add-forward-port=port=9897:proto=tcp:toport=10016
sudo firewall-cmd --zone=external --add-forward-port=port=9898:proto=tcp:toport=10017
sudo firewall-cmd --zone=external --add-forward-port=port=9899:proto=tcp:toport=10018
sudo firewall-cmd --zone=external --add-forward-port=port=9900:proto=tcp:toport=10019
sudo firewall-cmd --zone=external --add-forward-port=port=9901:proto=tcp:toport=10020
sudo firewall-cmd --zone=external --add-forward-port=port=9902:proto=tcp:toport=10021
sudo firewall-cmd --zone=external --add-forward-port=port=9903:proto=tcp:toport=10022
sudo firewall-cmd --zone=external --add-forward-port=port=9904:proto=tcp:toport=10023
sudo firewall-cmd --zone=external --add-forward-port=port=9905:proto=tcp:toport=10024
sudo firewall-cmd --zone=external --add-forward-port=port=9906:proto=tcp:toport=10025
sudo firewall-cmd --zone=external --add-forward-port=port=9907:proto=tcp:toport=10026
sudo firewall-cmd --zone=external --add-forward-port=port=9908:proto=tcp:toport=10027
sudo firewall-cmd --zone=external --add-forward-port=port=9909:proto=tcp:toport=10028
sudo firewall-cmd --zone=external --add-forward-port=port=9910:proto=tcp:toport=10029

sudo firewall-cmd --permanent --zone=public --add-source=192.168.115.101/24
sudo firewall-cmd --permanent --zone=public --add-source=192.168.115.101/32
sudo firewall-cmd --permanent --zone=public --add-source=192.168.115.106/24
sudo firewall-cmd --permanent --zone=public --add-source=192.168.115.106/32

sudo firewall-cmd --reload

# Make directories for Docker Mounted Shared Folders 
# (You should have done this manually and pulled 
# the desired repositories)

# Make directories for Docker Files

sudo mkdir -p /var/www/html/DockerFiles/base
sudo mkdir -p /var/www/html/DockerFiles/database
sudo mkdir -p /var/www/html/DockerFiles/dbseed
sudo mkdir -p /var/www/html/DockerFiles/mariadbserver
sudo mkdir -p /var/www/html/DockerFiles/mariadbclient
sudo mkdir -p /var/www/html/DockerFiles/ssl
sudo mkdir -p /var/www/html/DockerFiles/wget
sudo mkdir -p /var/www/html/DockerFiles/openssh
sudo mkdir -p /var/www/html/DockerFiles/httpd
sudo mkdir -p /var/www/html/DockerFiles/php54
sudo mkdir -p /var/www/html/DockerFiles/php56
sudo mkdir -p /var/www/html/DockerFiles/perldevel
sudo mkdir -p /var/www/html/DockerFiles/composer
sudo mkdir -p /var/www/html/DockerFiles/git
sudo mkdir -p /var/www/html/DockerFiles/laravel

sudo mkdir -p /var/www/html/DockerFiles/rpebpp
sudo mkdir -p /var/www/html/DockerFiles/blaster
sudo mkdir -p /var/www/html/DockerFiles/docflow
sudo mkdir -p /var/www/html/DockerFiles/dfdig
sudo mkdir -p /var/www/html/DockerFiles/nevada
sudo mkdir -p /var/www/html/DockerFiles/voltron
sudo mkdir -p /var/www/html/DockerFiles/rpebppLaravel


# Install Docker (I'm not sure why but the most fail safe way I've found to install Docker is to install Docker, uninstall Docker and then reinstall it. Simply installing it one time often won't allow docker to start. )

sudo groupadd docker
sudo useradd nova
sudo usermod -G docker nova

sudo modprobe dm_mod
sudo yum install -y docker-io
sudo systemctl restart docker.service

sudo yum -y remove docker.x86_64
sudo yum -y remove docker-selinux.x86_64
sudo rm -rf /var/lib/docker

sudo yum install -y docker-io
sudo systemctl restart docker.service

sudo chcon -Rv --type=httpd_sys_content_t /var/lib/docker
sudo restorecon -r /var/lib/docker
sudo chcon -Rv --type=httpd_sys_content_t /var/run
sudo restorecon -r /var/run

sudo yum update
sudo yum -y update && sudo yum -y install openssh-server apache2 supervisor
sudo mkdir -p /etc/supervisor/conf.d/
sudo cp /etc/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
sudo yum -y --enablerepo=base clean metadata

# Docker ssh (May need this later if CentOS 7 is removed)

# sudo rm -rf /va/run/docker.pid
# sudo systemctl stop docker.service
# sudo docker -d --tlsverify --tlscacert=/etc/pki/tls/certs/ca.crt --tlscert=/etc/pki/tls/certs/ca.crt --tlskey=/etc/pki/tls/private/ca.key -H=0.0.0.0:2376&
# mkdir -pv ~/.docker
# cp /etc/pki/tls/certs/ca.crt ~/.docker/ca.crt
# cp /etc/pki/tls/private/ca.key ~/.docker/ca.key
# export DOCKER_HOST=tcp://$HOST:2376 DOCKER_TLS_VERIFY=1

# Generate MariaDB Username & Password

host=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
sudo echo "host=$host" >> ~/.bashrc
sudo echo "export host" >> ~/.bashrc

salt=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
date=`date +%Y-%m-%d`
rawpassword="$date $host $salt"
rawpasswordLower=$(echo $rawpassword | tr '[:upper:]' '[:lower:]')
MYSQL_ROOT_PASSWORD=$(echo $rawpassword | sha256sum |base64 | head -c 32)
MYSQL_ROOT_PASSWORD_LOWERCASE=$(echo $MYSQL_ROOT_PASSWORD | tr '[:upper:]' '[:lower:]')
sudo echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" >> ~/.bashrc
sudo echo "MYSQL_ROOT_PASSWORD_LOWERCASE=$MYSQL_ROOT_PASSWORD_LOWERCASE" >> ~/.bashrc
sudo echo "export MYSQL_ROOT_PASSWORD" >> ~/.bashrc
sudo echo "export MYSQL_ROOT_PASSWORD_LOWERCASE" >> ~/.bashrc

salt=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
date=`date +%Y-%m-%d`
rawusername="$date $salt"
rawusernameLower=$(echo $rawusername | tr '[:upper:]' '[:lower:]')
MYSQL_USER=$(echo $rawusername | sha256sum |base64 | head -c 16)
MYSQL_USER_LOWERCASE=$(echo $MYSQL_USER | tr '[:upper:]' '[:lower:]')
sudo echo "MYSQL_USER=$MYSQL_USER" >> ~/.bashrc
sudo echo "MYSQL_USER_LOWERCASE=$MYSQL_USER_LOWERCASE" >> ~/.bashrc
sudo echo "export MYSQL_USER" >> ~/.bashrc
sudo echo "export MYSQL_USER_LOWERCASE" >> ~/.bashrc

sudo echo "TERM=dumb" >> ~/.bashrc
sudo echo "export TERM" >> ~/.bashrc

# Generate Mysql Sock

sudo echo "" > ~/mysql.sock
sudo cp ~/mysql.sock /var/lib/mysql/mysql.sock
sudo chown mysql:mysql -R /var/lib/mysql
ln -s /var/lib/mysql/mysql.sock /tmp/mysql.sock

# Move or Create Empty Dummmy Scripts for the SQLSeeds to prevent errors

sudo echo "" > ~/RPEBPPEntireDatabase.sql
sudo cp ~/RPEBPPEntireDatabase.sql /var/www/html/DockerFiles/mariadb/RPEBPPEntireDatabase.sql
sudo mv ~/RPEBPPEntireDatabase.sql /var/www/html/DockerFiles/dbseed/RPEBPPEntireDatabase.sql
sudo chmod 0755 -R /var/www/html/DockerFiles/mariadbserver/
sudo chown centos:centos -R /var/www/html/DockerFiles/mariadbserver/
sudo yes Y | cp /var/www/html/DockerVolumes/rpebpp/v2/db/SQLSeed/EntireDatabase.sql /var/www/html/DockerFiles/dbseed/RPEBPPEntireDatabase.sql
sudo yes Y | cp /var/www/html/DockerVolumes/rpebpp/v2/db/SQLSeed/EntireDatabase.sql /var/www/html/DockerFiles/mariadbserver/RPEBPPEntireDatabase.sql

# Generate Shell Script for Seeding Database

cd ~/

sudo echo -e '#!/bin/bash' > configureDatabase.sh
sudo echo "set e" >> configureDatabase.sh
sudo echo "systemctl restart mariadb.service" >> configureDatabase.sh
sudo echo "if [ ! \"$DBPopulated\" ]; then" >> configureDatabase.sh
sudo echo     "mysqladmin --user=root --password='' password \$MYSQL_ROOT_PASSWORD" >> configureDatabase.sh

sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE1\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE2\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE3\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE4\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE5\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE6\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE7\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE8\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE9\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"create database \$MYSQL_DATABASE10\"" >> configureDatabase.sh

sudo echo     "mysql rpweb_dev --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"GRANT ALL ON rpweb_dev.* TO root@'$host' IDENTIFIED BY '\$MYSQL_ROOT_PASSWORD'\"" >> configureDatabase.sh
sudo echo     "mysql rpweb_dev --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"GRANT ALL ON rpweb_dev.* TO root@'$host' IDENTIFIED BY '\$MYSQL_ROOT_PASSWORD'\"" >> configureDatabase.sh
sudo echo     "mysql rpweb_dev --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"GRANT ALL ON rpweb_dev.* TO root@'$host:9904' IDENTIFIED BY '\$MYSQL_ROOT_PASSWORD'\"" >> configureDatabase.sh

sudo echo     "mysql rpweb_dev < /tmp/RPEBPPEntireDatabase.sql --user=root --password=\$MYSQL_ROOT_PASSWORD" >> configureDatabase.sh
sudo echo     "mysql rpweb_dev --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"INSERT INTO Whitelist (address, description, active) VALUES ('$host', '$host', '1')\"" >> configureDatabase.sh
sudo echo     "mysql rpweb_dev --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"INSERT INTO Whitelist (address, description, active) VALUES ('172.17.42.1', '172.17.42.1', '1')\"" >> configureDatabase.sh
sudo echo     "mysql rpweb_dev --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"INSERT INTO Whitelist (address, description, active) VALUES ('10.2.5.15', '10.2.5.15', '1')\"" >> configureDatabase.sh
sudo echo     "mysql rpweb_dev --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"INSERT INTO Whitelist (address, description, active) VALUES ('192.168.115.106', '192.168.115.106', '1')\"" >> configureDatabase.sh
sudo echo     "mysql rpweb_dev --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"INSERT INTO Whitelist (address, description, active) VALUES ('192.168.56.1', '192.168.56.1', '1')\"" >> configureDatabase.sh

sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"CREATE USER '\$MYSQL_USER'@'$host' IDENTIFIED BY '\$MYSQL_ROOT_PASSWORD';\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"GRANT ALL PRIVILEGES ON *.* TO '\$MYSQL_USER'@'$host' WITH GRANT OPTION;\"" >> configureDatabase.sh
sudo echo     "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"GRANT ALL PRIVILEGES ON *.* TO 'root'@'$host' WITH GRANT OPTION;\"" >> configureDatabase.sh

sudo echo     "DBPopulated=true" >> configureDatabase.sh
sudo echo     "echo \"DBPopulated=true\" >> ~/.bashrc" >> configureDatabase.sh
sudo echo     "echo \"export DBPopulated true\" >> ~/.bashrc" >> configureDatabase.sh
sudo echo     "chown -R mysql:mysql /var/lib/mysql" >> configureDatabase.sh
sudo echo "fi" >> configureDatabase.sh

sudo cp configureDatabase.sh /var/www/html/DockerFiles/mariadbserver/configureDatabase.sh

# Generate Dockerfile for Base Image

cd ~/

sudo echo "FROM centos:7" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV BASE_IMAGE_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "USER root" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/base/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base /var/www/html/DockerFiles/base

# Generate Dockerfile for database volume

cd ~/

sudo echo "FROM mailserviceslc/base" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "WORKDIR /var/lib/mysql" >> Dockerfile
sudo echo "ENV DATABASE_VOLUME_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "VOLUME [\"/var/lib/mysql/:/var/lib/mysql/\"]" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/database/Dockerfile
sudo docker build --no-cache -t "mailserviceslc"/base-database /var/www/html/DockerFiles/database
sudo docker run  --name database --privileged=true -h hostname -d -i mailserviceslc/base-database /sbin/init* 

databaseIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' database)
old_databaseIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' database)
sudo echo "old_databaseIP=$databaseIP" >> ~/storingOldIPs.sh

sudo echo "sudo docker start database" >> ~/.bashrc
sudo echo "databaseIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' database)" >> ~/.bashrc
sudo echo "sed -i 's/\$old_databaseIP/\$databaseIP/g' ~/storingOldIPs.sh" >> ~/.bashrc

# Generate Dockerfile for openssh

cd ~/

sudo echo "FROM mailserviceslc/base" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV OPENSSH_REFRESHED_AT 2015-09-8" >> Dockerfile
sudo echo "RUN yum install -y openssh-server" >> Dockerfile
sudo echo "EXPOSE 22" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/openssh/Dockerfile
sudo docker build --no-cache -t "mailserviceslc"/base-openssh /var/www/html/DockerFiles/openssh

# Generate Dockerfile for SSL

cd ~/

sudo echo "FROM mailserviceslc/base-openssh" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV SSL_REFRESHED_AT 2015-09-8" >> Dockerfile
sudo echo "RUN yum -y install ca-certificates" >> Dockerfile
sudo echo "RUN update-ca-trust enable" >> Dockerfile
sudo echo "RUN yum -y install mod_ssl openssl" >> Dockerfile
sudo echo "RUN openssl genrsa -out ~/ca.key 2048" >> Dockerfile
sudo echo "RUN sed -i 's/#DocumentRoot/DocumentRoot/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile
sudo echo "RUN sed -i 's/#ServerName/ServerName/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile
sudo echo "RUN sed -i 's/www.example.com:443/$host/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile
sudo echo "RUN sed -i 's/\/etc\/httpd\/ssl\/apache.crt/\/etc\/pki\/tls\/certs\/ca.crt/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile
sudo echo "RUN sed -i 's/\/etc\/httpd\/ssl\/apache.key/\/etc\/pki\/tls\/private\/ca.key/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile
sudo echo "RUN sed -i 's/\/etc\/pki\/tls\/certs\/localhost.crt/\/etc\/pki\/tls\/certs\/ca.crt/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile
sudo echo "RUN sed -i 's/\/etc\/pki\/tls\/private\/localhost.key/\/etc\/pki\/tls\/private\/ca.key/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile
sudo echo "VOLUME [\"/etc/pki/:/etc/pki/\"]" >> Dockerfile
sudo echo "EXPOSE 443" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/ssl/Dockerfile
sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl /var/www/html/DockerFiles/ssl

sudo docker run -v /etc/pki/:/etc/pki/ -v /etc/clearLogs.sh:/home/centos/clearLogs.sh --name ssl --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl /sbin/init* 

sudo docker export --output=base-openssh-ssl.tar ssl
sudo docker stop ssl
sudo docker rm ssl
sudo docker rmi mailserviceslc/base-openssh-ssl
sudo cat base-openssh-ssl.tar | sudo docker import - mailserviceslc/base-openssh-ssl

sudo docker run -v /etc/pki/:/etc/pki/ -v /etc/clearLogs.sh:/home/centos/clearLogs.sh --name ssl --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl /sbin/init* 
sudo rm -rf base-openssh-ssl.tar


# Commands to Save Instead of Export (Benefits include preserving history and environment variables at cost of more space.)

# sudo docker save mailserviceslc/base-openssh-ssl > ~/base-openssh-ssl.tar 
# sudo docker stop ssl
# sudo docker rm ssl
# sudo docker rmi mailserviceslc/base-openssh-ssl
# sudo docker load < ~/base-openssh-ssl.tar

# Generate DockerFile for mariadb server

cd ~/

sudo echo "FROM mailserviceslc/base-openssh-ssl" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV MARIADB_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "ENV MYSQL_CONTAINER_NAME=\"mariadb\"" >> Dockerfile
sudo echo "ENV MYSQL_ROOT_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" >> Dockerfile
sudo echo "ENV MYSQL_ROOT_PASSWORD_LOWERCASE=\"$MYSQL_ROOT_PASSWORD_LOWERCASE\"" >> Dockerfile
sudo echo "ENV MYSQL_USER=\"$MYSQL_USER\"" >> Dockerfile
sudo echo "ENV MYSQL_USER_LOWERCASE=\"$MYSQL_USER_LOWERCASE\"" >> Dockerfile
sudo echo "ENV host=\"$host\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE1=\"rpweb_dev\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE2=\"blaster\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE3=\"dfdig\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE4=\"docflow\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE5=\"database5\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE6=\"database6\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE7=\"database7\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE8=\"database8\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE9=\"database9\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE10=\"database10\"" >> Dockerfile
sudo echo "ENV TERM dumb" >> Dockerfile
sudo echo "RUN echo \"MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"MYSQL_USER=$MYSQL_USER\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"TERM=dumb\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"export MYSQL_ROOT_PASSWORD\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"export MYSQL_USER\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"export TERM dumb\" >> ~/.bashrc" >> Dockerfile
sudo echo "COPY RPEBPPEntireDatabase.sql /tmp/" >> Dockerfile
sudo echo "COPY configureDatabase.sh /tmp/" >> Dockerfile
sudo echo "RUN cp /tmp/RPEBPPEntireDatabase.sql ~/RPEBPPEntireDatabase.sql" >> Dockerfile
sudo echo "RUN cp /tmp/configureDatabase.sh ~/configureDatabase.sh" >> Dockerfile
sudo echo "RUN chmod 755 -R /tmp/" >> Dockerfile
sudo echo "RUN yum -y update \\" >> Dockerfile
sudo echo "    && yum -y install \\" >> Dockerfile
sudo echo "        mariadb-server \\" >> Dockerfile
sudo echo "    && rm -rf /var/lib/apt/lists/* \\" >> Dockerfile
sudo echo "    && rm -rf /var/lib/mysql \\" >> Dockerfile
sudo echo "    && mkdir /var/lib/mysql \\" >> Dockerfile
sudo echo "    && chown mysql:mysql -R /var/lib/mysql \\" >> Dockerfile
sudo echo "    && rm -rf /var/lib/mysql/test " >> Dockerfile
sudo echo "RUN /usr/bin/mysqld_safe&" >> Dockerfile
sudo echo "RUN yum -y update" >> Dockerfile
sudo echo "RUN echo \"\" > /var/lib/mysql/mysql.sock" >> Dockerfile
sudo echo "RUN ln -s /var/lib/mysql/mysql.sock /tmp/mysql.sock" >> Dockerfile
sudo echo "RUN systemctl enable mariadb.service" >> Dockerfile
sudo echo "EXPOSE 3306" >> Dockerfile
sudo echo "CMD [\"systemctl\",\"restart\",\"mariadb.service\"]" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/mariadbserver/Dockerfile
sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbserver /var/www/html/DockerFiles/mariadbserver
sudo docker run --volumes-from database --volumes-from ssl -v /var/www/html/DockerFiles/mariadbserver/:/home/mariadbconfigs/ -p 22 -p 9891:3306 --name mariadb --link database:mariadb --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbserver /sbin/init* 

mariadbIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mariadb)
old_mariadbIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mariadb)
sudo echo "old_mariadbIP=$mariadbIP" >> ~/storingOldIPs.sh

sudo echo "sudo docker start mariadb" >> ~/.bashrc
sudo echo "mariadbIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mariadb)" >> ~/.bashrc
sudo echo "sed -i 's/\$old_mariadbIP/\$mariadbIP/g' ~/storingOldIPs.sh" >> ~/.bashrc

sudo docker exec -it mariadb /bin/bash -c "sh ~/configureDatabase.sh";

# Generate DockerFile for mariadb server

# $ docker run -it --link mariadb:mariadb2 --rm mariadb2 sh -c 'exec mysql -h"$host:9891" -P"3306" -uroot -p"$MYSQL_ROOT_PASSWORD"'
# docker run -it --link some-mysql:mysql --rm mysql sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p"$MYSQL_ROOT_PASSWORD"'

# Generate Dockerfile for MariaDB-Client

sudo echo "FROM mailserviceslc/base-openssh-ssl" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV MARIADB_CLIENT_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "RUN yum install -y mariadb" >> Dockerfile
sudo echo "RUN mkdir -p /var/lib/mysql/" >> Dockerfile
sudo echo "RUN echo \"\" > /var/lib/mysql/mysql.sock" >> Dockerfile
sudo echo "RUN ln -s /var/lib/mysql/mysql.sock /tmp/mysql.sock" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/mariadbclient/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient /var/www/html/DockerFiles/mariadbclient

# Generate Dockerfile for wget

cd ~/

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV WGET_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "RUN yum -y install wget" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/wget/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget /var/www/html/DockerFiles/wget

# Generate Dockerfile for Git

cd ~/

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient-wget" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV GIT_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "RUN cd ~/" >> Dockerfile
sudo echo "RUN yum install -y git" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/git/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git /var/www/html/DockerFiles/git

# Generate Dockerfile for httpd

cd ~/

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient-wget-git" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV HTTPD_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "RUN yum -y install httpd" >> Dockerfile
sudo echo "RUN systemctl enable httpd.service" >> Dockerfile
sudo echo "RUN chown -R apache:apache /var/www/html/" >> Dockerfile
sudo echo "RUN bash -c echo \"systemctl restart httpd.service\" >> ~/clearLogs.sh" >> Dockerfile
sudo echo "EXPOSE 80 137 138 139 445" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/httpd/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git-httpd /var/www/html/DockerFiles/httpd

sudo docker run --volumes-from ssl --name httpd --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd /sbin/init* 

sudo docker export --output=base-openssh-ssl-mariadbclient-wget-git-httpd.tar httpd
sudo docker stop httpd
sudo docker rm httpd
sudo docker rmi mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd
sudo cat base-openssh-ssl-mariadbclient-wget-git-httpd.tar | sudo docker import - mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd

sudo rm -rf base-openssh-ssl-mariadbclient-wget-git-httpd.tar

# Generate Dockerfile for PHP 5.4

cd ~/

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV PHP54_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "RUN wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm" >> Dockerfile
sudo echo "RUN rpm -ivh epel-release-7-5.noarch.rpm" >> Dockerfile
sudo echo "RUN yum -y install --enablerepo=\"epel\" php-mcrypt" >> Dockerfile
sudo echo "RUN yum -y install php-mcrypt*" >> Dockerfile
sudo echo "RUN yum -y install php php-cli php-common php-devel php-mbstring php-mcrypt php-mysql php-opcache php-pdo php-xml" >> Dockerfile
sudo echo "RUN cd ~/" >> Dockerfile
sudo echo "RUN cp /etc/php.ini ~/php.ini" >> Dockerfile
sudo echo "RUN sed -i 's/mysql.default_socket =/mysql.default_socket = var\/lib\/mysql\/mysql.sock/g' ~/php.ini" >> Dockerfile
sudo echo "RUN sed -i 's/;date.timezone =/date.timezone = \"US\/Central\"/g' ~/php.ini" >> Dockerfile
sudo echo "RUN yes Y | cp ~/php.ini /etc/php.ini" >> Dockerfile
sudo echo "RUN systemctl enable httpd.service" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/php54/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git-httpd-php54 /var/www/html/DockerFiles/php54

# sudo docker run --volumes-from ssl --name php54 --privileged=true -h hostname  -d -i mailserviceslc/base-openssh-ssl-wget-httpd-php54 /sbin/init* 

# Generate Dockerfile for perl-devel

cd ~/

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php54" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV PERL-DEVEL_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "RUN yum -y install perl-devel" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/perldevel/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git-httpd-php54-perldevel /var/www/html/DockerFiles/perldevel

# Generate DockerFile for rpebpp

cd ~/

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php54-perldevel" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV RPEBPP_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "ENV MYSQL_ROOT_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" >> Dockerfile
sudo echo "ENV MYSQL_ROOT_PASSWORD_LOWERCASE=\"$MYSQL_ROOT_PASSWORD_LOWERCASE\"" >> Dockerfile
sudo echo "ENV MYSQL_USER=\"$MYSQL_USER\"" >> Dockerfile
sudo echo "ENV MYSQL_USER_LOWERCASE=\"$MYSQL_USER_LOWERCASE\"" >> Dockerfile
sudo echo "ENV mariadbIP=\"$mariadbIP\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE=\"rpweb_dev\"" >> Dockerfile
sudo echo "ENV TERM dumb" >> Dockerfile
sudo echo "RUN echo \"MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"MYSQL_ROOT_PASSWORD_LOWERCASE=$MYSQL_ROOT_PASSWORD_LOWERCASE\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"MYSQL_USER=$MYSQL_USER\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"MYSQL_USER_LOWERCASE=$MYSQL_USER_LOWERCASE\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"MYSQL_DATABASE=$MYSQL_DATABASE\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"TERM=dumb\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"export MYSQL_ROOT_PASSWORD $MYSQL_ROOT_PASSWORD\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"export MYSQL_USER $MYSQL_USER\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"export MYSQL_ROOT_PASSWORD_LOWERCASE $MYSQL_ROOT_PASSWORD_LOWERCASE\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"export MYSQL_USER_LOWERCASE $MYSQL_USER_LOWERCASE\" >> ~/.bashrc" >> Dockerfile
sudo echo "RUN echo \"export TERM dumb\" >> ~/.bashrc" >> Dockerfile

sudo echo "RUN mkdir -p /var/www/html/v2/management/etc/" >> Dockerfile
sudo echo "RUN mkdir -p /var/www/html/v2/enduser" >> Dockerfile
sudo echo "RUN chown -R apache:apache /var/www/html/v2/management/etc" >> Dockerfile
sudo echo "RUN chown -R root:root /var/www/html/v2" >> Dockerfile
sudo echo "RUN echo \"dbhost = $mariadbIP\" > ~/dbconfig_dev" >> Dockerfile
sudo echo "RUN echo \"dbuser = $MYSQL_USER_LOWERCASE\" >> ~/dbconfig_dev" >> Dockerfile
sudo echo "RUN echo \"dbpass = $MYSQL_ROOT_PASSWORD_LOWERCASE\" >> ~/dbconfig_dev" >> Dockerfile
sudo echo "RUN echo \"dbname = rpweb_dev\" >> ~/dbconfig_dev" >> Dockerfile
sudo echo "RUN chown apache:apache ~/dbconfig_dev" >> Dockerfile
sudo echo "RUN chmod 755 ~/dbconfig_dev" >> Dockerfile
sudo echo "RUN yes Y | cp ~/dbconfig_dev /var/www/html/v2/management/etc/dbconfig_dev" >> Dockerfile
sudo echo "RUN yes Y | cp ~/dbconfig_dev /var/www/html/v2/management/etc/key_dev" >> Dockerfile
sudo echo "RUN yes Y | cp -R /var/www/html/v2/management/etc /var/www/html/v2/enduser" >> Dockerfile
sudo echo "RUN yes Y | cp -R /var/www/html/v2/management/etc /../" >> Dockerfile
sudo echo "RUN chown -R apache:apache /var/www/html/v2" >> Dockerfile
sudo echo "RUN mkdir -p /data/to_http/view/" >> Dockerfile
sudo echo "RUN mkdir -p /data/to_http/edit/" >> Dockerfile
sudo echo "RUN mkdir -p /data/log/" >> Dockerfile
sudo echo "RUN mkdir -p /data/conf/" >> Dockerfile
sudo echo "RUN echo \"\" > ~/queryerror.log" >> Dockerfile
sudo echo "RUN echo \"\" > ~/unauthorized.log" >> Dockerfile
sudo echo "RUN echo \"webdmo:dev_config\" >  ~/webdbqueue.conf" >> Dockerfile
sudo echo "RUN echo \"sfhdmo:dev_config\" >> ~/webdbqueue.conf" >> Dockerfile
sudo echo "RUN echo \"predmo:dev_config\" >> ~/webdbqueue.conf" >> Dockerfile
sudo echo "RUN echo \"allnon:dev_config\" >> ~/webdbqueue.conf" >> Dockerfile
sudo echo "RUN echo \"allyes:dev_config\" >> ~/webdbqueue.conf" >> Dockerfile
sudo echo "RUN chmod 755 -R /data" >> Dockerfile
sudo echo "RUN yes Y | cp ~/queryerror.log /data/conf/queryerror.log" >> Dockerfile
sudo echo "RUN yes Y | cp ~/unauthorized.log /data/log/unauthorized.log" >> Dockerfile
sudo echo "RUN yes Y | cp ~/webdbqueue.conf /data/conf/webdbqueue.conf" >> Dockerfile
sudo echo "RUN chmod 755 -R /data" >> Dockerfile
sudo echo "RUN chown -R apache:apache /data" >> Dockerfile

sudo echo "RUN yes Y | cp /etc/httpd/conf/httpd.conf ~/httpd.conf" >> Dockerfile
sudo echo "RUN cd ~/" >> Dockerfile
sudo echo "RUN sed -i 's/#ServerName www.example.com:80/ServerName $host/g' ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"Alias /ebp /var/www/html/v2/enduser/www/wwwroot\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"<Directory \\\"/var/www/html/v2/enduser/www/wwwroot\\\">\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"    AllowOverride All\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"    SSLOptions +StdEnvVars\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"    Order allow,deny\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"    Allow from 10.2\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"</Directory>\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"\" >> httpd.conf" >> Dockerfile
sudo echo "RUN echo \"Alias /mgmnt /var/www/html/v2/management/www\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"<Directory \\\"/var/www/html/v2/management/www\\\">\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"    AllowOverride All\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"    SSLOptions +StdEnvVars\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"    Order allow,deny\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"    Allow from 10.2\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN echo \"</Directory>\" >> ~/httpd.conf" >> Dockerfile
sudo echo "RUN yes Y | cp ~/httpd.conf /etc/httpd/conf/httpd.conf" >> Dockerfile
sudo echo "RUN rm -rf ~/httpd.conf" >> Dockerfile

sudo echo "RUN chown -R apache:apache /data" >> Dockerfile

sudo echo "RUN mv /usr/share/pear/PEAR.php /usr/share/pear/PEAR2.php" >> Dockerfile

sudo echo "RUN yum -y update" >> Dockerfile
sudo echo "CMD [\"/usr/bin/supervisord\"]" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/rpebpp/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git-httpd-php54-perldevel-rpebpp /var/www/html/DockerFiles/rpebpp

sudo docker run --volumes-from ssl -v /var/www/html/DockerVolumes/rpebpp:/var/www/html -p 22 -p 9904:443 --name rpebpp --link mariadb:rpebpp --privileged=true -h hostname  -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php54-perldevel-rpebpp /sbin/init* 

sudo docker exec -it rpebpp /bin/bash -c "rm -rf /var/www/html/v2/enduser/etc";
sudo docker exec -it rpebpp /bin/bash -c "mkdir /var/www/html/v2/enduser/etc";
sudo docker exec -it rpebpp /bin/bash -c "yes Y | cp ~/dbconfig_dev /var/www/html/v2/management/etc/dbconfig_dev";
sudo docker exec -it rpebpp /bin/bash -c "yes Y | cp ~/dbconfig_dev /var/www/html/v2/management/etc/key_dev";
sudo docker exec -it rpebpp /bin/bash -c "yes Y | cp ~/dbconfig_dev /var/www/html/v2/enduser/etc/dbconfig_dev";
sudo docker exec -it rpebpp /bin/bash -c "yes Y | cp ~/dbconfig_dev /var/www/html/v2/enduser/etc/key_dev";

rpebppIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' rpebpp)
old_rpebppIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' rpebpp)
sudo echo "old_rpebppIP=$rpebppIP" >> ~/storingOldIPs.sh

sudo echo "sudo docker start rpebpp" >> ~/.bashrc
sudo echo "rpebppIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' rpebpp)" >> ~/.bashrc
sudo echo "sed -i 's/\$old_rpebppIP/\$rpebppIP/g' ~/storingOldIPs.sh" >> ~/.bashrc

sudo echo "yes Y | cp /var/www/html/DockerFiles/mariadbserver/configureRPEBPPUsers.sh ~/configureRPEBPPUsers.sh" >> ~/.bashrc
sudo echo "yes Y | head -n -3  ~/configureRPEBPPUsers.sh > temp.sh ; mv temp.sh  ~/configureRPEBPPUsers.sh" >> ~/.bashrc
sudo echo "sudo echo \"mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \\\"DROP USER \$MYSQL_USER_LOWERCASE@\$old_rpebppIP;\\\"\" >> ~/configureRPEBPPUsers.sh" >> ~/.bashrc
sudo echo "sudo echo \"mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \\\"CREATE USER '\$MYSQL_USER_LOWERCASE'@'\$rpebppIP' IDENTIFIED BY '\$MYSQL_ROOT_PASSWORD_LOWERCASE';\\\"\" >> ~/configureRPEBPPUsers.sh" >> ~/.bashrc
sudo echo "sudo echo \"mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \\\"GRANT ALL PRIVILEGES ON *.* TO '\$MYSQL_USER_LOWERCASE'@'\$rpebppIP' WITH GRANT OPTION;\\\"\" >> ~/configureRPEBPPUsers.sh" >> ~/.bashrc
sudo echo "yes Y | sudo cp configureRPEBPPUsers.sh /var/www/html/DockerFiles/mariadbserver/configureRPEBPPUsers.sh" >> ~/.bashrc
sudo echo "sudo docker exec -it rpebpp /bin/bash -c \"sed -i 's/$old_mariadbIP/$mariadbIP/g' /var/www/html/v2/management/etc/dbconfig_dev\";" >> ~/.bashrc
sudo echo "sudo docker exec -it rpebpp /bin/bash -c \"yes Y | cp /var/www/html/v2/management/etc/dbconfig_dev /var/www/html/v2/management/etc/key_dev\";" >> ~/.bashrc
sudo echo "sudo docker exec -it rpebpp /bin/bash -c \"rm -rf /var/www/html/v2/enduser/etc\";" >> ~/.bashrc
sudo echo "sudo docker exec -it rpebpp /bin/bash -c \"mkdir /var/www/html/v2/enduser/etc\";" >> ~/.bashrc
sudo echo "sudo docker exec -it rpebpp /bin/bash -c \"yes Y | cp -R /var/www/html/v2/management/etc /var/www/html/v2/enduser\";" >> ~/.bashrc
sudo echo "sudo chown -R root:root /var/www/html/DockerFiles/mariadbserver" >> ~/.bashrc
sudo echo "sudo docker exec -it mariadb /bin/bash -c \"ln -s /var/lib/mysql/mysql.sock /tmp/mysql.sock\";" >> ~/.bashrc
sudo echo "sudo docker exec -it mariadb /bin/bash -c \"sh /home/mariadbconfigs/configureRPEBPPUsers.sh\";" >> ~/.bashrc

cd ~/

sudo echo -e '#!/bin/bash' > ~/configureRPEBPPUsers.sh
sudo echo "set e" >> ~/configureRPEBPPUsers.sh

sudo echo "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"CREATE USER '$MYSQL_USER_LOWERCASE'@'$rpebppIP' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD_LOWERCASE';\"" >> ~/configureRPEBPPUsers.sh
sudo echo "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER_LOWERCASE'@'$rpebppIP' WITH GRANT OPTION;\"" >> ~/configureRPEBPPUsers.sh

yes Y | sudo cp ~/configureRPEBPPUsers.sh /var/www/html/DockerFiles/mariadbserver/configureRPEBPPUsers.sh
suod chmod 755 /var/www/html/DockerFiles/mariadbserver/configureRPEBPPUsers.sh
sudo docker exec -it mariadb /bin/bash -c "sh /home/mariadbconfigs/configureRPEBPPUsers.sh";

sudo docker exec -it rpebpp /bin/bash -c "rm -rf /var/www/html/v2/enduser/etc";
sudo docker exec -it rpebpp /bin/bash -c "mkdir /var/www/html/v2/enduser/etc";
sudo docker exec -it rpebpp /bin/bash -c "yes Y | cp ~/dbconfig_dev /var/www/html/v2/management/etc/dbconfig_dev";
sudo docker exec -it rpebpp /bin/bash -c "yes Y | cp ~/dbconfig_dev /var/www/html/v2/management/etc/key_dev";
sudo docker exec -it rpebpp /bin/bash -c "yes Y | cp ~/dbconfig_dev /var/www/html/v2/enduser/etc/dbconfig_dev";
sudo docker exec -it rpebpp /bin/bash -c "yes Y | cp ~/dbconfig_dev /var/www/html/v2/enduser/etc/key_dev";

# sudo echo "RUN sed -i 's/\/etc\/pki\/tls\/certs\/localhost.crt/\/etc\/pki\/tls\/certs\/ca.crt/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile


# sudo echo "sed -i 's/\$old_rpebppIP/\$rpebppIP /var/www/html/DockerFiles/mariadbserver/configureRPEBPPUsers.sh" >> ~/.bashrc
# sudo echo "sed -i 's/\$old_mariadbIP/\$mariadbIP /var/www/html/DockerFiles/mariadbserver/configureRPEBPPUsers.sh" >> ~/.bashrc


# Generate DockerFile for docflow

cd ~/

sudo echo "FROM mailserviceslc/base-openssh-ssl-wget-git-httpd-php54" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV DOCFLOW_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "ENV MYSQL_ROOT_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" >> Dockerfile
sudo echo "ENV MYSQL_USER=\"$MYSQL_USER\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE=\"docflow\"" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/docflow/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git-httpd-php54-perldevel /var/www/html/DockerFiles/perldevel

sudo echo "docflowIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' docflow)" >> .bashrc
sudo echo "sudo docker start docflow" >> ~/.bashrc
sudo echo "sed -i 's/\$old_docflowIP/\$current_docflowIP/g' ~/.bashrc" >> ~/.bashrc
sudo echo "sed -i 's/\$current_docflowIP/\$docflowIP/g' ~/.bashrc" >> ~/.bashrc
sudo echo "current_docflowIP=\$docflowIP" >> ~/.bashrc

echo "old_docflowIP=$docflow" >> ~/storingOldIPs.sh

# Generate Dockerfile for PHP 5.6 (Works for mcgmobile, mcgwebsite, mswebsite, ozarkwebsite, pspwebsite, & qpswebsite)

cd ~/

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV PHP56_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "RUN yum -y install epel-release" >> Dockerfile
sudo echo "RUN yum -y update" >> Dockerfile
sudo echo "RUN wget http://rpms.famillecollet.com/enterprise/remi-release-7.rpm" >> Dockerfile
sudo echo "RUN rpm -Uvh remi-release-7*.rpm" >> Dockerfile
sudo echo "RUN yum update / yum upgrade" >> Dockerfile
sudo echo "RUN yum -y --enablerepo=remi,remi-php56 update" >> Dockerfile
sudo echo "RUN yum -y --enablerepo=remi,remi-php56 upgrade" >> Dockerfile
sudo echo "RUN yum -y --enablerepo=remi-php56 install php php-mysql php-mcrypt php-mbstring php-dom php-xml php-common" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/php56/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git-httpd-php56 /var/www/html/DockerFiles/php56

sudo docker run -u root -v /var/www/html/DockerVolumes/mcgmobile:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9895:443 --name mcgmobile --link mariadb:mcgmobile --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56 /sbin/init* 
sudo docker run -u root -v /var/www/html/DockerVolumes/mcgwebsite:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9896:443 --name mcgwebsite --link mariadb:mcgwebsite --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56 /sbin/init* 
sudo docker run -u root -v /var/www/html/DockerVolumes/mswebsite:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9897:443 --name mswebsite --link mariadb:mswebsite --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56 /sbin/init* 
sudo docker run -u root -v /var/www/html/DockerVolumes/ozarkwebsite:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9898:443 --name ozarkwebsite --link mariadb:ozarkwebsite --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56 /sbin/init* 
sudo docker run -u root -v /var/www/html/DockerVolumes/pspwebsite:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9899:443 --name pspwebsite --link mariadb:pspwebsite --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56 /sbin/init* 
sudo docker run -u root -v /var/www/html/DockerVolumes/qpswebsite:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9900:443 --name qpswebsite --link mariadb:qpswebsite --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56 /sbin/init* 

# updatingIP=mcgmobileIP
# updatingOldIP=old_mcgmobileIP
# containerName=mcgmobile

# echo "\${!updatingIP}=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' \${!containerName})" > ~/updatingIPScript
# echo "\${!updatingOldIP}=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' \${!containerName})" >> ~/updatingIPScript
# echo "sudo echo \"echo \\\$\$updatingOldIP=\\\$\$updatingIP\" >> ~/storingOldIPs.sh" >> ~/updatingIPScript

# sh ~/updatingIPScript


# # echo "sudo sed -i 's/updatingOldIP/$updatingOldIP/g' ~/updatingIPScript" >> ~/tmp.sh
# # echo "sudo sed -i 's/updatingIP/$updatingIP/g' ~/updatingIPScript" >> ~/tmp.sh
# # echo "sudo sed -i 's/containerName/$containerName/g' ~/updatingIPScript" >> ~/tmp.sh

# sh tmp.sh
# rm -rf ~/tmp.sh

mcgmobileIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mcgmobile)
old_mcgmobileIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mcgmobile)
sudo echo "old_mcgmobileIP=$mcgmobileIP" >> ~/storingOldIPs.sh

mcgwebsiteIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mcgwebsite)
old_mcgwebsiteIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mcgwebsite)
sudo echo "old_mcgwebsiteIP=$mcgwebsiteIP" >> ~/storingOldIPs.sh

mswebsiteIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mswebsite)
old_mswebsiteIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mswebsite)
sudo echo "old_mswebsiteIP=$mswebsiteIP" >> ~/storingOldIPs.sh

ozarkwebsiteIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' ozarkwebsite)
old_ozarkwebsite=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' ozarkwebsite)
sudo echo "old_ozarkwebsite=$ozarkwebsiteIP" >> ~/storingOldIPs.sh

pspwebsiteIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' pspwebsite)
old_pspwebsiteIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' pspwebsite)
sudo echo "old_pspwebsiteIP=$pspwebsiteIP" >> ~/storingOldIPs.sh

qpswebsiteIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' qpswebsite)
old_qpswebsiteIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' qpswebsite)
sudo echo "old_pspwebsiteIP=$pspwebsiteIP" >> ~/storingOldIPs.sh

sudo echo "sudo docker start mcgmobile" >> ~/.bashrc
sudo echo "sudo docker start mcgwebsite" >> ~/.bashrc
sudo echo "sudo docker start mswebsite" >> ~/.bashrc
sudo echo "sudo docker start ozarkwebsite" >> ~/.bashrc
sudo echo "sudo docker start pspwebsite" >> ~/.bashrc
sudo echo "sudo docker start qpswebsite" >> ~/.bashrc

sudo echo "mcgmobileIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mcgmobile)" >> .bashrc
sudo echo "mcgwebsiteIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mcgwebsite)" >> .bashrc
sudo echo "mswebsiteIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' mswebsite)" >> .bashrc
sudo echo "ozarkwebsiteIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' ozarkwebsite)" >> .bashrc
sudo echo "pspwebsiteIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' pspwebsite)" >> .bashrc
sudo echo "qpswebsiteIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' qpswebsite)" >> .bashrc

sudo echo "sed -i 's/\$old_mcgmobileIP/\$mcgmobileIP/g' ~/storingOldIPs.sh" >> ~/.bashrc
sudo echo "sed -i 's/\$old_mcgwebsiteIP/\$mcgwebsiteIP/g' ~/storingOldIPs.sh" >> ~/.bashrc
sudo echo "sed -i 's/\$old_mswebsiteIP/\$mswebsiteIP/g' ~/storingOldIPs.sh" >> ~/.bashrc
sudo echo "sed -i 's/\$old_ozarkwebsiteIP/\$ozarkwebsiteIP/g' ~/storingOldIPs.sh" >> ~/.bashrc
sudo echo "sed -i 's/\$old_pspwebsiteIP/\$pspwebsiteIP/g' ~/storingOldIPs.sh" >> ~/.bashrc
sudo echo "sed -i 's/\$old_qpswebsiteIP/\$qpswebsiteIP/g' ~/storingOldIPs.sh" >> ~/.bashrc

# sudo docker run --volumes-from ssl --name php56 --privileged=true -h hostname  -d -i mailserviceslc/base-openssh-ssl-wget-httpd-php56 /sbin/init* 

# Generate Dockerfile for Composer

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV COMPOSER_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "RUN cd ~/" >> Dockerfile
sudo echo "RUN curl -k -sS https://getcomposer.org/installer | php" >> Dockerfile
sudo echo "RUN cd /usr/local/bin" >> Dockerfile
sudo echo "RUN yes Y | mv /composer.phar /usr/local/bin/composer" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/composer/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer /var/www/html/DockerFiles/composer

sudo docker run --volumes-from ssl --name composer --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer /sbin/init* 

sudo docker export --output=base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer.tar composer
sudo docker stop composer
sudo docker rm composer
sudo docker rmi mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer
sudo cat base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer.tar | sudo docker import - mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer

sudo rm -rf base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer.tar

# Generate DockerFile for Blaster

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV BLASTER_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "ENV MYSQL_ROOT_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" >> Dockerfile
sudo echo "ENV MYSQL_USER=\"$MYSQL_USER\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE=\"blaster\"" >> Dockerfile
sudo echo "ENV mariadbIP=\"$mariadbIP\"" >> Dockerfile

sudo echo "RUN sed -i  's/\/var\/www\/html/\/var\/www\/html\/blaster-client/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile

sudo echo "RUN cp /etc/httpd/conf/httpd.conf ~/httpd.conf" >> Dockerfile
sudo echo "RUN cd ~/" >> Dockerfile
sudo echo "RUN sed -i 's/\/var\/www\/html/\/var\/www\/html\/blaster-client/g' ~/httpd.conf" >> Dockerfile
sudo echo "RUN sed -i 's/#ServerName www.example.com:80/ServerName $host/g' ~/httpd.conf" >> Dockerfile
sudo echo "RUN yes Y | cp ~/httpd.conf /etc/httpd/conf/httpd.conf " >> Dockerfile

sudo echo "RUN yum -y install python-setuptools" >> Dockerfile
sudo echo "RUN easy_install pip" >> Dockerfile
sudo echo "RUN pip install supervisor" >> Dockerfile
sudo echo "RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/conf.d/" >> Dockerfile
sudo echo "CMD [\"/usr/bin/supervisord\"]" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/blaster/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer-blaster /var/www/html/DockerFiles/blaster

sudo docker run -u root -v /var/www/html/DockerVolumes/blaster:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9905:443 --name blaster --link mariadb:blaster --privileged=true -h hostname -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer-blaster /sbin/init* 

cd ~/

blasterIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' blaster)
old_blasterIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' blaster)
sudo echo "old_blasterIP=$blasterIP" >> ~/storingOldIPs.sh

sudo echo "sed -i 's/localhost/$mariadbIP/g' /var/www/html/DockerVolumes/blaster/blaster-api/app/config/database.php" > ~/.updateBlasterDBConfig
sudo echo "sed -i \"s/DB_DATABASE', 'homestead'/DB_DATABASE', 'blaster'/g\" /var/www/html/DockerVolumes/blaster/blaster-api/app/config/database.php" >> ~/.updateBlasterDBConfig
sudo echo "sed -i \"s/'homestead'/'$MYSQL_USER'/g\" /var/www/html/DockerVolumes/blaster/blaster-api/app/config/database.php" >> ~/.updateBlasterDBConfig
sudo echo "sed -i 's/'secret'/'$MYSQL_ROOT_PASSWORD'/g' /var/www/html/DockerVolumes/blaster/blaster-api/app/config/database.php" >> ~/.updateBlasterDBConfig
sudo sh ~/.updateBlasterDBConfig

sudo echo "sudo docker start blaster" >> ~/.bashrc
sudo echo "blasterIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' blaster)" >> ~/.bashrc
sudo echo "sed -i 's/\$old_blasterIP/\$blasterIP/g' ~/storingOldIPs.sh" >> ~/.bashrc
sudo echo "sed -i 's/$old_mariadbIP/$mariadbIP/g' /var/www/html/DockerVolumes/blaster/blaster-api/app/config/database.php" >> ~/.bashrc
sudo echo "yes Y | cp /var/www/html/DockerFiles/mariadbserver/configureDFDIGUsers.sh ~/configureBlasterUsers.sh" >> ~/.bashrc
sudo echo "yes Y | head -n -3  ~/configureBlasterUsers.sh > temp.sh ; mv temp.sh  ~/configureBlasterUsers.sh" >> ~/.bashrc
sudo echo "sudo echo \"mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \\\"DROP USER \$MYSQL_USER@\$old_blasterIP;\\\"\" >> ~/configureBlasterUsers.sh" >> ~/.bashrc
sudo echo "sudo echo \"mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \\\"CREATE USER '\$MYSQL_USER'@'\$blasterIP' IDENTIFIED BY '\$MYSQL_ROOT_PASSWORD';\\\"\" >> ~/configureBlasterUsers.sh" >> ~/.bashrc
sudo echo "sudo echo \"mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \\\"GRANT ALL PRIVILEGES ON *.* TO '\$MYSQL_USER'@'\$blasterIP' WITH GRANT OPTION;\\\"\" >> ~/configureBlasterUsers.sh" >> ~/.bashrc
sudo echo "yes Y | sudo cp configureBlasterUsers.sh /var/www/html/DockerFiles/mariadbserver/configureBlasterUsers.sh" >> ~/.bashrc
sudo echo "sudo chown -R root:root /var/www/html/DockerFiles/mariadbserver" >> ~/.bashrc
sudo echo "sudo docker exec -it mariadb /bin/bash -c \"ln -s /var/lib/mysql/mysql.sock /tmp/mysql.sock\";" >> ~/.bashrc
sudo echo "yes Y | sudo cp configureBlasterUsers.sh /var/www/html/DockerFiles/mariadbserver/configureBlasterUsers.sh" >> ~/.bashrc
sudo echo "sudo docker exec -it mariadb /bin/bash -c \"sh /home/mariadbconfigs/configureBlasterUsers.sh\";" >> ~/.bashrc

sudo echo -e '#!/bin/bash' > ~/configureBlasterUsers.sh
sudo echo "set e" >> ~/configureBlasterUsers.sh

sudo echo "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"CREATE USER '$MYSQL_USER'@'$blasterIP' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';\"" >> ~/configureBlasterUsers.sh
sudo echo "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'$blasterIP' WITH GRANT OPTION;\"" >> ~/configureBlasterUsers.sh

yes Y | sudo cp ~/configureBlasterUsers.sh /var/www/html/DockerFiles/mariadbserver/configureBlasterUsers.sh
sudo chmod 755 /var/www/html/DockerFiles/mariadbserver/configureBlasterUsers.sh
sudo docker exec -it mariadb /bin/bash -c "sh /home/mariadbconfigs/configureBlasterUsers.sh";
# sudo chmod 755 -R /var/www/html/DockerVolumes/blaster/blaster-api/

sudo docker exec -it blaster /bin/bash -c "cd /var/www/html/blaster-api; git checkout dev;";
sudo docker exec -it blaster /bin/bash -c "cd /var/www/html/blaster-client; git checkout dev;";
sudo docker exec -it blaster /bin/bash -c "cd /var/www/html/blaster-test; git checkout dev;";
sudo docker exec -it blaster /bin/bash -c "cd /var/www/html/blaster-test; composer update;";

sudo docker exec -it blaster /bin/bash -c "cd /var/www/html/blaster-api; composer dump-autoload; composer update; yes Y | php artisan migrate:refresh --seed;";

echo "echo old_blasterIP=$blasterIP" >> ~/storingOldIPs.sh

# Generate DockerFile for dfdig

sudo echo "FROM mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer" > Dockerfile
sudo echo "MAINTAINER Kevin Nabity \"knabity@mailserviceslc.com\"" >> Dockerfile
sudo echo "ENV DFDIG_REFRESHED_AT 2015-09-14" >> Dockerfile
sudo echo "ENV MYSQL_ROOT_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" >> Dockerfile
sudo echo "ENV MYSQL_USER=\"$MYSQL_USER\"" >> Dockerfile
sudo echo "ENV MYSQL_DATABASE=\"dfdig\"" >> Dockerfile
sudo echo "ENV mariadbIP=\"$mariadbIP\"" >> Dockerfile
sudo echo "ENV TERM dumb" >> Dockerfile
sudo echo "RUN export TERM=linux" >> Dockerfile
sudo echo "RUN sed -i  's/\/var\/www\/html/\/var\/www\/html\/docflow-web-api\/public/g' /etc/httpd/conf.d/ssl.conf" >> Dockerfile
sudo echo "RUN cp /etc/httpd/conf/httpd.conf ~/httpd.conf" >> Dockerfile
sudo echo "RUN cd ~/" >> Dockerfile
sudo echo "RUN sed -i 's/\/var\/www\/html/\/var\/www\/html\/docflow-web-api\/public/g' ~/httpd.conf" >> Dockerfile
sudo echo "RUN sed -i 's/#ServerName www.example.com:80/ServerName $host/g' ~/httpd.conf" >> Dockerfile
sudo echo "RUN sed -i 's/DirectoryIndex index.html/DirectoryIndex index.html index.php/g' ~/httpd.conf" >> Dockerfile
sudo echo "RUN sed -i 's/AllowOverride None/AllowOverride All/g' ~/httpd.conf" >> Dockerfile

sudo echo "RUN cd ~/" >> Dockerfile
sudo echo "RUN cp /etc/php.ini ~/php.ini" >> Dockerfile
sudo echo "RUN sed -i 's/mysql.default_socket =/mysql.default_socket = var\/lib\/mysql\/mysql.sock/g' ~/php.ini" >> Dockerfile
sudo echo "RUN yes Y | cp ~/php.ini /etc/php.ini" >> Dockerfile
sudo echo "RUN mkdir -p /var/lib/mysql" >> Dockerfile
sudo echo "RUN echo "" > /var/lib/mysql/mysql.sock" >> Dockerfile

sudo echo "RUN yes Y | cp ~/httpd.conf /etc/httpd/conf/httpd.conf" >> Dockerfile

sudo echo "RUN yum -y update" >> Dockerfile
sudo echo "CMD [\"/usr/bin/supervisord\"]" >> Dockerfile

sudo mv Dockerfile /var/www/html/DockerFiles/dfdig/Dockerfile

sudo docker build --no-cache -t "mailserviceslc"/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer-dfdig /var/www/html/DockerFiles/dfdig

sudo docker run --volumes-from ssl -v /var/www/html/DockerVolumes/dfdig:/var/www/html -p 22 -p 9894:443 --name dfdig --link mariadb:dfdig --privileged=true -h hostname  -d -i mailserviceslc/base-openssh-ssl-mariadbclient-wget-git-httpd-php56-composer-dfdig /sbin/init* 

cd ~/

dfdigIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' dfdig)
old_dfdigIP=$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' dfdig)
sudo echo "old_dfdigIP=$dfdigIP" >> ~/storingOldIPs.sh

sudo sed -i 's/\$this->call(\x27SubmissionTableSeeder\x27)/\/\/ \$this->call(\x27SubmissionTableSeeder\x27)/g' /var/www/html/DockerVolumes/dfdig/docflow-web-api/database/seeds/DatabaseSeeder.php

sudo echo "sed -i 's/localhost/$mariadbIP/g' /var/www/html/DockerVolumes/dfdig/docflow-web-api/config/database.php" > ~/.updateDFDIGDBConfig
sudo echo "sed -i \"s/DB_DATABASE', 'homestead'/DB_DATABASE', 'dfdig'/g\" /var/www/html/DockerVolumes/dfdig/docflow-web-api/config/database.php" >> ~/.updateDFDIGDBConfig
sudo echo "sed -i \"s/DB_USERNAME', 'homestead'/DB_USERNAME', '$MYSQL_USER'/g\" /var/www/html/DockerVolumes/dfdig/docflow-web-api/config/database.php" >> ~/.updateDFDIGDBConfig
sudo echo "sed -i 's/'secret'/'$MYSQL_ROOT_PASSWORD'/g' /var/www/html/DockerVolumes/dfdig/docflow-web-api/config/database.php" >> ~/.updateDFDIGDBConfig
sudo sh ~/.updateDFDIGDBConfig

sudo echo "sudo docker start dfdig" >> ~/.bashrc
sudo echo "dfdigIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' dfdig)" >> ~/.bashrc
sudo echo "sed -i 's/\$old_dfdigIP/\$dfdigIP/g' ~/storingOldIPs.sh" >> ~/.bashrc
sudo echo "sed -i 's/$old_mariadbIP/$mariadbIP/g' /var/www/html/DockerVolumes/dfdig/docflow-web-api/config/database.php" >> ~/.bashrc
sudo echo "sed -i \"s/DB_DATABASE', 'homestead'/DB_DATABASE', 'dfdig'/g\" /var/www/html/DockerVolumes/dfdig/docflow-web-api/config/database.php" >> ~/.bashrc
sudo echo "sed -i \"s/DB_USERNAME', 'homestead'/DB_USERNAME', '$MYSQL_USER'/g\" /var/www/html/DockerVolumes/dfdig/docflow-web-api/config/database.php" >> ~/.bashrc
sudo echo "sed -i 's/'secret'/'$MYSQL_ROOT_PASSWORD'/g' /var/www/html/DockerVolumes/dfdig/docflow-web-api/config/database.php" >> ~/.bashrc
sudo echo "yes Y | cp /var/www/html/DockerFiles/mariadbserver/configureDFDIGUsers.sh ~/configureDFDIGUsers.sh" >> ~/.bashrc
sudo echo "yes Y | head -n -3  ~/configureDFDIGUsers.sh > temp.sh ; mv temp.sh  ~/configureDFDIGUsers.sh" >> ~/.bashrc
sudo echo "sudo echo \"mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \\\"DROP USER \$MYSQL_USER@\$old_dfdigIP;\\\"\" >> ~/configureDFDIGUsers.sh" >> ~/.bashrc
sudo echo "sudo echo \"mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \\\"CREATE USER '\$MYSQL_USER'@'\$dfdigIP' IDENTIFIED BY '\$MYSQL_ROOT_PASSWORD';\\\"\" >> ~/configureDFDIGUsers.sh" >> ~/.bashrc
sudo echo "sudo echo \"mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \\\"GRANT ALL PRIVILEGES ON *.* TO '\$MYSQL_USER'@'\$dfdigIP' WITH GRANT OPTION;\\\"\" >> ~/configureDFDIGUsers.sh" >> ~/.bashrc
sudo echo "yes Y | sudo cp configureDFDIGUsers.sh /var/www/html/DockerFiles/mariadbserver/configureDFDIGUsers.sh" >> ~/.bashrc
sudo echo "sudo docker exec -it dfdig /bin/bash -c \"sed -i 's/$old_mariadbIP/$mariadbIP/g' /var/www/html/v2/management/etc/dbconfig_dev\";" >> ~/.bashrc
sudo echo "sudo chown -R root:root /var/www/html/DockerFiles/mariadbserver" >> ~/.bashrc
sudo echo "sudo docker exec -it mariadb /bin/bash -c \"ln -s /var/lib/mysql/mysql.sock /tmp/mysql.sock\";" >> ~/.bashrc
sudo echo "yes Y | sudo cp configureDFDIGUsers.sh /var/www/html/DockerFiles/mariadbserver/configureDFDIGUsers.sh" >> ~/.bashrc
sudo echo "sudo docker exec -it mariadb /bin/bash -c \"sh /home/mariadbconfigs/configureDFDIGUsers.sh\";" >> ~/.bashrc

sudo echo -e '#!/bin/bash' > ~/configureDFDIGUsers.sh
sudo echo "set e" >> ~/configureDFDIGUsers.sh

sudo echo "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"CREATE USER '$MYSQL_USER'@'$dfdigIP' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';\"" >> ~/configureDFDIGUsers.sh
sudo echo "mysql --user=root --password=\$MYSQL_ROOT_PASSWORD -e \"GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'$dfdigIP' WITH GRANT OPTION;\"" >> ~/configureDFDIGUsers.sh

yes Y | sudo cp ~/configureDFDIGUsers.sh /var/www/html/DockerFiles/mariadbserver/configureDFDIGUsers.sh
sudo chmod 755 /var/www/html/DockerFiles/mariadbserver/configuredFDIGUsers.sh
sudo docker exec -it mariadb /bin/bash -c "sh /home/mariadbconfigs/configureDFDIGUsers.sh";
sudo chmod 755 -R /var/www/html/DockerVolumes/dfdig/docflow-web-api/storage/logs

sudo docker exec -it dfdig /bin/bash -c "cd /var/www/html/docflow-web-api; composer dump-autoload; composer update; yes Y | php artisan migrate:refresh --seed";

systemctl restart httpd.service

sudo docker build --no-cache -t "nevada"/supervisord /var/www/html/DockerFiles/nevada
sudo docker build --no-cache -t "voltron"/supervisord /var/www/html/DockerFiles/voltron
sudo docker build --no-cache -t "rpebppLaravel"/supervisord /var/www/html/DockerFiles/rpebppLaravel

# sudo docker run -u root -v /etc/httpd/conf.d/:/etc/httpd/conf.d/ -v /etc/pki/tls/certs:/etc/pki/tls/certs -v /var/www/html/DockerVolumes/rpebpp:/var/www/html -w /var/www/html -p 22 -p 9904:443 --name rpebpp --link mariadb:mariadb --privileged=true -h hostname -d -i rpebpp/supervisord /sbin/init* 

# sudo docker run -u root -v /var/www/html/DockerVolumes/mariadb:/var/www/html -w /var/www/html -p 22 -p 9891:443 --name mariadb --privileged=true -h hostname  -d -i ssl/supervisord /sbin/init* 

sudo docker run -u root -v /var/www/html/DockerVolumes/docflow:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9893:443 --name docflow --link mariadb:docflow --privileged=true -h hostname  -d -i docflow/supervisord /sbin/init* 
sudo docker run -u root -v /var/www/html/DockerVolumes/nevada:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9901:443 --name nevada --link mariadb:nevada --privileged=true -h hostname -d -i standard/supervisord /sbin/init* 
sudo docker run -u root -v /var/www/html/DockerVolumes/voltron:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -p 22 -p 9902:443 --name voltron --link mariadb:voltron --privileged=true -h hostname -d -i standard/supervisord /sbin/init* 
sudo docker run -u root -v /var/www/html/DockerVolumes/rpebppLaravel:/var/www/html --volumes-from ssl -v /usr/sbin/httpd/:/usr/sbin/httpd/ -v /etc/pki/:/etc/pki/ -w /var/www/html -p 22 -p 9903:443 --name rpebppLaravel --link mariadb:rpebppLaravel --privileged=true -h hostname -d -i standard/supervisord /sbin/init* 

# sudo docker run -u root -v /var/www/html/DockerVolumes/rpebpp:/var/www/html -w /var/www/html -p 22 -p 9904:443 --name rpebpp --link mariadb:mariadb --privileged=true -h hostname  -d --tlsverify --tlscacert=/etc/pki/tls/certs/ca.crt --tlscert=/etc/pki/tls/certs/ca.crt --tlskey=/etc/pki/tls/private/ca.key -H=0.0.0.0:2376 -i rpebpp/supervisord /sbin/init* 

sudo docker exec -it database /bin/bash; systemctl restart httpd.service;
sudo docker exec -it mariadb /bin/bash;
sudo docker exec -it blaster /bin/bash; systemctl restart httpd.service;
sudo docker exec -it docflow /bin/bash; systemctl restart httpd.service;
sudo docker exec -it dfdig /bin/bash; systemctl restart httpd.service;
sudo docker exec -it mcgmobile /bin/bash; systemctl restart httpd.service;
sudo docker exec -it mcgwebsite /bin/bash; systemctl restart httpd.service;
sudo docker exec -it mswebsite /bin/bash; systemctl restart httpd.service;
sudo docker exec -it ozarkwebsite /bin/bash; systemctl restart httpd.service;
sudo docker exec -it pspwebsite /bin/bash; systemctl restart httpd.service;
sudo docker exec -it qpswebsite /bin/bash; systemctl restart httpd.service;
sudo docker exec -it nevada /bin/bash; systemctl restart httpd.service;
sudo docker exec -it voltron /bin/bash; systemctl restart httpd.service;
sudo docker exec -it rpebppLaravel /bin/bash; systemctl restart httpd.service;
sudo docker exec -it rpebpp /bin/bash; systemctl restart httpd.service;

# Configure Blaster

# Configure httpd.conf



# Set Up MySQL

#(default password is nothing so two single quotes)
mysqladmin --user=root --password='' password 'secret'
mysqladmin --user=vagrant --password='' password 'secret'

cd ~/

echo "CREATE USER 'homestead'@'localhost' IDENTIFIED BY 'secret';" > addHomestead.sql
echo "GRANT ALL PRIVILEGES ON * . * TO 'homestead'@'localhost';" >> addHomestead.sql
echo "FLUSH PRIVILEGES;" >> addHomestead.sql
echo "CREATE DATABASE homestead;" >> addHomestead.sql

mysql < ~/addHomestead.sql --user=root --password=secret

rm -rf addHomestead.sql

chown -R apache:apache /var/www/html/






















# Configure Nevada

systemctl restart httpd.service 

# Configure SSL

sed -i  's/\/var\/www\/html/\/var\/www\/html\/nevada_ebpp_web_tools\/public/g' /etc/httpd/conf.d/ssl.conf

update-ca-trust extract

systemctl restart httpd.service

# Configure httpd.conf

cp /etc/httpd/conf/httpd.conf ~/httpd.conf
cd ~/
sed -i 's/\/var\/www\/html/\/var\/www\/html\/nevada_ebpp_web_tools\/public/g' httpd.conf
echo "sudo sed -i 's/#ServerName www.example.com:80/ServerName $host/g' httpd.conf" > ~/httpdSHCommands.sh
sudo sh ~/httpdSHCommands.sh
sudo rm -rf ~/httpdSHCommands.sh
yes Y | cp ~/httpd.conf /etc/httpd/conf/httpd.conf 



sudo echo "sudo docker start nevada" >> ~/.bashrc
sudo echo "nevadaIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' nevada)" >> .bashrc
sudo echo "sed -i 's/\$old_nevadaIP/\$current_nevadaIP/g' ~/.bashrc" >> ~/.bashrc
sudo echo "sed -i 's/\$current_nevadaIP/\$nevadaIP/g' ~/.bashrc" >> ~/.bashrc
sudo echo "current_nevadaIP=\$nevadaIP" >> ~/.bashrc

echo "echo old_nevadawebsiteIP=$nevadawebsiteIP" >> ~/storingOldIPs.sh








# Configure Docflow

docker exec -it docflow /bin/bash

# yes Y | cp /var/www/html/ServerConfigs/httpdBlaster.conf /etc/httpd/conf/httpd.conf

# Configure PHP

yum install -y centos-release-SCL
yum install -y php php-pdo php-mysqli php-mcrypt php-cli
# yes Y | cp /var/www/html/ServerConfigs/php.ini /etc/php.ini

useradd -u 9500 -md /home/docflow docflow

yum install -y tar
curl -o /tmp/openafs.tar.gz 'http://dl.openafs.org/dl/openafs/openafs/openafs/openafs/1.7.32/openafs-1.7.32-src.tar.gz'
mkdir -p /tmp/openafs
mv /tmp/openafs.tar.gz /tmp/openafs/openafs.tar.gz
cd /tmp/openafs/
tar xvf /tmp/openafs/openafs.tar.gz

rpm -ivh http://openafs.org/dl/openafs/1.6.9/openafs-release-rhel-1.6.9-1.noarch.rpm
rpm -ivh http://openafs.org/dl/openafs/1.6.12/openafs-1.6.12-1.src.rpm

rpm -ivh http://www.openafs.org/dl/openafs/1.6.1/rhel6/x86_64/kmod-openafs-1.6.1-1.2.6.32_279.el6.x86_64.rpm

rpm -ivh http://www.openafs.org/dl/openafs/1.6.1/rhel6/x86_64/kmod-openafs-1.6.1-1.2.6.32_220.13.1.el6.centos.plus.x86_64.rpm

yum install -y openafs.x86_64 openafs-devel.x86_64 openafs-authlibs.x86_64 openafs-release-rhel.noarch kmod-openafs.x86_64 openafs-client.x86_64 openafs-krb5.x86_64 openafs-kernel-source.x86_64
yum install -y openafs.x86_64 openafs-devel.x86_64 openafs-authlibs.x86_64 openafs-release-rhel.noarch kmod-openafs.x86_64 openafs-client.x86_64 openafs-krb5.x86_64 openafs-kernel-source.x86_64 --skip-broken

wget http://dl.openafs.org/dl/openafs/1.4.10/openafs-repository-1.4.10-1.noarch.rpm
sudo rpm -U openafs-repository-1.4.10-1.noarch.rpm
yum install -y openafs-client


mkdir -p /usr/vice/etc
echo "mailserviceslc.com #Mail Services" > /usr/vice/etc/CellServDB.local
echo "10.2.2.92 #dyerseve.mailserviceslc.com" >> /usr/vice/etc/CellServDB.local
echo "10.2.2.90 #battery.mailserviceslc.com" >> /usr/vice/etc/CellServDB.local

cat /usr/vice/etc/CellServDB.local /usr/vice/etc/CellServDB.dist > /usr/vice/etc/CellServDB
echo "mailserviceslc.com" > /usr/vice/etc/ThisCell

 /sbin/service openafs-client start

# Install composer

cd /usr/local/bin
curl -sS https://getcomposer.org/installer | php
mv composer.phar composer
cd /var/www/html/blaster-api
composer.phar update

# Set Up MySQL

#(default password is nothing so two single quotes)
mysqladmin --user=root --password='' password 'secret'
mysql --user=root --password='secret' -e "create database blaster"
# mysql rpweb_dev < /var/www/html/v2/Tables/EntireDatabase.sql --user=root --password=secret

cd /var/www/html/blaster-api
git checkout dev
cd /var/www/html/blaster-client
git checkout dev
cd /var/www/html/blaster-ops
git checkout dev
cd /var/www/html/blaster-test
git checkout dev
composer update


# Configure Dockerfile for voltron

sudo echo "sudo docker start voltron" >> ~/.bashrc
sudo echo "voltronIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' voltron)" >> .bashrc
echo "echo old_voltronIP=$voltronIP" >> ~/storingOldIPs.sh

# Configure Dockerfile for rpebppLaravel
sudo echo "sudo docker start rpebppLaravel" >> ~/.bashrc
sudo echo "rpebppLaravelIP=\$(sudo docker inspect -f '{{ .NetworkSettings.IPAddress }}' rpebppLaravel)" >> .bashrc
sudo echo "sed -i 's/\$old_rpebppLaravelIP/\$current_rpebppLaravelIP/g' ~/.bashrc" >> ~/.bashrc
sudo echo "sed -i 's/\$current_rpebppLaravelIP/\$nevadaIP/g' ~/.bashrc" >> ~/.bashrc
sudo echo "current_rpebppLaravelIP=\$rpebppLaravelIP" >> ~/.bashrc
echo "echo old_rpebppLaravelIP=$rpebppLaravelIP" >> ~/storingOldIPs.sh


