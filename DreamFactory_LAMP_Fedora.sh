#!/bin/bash
#LAMP installation
#Colors schemes for echo:
RD='\033[0;31m' #Red
GN='\033[0;32m' #Green
MG='\033[0;95m' #Magenta
NC='\033[0m' # No Color

CURRENT_OS=$(cat /etc/os-release | grep VERSION_ID | cut -d "=" -f 2 | cut -c 1-2)

#CHECK FOR --oracle 
case "$1" in
        --oracle) ORACLE=TRUE
	       	  DRIVERS_PATH=$2 ;;
esac


#dev mode:
#set -x

clear

#Check who run script. If not root or without sudo, exit.
if (( $EUID  != 0 ));
then
   echo -e "${RD}\nPlease run script with root privileges: su -mc \"bash $0\" \n${NC}"
   exit 1
fi

#Checking user from who was started script.
CURRENT_USER=$(logname)

if [[ -z $SUDO_USER ]] && [[ -z $CURRENT_USER ]]
then
        echo -e "${RD} \n"
        read -p "Enter username for installation DreamFactory:" CURRENT_USER
        echo -e "${NC} \n"
fi

if [[ ! -z $SUDO_USER ]]
then
        CURRENT_USER=${SUDO_USER}
fi

echo -e "${GN}Step 1: Installing prerequisites applications...\n${NC}"
dnf -q install -y git \
	curl \
	zip \
	unzip \
	ca-certificates \
	lsof \
	libmcrypt-devel \
	readline-devel \
	libzip-devel
#Checking status of installation
if (( $? >= 1 ))
then
	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	exit 1
fi

echo -e "${GN}The prerequisites applications installed.\n${NC}"

echo -e "${GN}Step 2: Installing PHP...\n${NC}"

# Install the php repository
if  (( $CURRENT_OS == 27 ))
then
        dnf -q install -y  http://rpms.remirepo.net/fedora/remi-release-27.rpm
        dnf config-manager --set-enabled remi-php72
elif (( ! $CURRENT_OS == 28 ))
then
	echo -e "${RD} The script support only Fedora 27/28 versions. Exit.\n ${NC}"
        exit 1
fi

#Install PHP
if (( $CURRENT_OS == 27 ))
then
	dnf -q --enablerepo=remi-php72 install -y php-common \
        php-xml \
        php-cli \
        php-curl \
        php-json \
        php-mysqlnd \
        php-sqlite3 \
        php-soap \
        php-mbstring \
        php-bcmath \
        php-devel 
else 
	dnf -q install -y php-common \
        php-xml \
        php-cli \
        php-curl \
        php-json \
        php-mysqlnd \
        php-sqlite3 \
        php-soap \
        php-mbstring \
        php-bcmath \
        php-devel 
        	
fi
if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi

echo -e "${GN}PHP installed.\n${NC}"

echo -e "${GN}Step 3: Configure PHP Extensions...\n${NC}"

dnf -q install -y php-pear
if (( $? >= 1 ))
then
	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi

pecl channel-update pecl.php.net

### ZIP
php -m | grep zip > /dev/null 2>&1
if (( $? >= 1 ))
then
        pecl -q install zip
        if (( $? >= 1 ))
        then
                echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                exit 1
        fi
        echo "extension=zip.so" > /etc/php.d/20-zip.ini
        php -m | grep "zip" > /dev/null 2>&1
        if (( $? >= 1 ))
        then
                echo -e  "${RD}\nExtension Zip have errors...${NC}"
        fi
fi

### MCRYPT
php -m | grep mcrypt > /dev/null 2>&1
if (( $? >= 1 ))
then
	printf "\n" | pecl -q install mcrypt-1.0.1
	if (( $? >= 1 ))
	then
	       	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	       	exit 1
	fi
	echo "extension=mcrypt.so" > /etc/php.d/20-mcrypt.ini
	php -m | grep "mcrypt" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nExtension Mcrypt have errors...${NC}"
	fi
fi

### DRIVERS FOR MONGODB
php -m | grep -E "^mongodb" > /dev/null 2>&1
if (( $? >= 1 ))
then
	pecl -q install mongodb
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        exit 1
	fi
	echo "extension=mongodb.so" > /etc/php.d/20-mongodb.ini
	php -m | grep -E  "^mongodb" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nExtension for MongoDB have errors...${NC}"
	fi
fi

### DRIVERS FOR MSSQL (sqlsrv)
php -m | grep -E "^sqlsrv" > /dev/null 2>&1
if (( $? >= 1 ))
then
	if (( $CURRENT_OS == 28 ))
	then
		curl https://packages.microsoft.com/config/rhel/7/prod.repo > /etc/yum.repos.d/mssql-release.repo
	else	
		curl https://packages.microsoft.com/config/rhel/6/prod.repo > /etc/yum.repos.d/mssql-release.repo
	fi
	ACCEPT_EULA=Y yum -q install -y msodbcsql17 mssql-tools unixODBC-devel
	if (( $? >= 1 ))
	then
                echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                exit 1
        fi

	pecl -q install sqlsrv
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        exit 1
	fi
	echo "extension=sqlsrv.so" > /etc/php.d/20-sqlsrv.ini
	php -m | grep -E  "^sqlsrv" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nExtension for MsSQL DB have errors...${NC}"
	fi
fi	


### DRIVERS FOR MSSQL (pdo_sqlsrv)
php -m | grep -E "^pdo_sqlsrv" > /dev/null 2>&1
if (( $? >= 1 ))
then
	pecl -q install pdo_sqlsrv
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        exit 1
	fi
	echo "extension=pdo_sqlsrv.so" > /etc/php.d/20-pdo_sqlsrv.ini
	php -m | grep -E  "^pdo_sqlsrv" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
		echo -e  "${RD}\nExtension for MsSQL DB have errors...${NC}"
	fi
fi

### DRIVERS FOR ORACLE ( ONLY WITH KEY --oracle )
php -m | grep oci8 > /dev/null 2>&1
if (( $? >= 1 ))
then
	if [[ $ORACLE == TRUE ]]
	then
		dnf -q install -y libaio systemtap-sdt-devel
		echo -e "${MG}"
		if [[ -z $DRIVERS_PATH ]]
		then
			DRIVERS_PATH="."
		fi
		echo -e "${NC}"
		yum -q install -y oracle-instantclient18.3-*-18.3.0.0.0-1.x86_64.rpm
		if (( $? >= 1 ))
	        then
                        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                        exit 1
                fi
		echo "/usr/lib/oracle/18.3/client64/lib" > /etc/ld.so.conf.d/oracle-instantclient.conf
	        ldconfig
		export PHP_DTRACE=yes
	        printf "\n" | pecl -q install oci8
	        if (( $? >= 1 ))
		then
	        	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        	exit 1
		fi
		echo "extension=oci8.so" > /etc/php.d/20-oci8.ini
		ln -s /usr/lib64/libnsl.so.2.0.0 /usr/lib64/libnsl.so.1	
		php -m | grep oci8 > /dev/null 2>&1
		if (( $? >= 1 ))
	        then
	                echo -e  "${RD}\nExtension for OracleDB have errors...${NC}"
	        fi
		
	fi
fi
echo -e "${GN}PHP Extensions configured.\n${NC}"

echo -e "${GN}Step 4: Installing Apache...\n${NC}"

# Check Apache2 installation in the system
ps aux | grep -v grep | grep httpd > /dev/null 2>&1
CHECK_WEB_PROCESS=`echo $?`

yum list installed | grep -E "^httpd.x86_64" > /dev/null 2>&1
CHECK_WEB_INSTALLATION=`echo $?`

if (( $CHECK_WEB_PROCESS == 0 )) || (( $CHECK_WEB_INSTALLATION == 0 ))
then
	echo -e  "${RD}Apache detected in the system. Skipping installation Apache. Configure Apache manualy.\n${NC}"
else
        #Install apache
        #Cheking running web server
        lsof -i :80 | grep LISTEN > /dev/null 2>&1
        if (( $? == 0 ))
        then
               	echo -e  "${RD}Some web server already running on http port.\n ${NC}"
               	echo -e  "${RD}Skipping installation Apache. Install Apache manualy.\n ${NC}"
        else
        	dnf -q install -y httpd php
        	if (( $? >= 1 ))
            	  then
                	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                	exit 1
        	fi
        
        # Create  Apache site entry
        	WEB_PATH=/etc/httpd/conf.d/dreamfactory.conf
                echo '<VirtualHost *:80>' > $WEB_PATH
                echo 'DocumentRoot /opt/dreamfactory/public' >> $WEB_PATH
                echo '<Directory /opt/dreamfactory/public>' >> $WEB_PATH
                echo 'AddOutputFilterByType DEFLATE text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript' >> $WEB_PATH
                echo 'Options -Indexes +FollowSymLinks -MultiViews' >> $WEB_PATH
                echo 'AllowOverride All' >> $WEB_PATH
                echo 'AllowOverride None' >> $WEB_PATH
                echo 'Require all granted' >> $WEB_PATH
                echo 'RewriteEngine on' >> $WEB_PATH
                echo 'RewriteBase /' >> $WEB_PATH
                echo 'RewriteCond %{REQUEST_FILENAME} !-f' >> $WEB_PATH
                echo 'RewriteCond %{REQUEST_FILENAME} !-d' >> $WEB_PATH
                echo 'RewriteRule ^.*$ /index.php [L]' >> $WEB_PATH
                echo '<LimitExcept GET HEAD PUT DELETE PATCH POST>' >> $WEB_PATH
                echo 'Allow from all' >> $WEB_PATH
                echo '</LimitExcept>' >> $WEB_PATH
                echo '</Directory>' >> $WEB_PATH
                echo '</VirtualHost>' >> $WEB_PATH
	
		service httpd restart
		systemctl enable httpd.service 

		firewall-cmd --add-service=http

        	echo -e "${GN}Apache installed.\n${NC}"
        fi
fi

echo -e "${GN}Step 5: Installing Composer...\n${NC}"

curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php

php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi
echo -e "${GN}Composer installed.\n${NC}"

echo -e "${GN}Step 6: Installing DB for DreamFactory...\n${NC}"

yum list installed | grep -E "mariadb-server.x86_64" > /dev/null 2>&1
CHECK_MYSQL_INSTALLATION=$(echo $?)

ps aux | grep -v grep | grep mysql > /dev/null 2>&1
CHECK_MYSQL_PROCESS=$(echo $?)

lsof -i :3306 | grep LISTEN > /dev/null 2>&1
CHECK_MYSQL_PORT=$(echo $?)

if (( $CHECK_MYSQL_PROCESS == 0 )) || (( $CHECK_MYSQL_INSTALLATION == 0 )) || (( $CHECK_MYSQL_PORT == 0 ))
then
	echo -e  "${RD}MySQL DB detected in the system. Skipping installation. \n${NC}"
	DB_FOUND=TRUE
else
        dnf -q install -y mariadb-server
        if (( $? >= 1 ))
        then
                echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                exit 1
        fi

	service mariadb start

	DB_PASS=$(date +%s | sha256sum | base64 | head -c 8)
	mysqladmin -u root -h localhost password ${DB_PASS}

fi

if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while starting service...Exit ${NC}"
        exit 1
fi

echo -e "${GN}DB for DreamFactory installed.\n${NC}"

echo -e "${GN}Step 6: Configure installed Database...\n${NC}"

DB_INSTALLED=FALSE

if [[ $DB_FOUND == TRUE ]]
then
	echo -e "${MG}"
	read -p 'Database for DreamFactory configured already? [Yy/Nn] ' DB_ANSWER
        echo -e "${NC}"
	if [[ -z $DB_ANSWER ]]
	then
        	DB_ANSWER=N	
	fi
	if [[ $DB_ANSWER =~ ^[Yy]$ ]]
	then
		DB_INSTALLED=TRUE
	fi
fi
if [[ $DB_INSTALLED == FALSE ]]
then
	
	# Test access to DB
	mysql -h localhost -u root -p$DB_PASS -e"quit" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
		echo "${RD}Connection to Database failed. Exit  \n${NC}"
		exit 1
	fi
	
	echo "CREATE DATABASE dreamfactory;" | mysql -u root -p${DB_PASS} > /dev/null 2>&1
	
	#Generate password for user in DB
	DB_ADMIN_PASS=\'$(date +%s | sha256sum | base64 | head -c 8)\'
	echo "GRANT ALL PRIVILEGES ON dreamfactory.* to 'dfadmin'@'localhost' IDENTIFIED BY ${DB_ADMIN_PASS};" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1
	echo "FLUSH PRIVILEGES;" | mysql -u root -p${DB_PASS}  > /dev/null 2>&1
	
	echo -e "${GN}DB configuration finished.\n${NC}"
else
	echo -e "${GN}Skipping...\n${NC}"
fi
		
echo -e "${GN}Step 7: Installing DreamFactory...\n ${NC}"

ls -d /opt/dreamfactory > /dev/null 2>&1
if (( $? >= 1 ))
then
	mkdir -p /opt/dreamfactory
	git clone https://github.com/dreamfactorysoftware/dreamfactory.git /opt/dreamfactory
	if (( $? >= 1 ))
	then
        	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        	exit 1
	fi
	DF_CLEAN_INSTALLATION=TRUE
else
	echo -e  "${RD}Folder with DreamFactory detected. Skipping installation DreamFactory...\n${NC}"
	DF_CLEAN_INSTALLATION=FALSE
fi

echo -e "${MG}"
read -p 'Do you have license? [Yy/Nn] ' ANSWER  
echo -e "${NC}"
if [[ -z $ANSWER ]]
then
	ANSWER=N
fi
if [[ $ANSWER =~ ^[Yy]$ ]]
then
	echo -e "${MG}"
	read -p "Enter paht to license files: [./] " LICENSE_PATH 
       	if [[ -z $LICENSE_PATH ]]
	then
		LICENSE_PATH="."
	fi
	echo -e "${NC}"
	cp $LICENSE_PATH/composer.{json,lock} /opt/dreamfactory/
	if (( $? >= 1 ))
        then
                echo -e  "${RD}\nLicenses not found. Skipping.\n${NC}"
        else
		echo -e "\n${GN}Licenses installed. ${NC}\n"
		LICENSE_INSTALLED=TRUE
	fi
else
	echo -e  "${RD}Installing OSS version of the DreamFactory...\n${NC}"
fi
chown -R $CURRENT_USER /opt/dreamfactory && cd /opt/dreamfactory 

sudo -u $CURRENT_USER bash -c "/usr/local/bin/composer -q install --no-dev --ignore-platform-reqs"
if [[ $DB_INSTALLED == FALSE ]] 
then
        sudo -u  $CURRENT_USER bash -c "php -q artisan df:env \
                --db_connection=mysql \
                --db_host=127.0.0.1 \
                --db_port=3306 \
                --db_database=dreamfactory \
                --db_username=dfadmin \
                --db_password=$(echo $DB_ADMIN_PASS | sed 's/['\'']//g')"	
	sed -i 's/\#\#DB\_CHARSET\=utf8/DB\_CHARSET\=utf8/g' .env
	sed -i 's/\#\#DB\_COLLATION\=utf8\_unicode\_ci/DB\_COLLATION\=utf8\_unicode\_ci/g' .env
	echo -e "\n"
fi
if [[  $LICENSE_INSTALLED == TRUE && $DF_CLEAN_INSTALLATION == FALSE ]]
then
	mkdir -p /opt/dreamfactory/storage/framework/cache/data/55/bd/
	php -q artisan migrate --seed
	sudo -u $CURRENT_USER bash -c "php -q artisan config:clear"
else
	sudo -u $CURRENT_USER bash -c "php -q artisan df:setup"
fi
chmod -R 2775 storage/ bootstrap/cache/
chown -R apache:$CURRENT_USER storage/ bootstrap/cache/
sudo -u $CURRENT_USER bash -c "php -q artisan cache:clear"

#Add rules if SELinux enabled
sestatus | grep SELinux | grep enabled > /dev/null 2>&1
if (( $? == 0 ))
then
	setsebool -P httpd_can_network_connect_db 1
	chcon -t httpd_sys_content_t storage -R
	chcon -t httpd_sys_content_t bootstrap/cache/ -R
	chcon -t httpd_sys_rw_content_t  storage -R
	chcon -t httpd_sys_rw_content_t  bootstrap/cache/ -R
fi

echo -e "\n${GN}Installation finished ${NC}!"
exit 0
