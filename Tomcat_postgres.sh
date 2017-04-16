#!/bin/bash -e

#
# Maintainer Suraj Nair
#

echo -e "

This is an CentOS 7 based installation script for Apache Tomcat 9-M18 version + POSTGRESQL 9.2 (as found in the epel repo while writing...subject to change) + PGadmin 5.1-2 (also subject to change)

OpenJDK Version 1.8.0_121

Try to run this on a fresh installation for better results and to avoid any unexpected outputs...\n
"

#
# Installation of Java
#

LOGFILE=/root/installlog.txt

IP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')

checkerror() {

RESULT=$1

if [ $RESULT != 0 ];then
echo -e "Errors occured during installation. Check $LOGFILE for more details\n"
exit 127
fi
}

#
# Check root permissions
#

if [ $(id -u) -ne 0 ];then
echo -e "Requires to be root in order to run this script\n"
exit 127
fi

#Updating repo..

#TOMCATPASSWORD=
#while [[ $TOMCATPASSWORD = "" ]]; do
#   read -p "Please insert the new Tomcat Password for root: " TOMCATPASSWORD
#done

#checkerror $?

TOMCATGUIADMINPWD=
while [[ $TOMCATGUIADMINPWD = "" ]]; do
   read -p "Please insert the new Tomcat GUI Admin Password for root: " TOMCATGUIADMINPWD
done

POSTGRESPWD=
while [[ $POSTGRESPWD = "" ]]; do
   read -p "Please insert the new POSTGRES User Password for root: " POSTGRESPWD
done

checkerror $?

echo -e "Performing OS Update..\n"

sudo yum -y update >> $LOGFILE 2>&1

checkerror $?

#
# Installing Java dependencies and EPEL repos
#

echo -e "Installing Java Dependencies as required...\n"

yum -y install java-1.8.0 epel-release >> $LOGFILE 2>&1

checkerror $?

echo -e "Downloading and extracting Apache Tomcat 9-M18 version now..\n"

mkdir /opt/tomcat

wget http://www-eu.apache.org/dist/tomcat/tomcat-9/v9.0.0.M18/bin/apache-tomcat-9.0.0.M18.tar.gz >> $LOGFILE 2>&1

tar -zxpvf apache-tomcat-9.0.0.M18.tar.gz -C /opt/tomcat --strip-components=1 >> $LOGFILE 2>&1

cd /opt/tomcat

echo -e "Adding required users and setting permissions\n"

groupadd tomcat

useradd -s /bin/nologin -g tomcat -d /opt/tomcat tomcat >> $LOGFILE 2>&1

chgrp -R tomcat conf

chmod g+rwx conf

chmod g+r conf/*

chown -R tomcat logs/ temp/ webapps/ work/

chgrp -R tomcat bin

chgrp -R tomcat lib

chmod g+rwx bin

chmod g+r bin/*

cd - >> $LOGFILE 2>&1

#
#Adding Systemd unit file for Apache tomcat
#

echo -e "Adding Systemd unit file for Apache tomcat..\n"

rm -f /etc/systemd/system/tomcat.service >> $LOGFILE 2>&1

touch /etc/systemd/system/tomcat.service

echo "[Unit] 
Description=Apache Tomcat Web Application Container 
After=syslog.target network.target 
 
[Service] 
Type=forking 

Environment=JAVA_HOME=/usr/lib/jvm/jre 
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid 
Environment=CATALINA_HOME=/opt/tomcat 
Environment=CATALINA_BASE=/opt/tomcat 
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC' 
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom' 
 
ExecStart=/opt/tomcat/bin/startup.sh 
ExecStop=/bin/kill -15 $MAINPID 
 
User=tomcat 
Group=tomcat 
UMask=0007 
RestartSec=10 
Restart=always 
 
[Install] 
WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/tomcat.service >> $LOGFILE 2>&1

checkerror $?

#
# Adding tomcat admin user from the users's input for admin password
#

echo -e "Adding tomcat user admin credentials conf file..\n"

rm -f /opt/tomcat/conf/tomcat-users.xml >> $LOGFILE 2>&1

cat <<EOF > /opt/tomcat/conf/tomcat-users.xml
<tomcat-users>
<!--
  <role rolename="tomcat"/>
  <role rolename="role1"/>
  <user username="tomcat" password="tomcat" roles="tomcat"/>
  <user username="both" password="tomcat" roles="tomcat,role1"/>
  <user username="role1" password="tomcat" roles="role1"/>
-->

<!-- user manager can access only manager section -->
<role rolename="manager-gui" />
<user username="manager" password="$TOMCATGUIADMINPWD" roles="manager-gui" />

<!-- user admin can access manager and admin section both -->
<role rolename="admin-gui" />
<user username="admin" password="$TOMCATGUIADMINPWD" roles="manager-gui,admin-gui" />
</tomcat-users>
EOF

checkerror $?

chgrp tomcat /opt/tomcat/conf/tomcat-users.xml

rm -f /opt/tomcat/webapps/manager/META-INF/context.xml

cat <<EOF > /opt/tomcat/webapps/manager/META-INF/context.xml

<Context antiResourceLocking="false" privileged="true" >
    <!--<Valve className=\"org.apache.catalina.valves.RemoteAddrValve\"
         allow=\"127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1\" /> -->

</Context>
EOF

chown tomcat /opt/tomcat/webapps/manager/META-INF/context.xml

systemctl daemon-reload

systemctl start tomcat.service

checkerror $?

systemctl enable tomcat.service

echo -e "Done installing Tomcat... Working on Postgres installation now...\n"

#
# Installing and configuring POSTGRES 9.2 and PHPPGAdmin
#

yum install -y postgresql-server postgresq-contrib >> $LOGFILE 2>&1

checkerror $?

postgresql-setup initdb >> $LOGFILE 2>&1

checkerror $?

systemctl start postgresql

checkerror $?	


sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$POSTGRESPWD';" >> $LOGFILE 2>&1


sed -i 's/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf

echo "listen_addresses = '*'" >> /var/lib/pgsql/data/postgresql.conf

echo "port = 5432" >> /var/lib/pgsql/data/postgresql.conf

echo -e "Restarting Postgres...\n"

systemctl restart postgresql >> $LOGFILE 2>&1

checkerror $?

echo -e "Installing phpPgAdmin now...\n"

yum install phpPgAdmin httpd -y >> $LOGFILE 2>&1

checkerror $?

rm -f /etc/httpd/conf.d/phpPgAdmin.conf

echo "

Alias /phpPgAdmin /usr/share/phpPgAdmin

<Location /phpPgAdmin>
    <IfModule mod_authz_core.c>
        # Apache 2.4
        Require all granted
        #Require host example.com
    </IfModule>
    <IfModule !mod_authz_core.c>
        # Apache 2.2
        Order deny,allow
        Allow from all
        # Allow from .example.com
    </IfModule>
</Location>" | tee -a /etc/httpd/conf.d/phpPgAdmin.conf >> $LOGFILE 2>&1

systemctl start httpd

checkerror $?

sed -i "18s/.*/\t\$conf[\'servers\'][0][\'host\'] = \'localhost\';/g" /etc/phpPgAdmin/config.inc.php

sed -i "93s/.*/\t\$conf['extra_login_security'] = false;/g" /etc/phpPgAdmin/config.inc.php

sed -i "99s/.*/\t\$conf['owned_only'] = true;/g" /etc/phpPgAdmin/config.inc.php

echo -e "Restarting Postgres and Apache to complete...\n"

systemctl restart postgresql

checkerror $?

systemctl enable postgresql

systemctl restart httpd

checkerror $?

systemctl enable httpd


echo -e "***************************************************\n

Installation succeeded....

Following are the Login credentials and URL's to follow:

Tomcat Manager app URL: http://$IP:8080/manager/html
Username: admin
Password: $TOMCATGUIADMINPWD


phpPgAdmin URL: http:/$IP/phpPgAdmin
Username: postgres
password: $POSTGRESPWD

You can login to above as postgres user and create any required Roles and Databases therein....

" 
