#!/bin/bash
#LEMP installation
#Colors schemes for echo:
RD='\033[0;31m' #Red
GN='\033[0;32m' #Green
MG='\033[0;95m' #Magenta
NC='\033[0m' # No Color

DEFAULT_PHP_VERSION="php7.2"

CURRENT_OS=$(cat /etc/os-release | grep VERSION_ID | cut -d "=" -f 2 | cut -c 2)

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
apt-get -qq update > /dev/null 
apt-get -qq install -y git \
	curl \
	zip \
	unzip \
	ca-certificates \
	apt-transport-https \
	software-properties-common \
	lsof \
	libmcrypt-dev \
	libreadline-dev \
	dirmngr

#Checking status of installation
if (( $? >= 1 ))
then
	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	exit 1
fi

echo -e "${GN}The prerequisites applications installed.\n${NC}"

echo -e "${GN}Step 2: Installing PHP...\n${NC}"

PHP_VERSION=${DEFAULT_PHP_VERSION}
PHP_VERSION_INDEX=$(echo $PHP_VERSION | cut -c 4-6)


# Install the php repository
curl -fsSL https://packages.sury.org/php/apt.gpg | apt-key add -
add-apt-repository "deb https://packages.sury.org/php/ $(lsb_release -cs) main"

# Update the system
apt-get -qq update 

apt-get -qq install -y ${PHP_VERSION}-common \
	${PHP_VERSION}-xml \
	${PHP_VERSION}-cli \
	${PHP_VERSION}-curl \
	${PHP_VERSION}-json \
	${PHP_VERSION}-mysqlnd \
	${PHP_VERSION}-sqlite \
	${PHP_VERSION}-soap \
	${PHP_VERSION}-mbstring \
	${PHP_VERSION}-zip \
	${PHP_VERSION}-bcmath \
	${PHP_VERSION}-dev \
	${PHP_VERSION}-fpm

if (( $? >= 1 ))
then
        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi

sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

echo -e "${GN}${PHP_VERSION} installed.\n${NC}"

echo -e "${GN}Step 3: Configure PHP Extensions...\n${NC}"

apt-get -qq install -y php-pear

if (( $? >= 1 ))
then
	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
        exit 1
fi

pecl channel-update pecl.php.net

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
	echo "extension=mcrypt.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/mcrypt.ini
	phpenmod mcrypt
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
	echo "extension=mongodb.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/mongodb.ini
	phpenmod mongodb
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
	curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
	if (( $CURRENT_OS == 8 ))
	then
		curl https://packages.microsoft.com/config/debian/8/prod.list > /etc/apt/sources.list.d/mssql-release.list
	elif (( $CURRENT_OS == 9 ))
	then
		curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list	
	else	
		echo -e "${RD} The script support only Debian 8 and 9 versions. Exit.\n ${NC}"
		exit 1
	fi
	apt-get -qq update  
	ACCEPT_EULA=Y apt-get -qq install -y msodbcsql17 mssql-tools unixodbc-dev
	su - $CURRENT_USER -c "echo export PATH=$PATH:/opt/mssql-tools/bin >> $HOME/.bash_profile"
	su - $CURRENT_USER -c "echo export PATH=$PATH:/opt/mssql-tools/bin >> $HOME/.bashrc"
	su - $CURRENT_USER -c "source $HOME/.bashrc"
	
	pecl -q install sqlsrv
	if (( $? >= 1 ))
	then
	        echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        exit 1
	fi
	echo "extension=sqlsrv.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/sqlsrv.ini
	phpenmod sqlsrv
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
	echo "extension=pdo_sqlsrv.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/pdo_sqlsrv.ini
	phpenmod pdo_sqlsrv
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
		apt-get -qq install -y libaio1
		echo -e "${MG}"
		if [[ -z $DRIVERS_PATH ]]
			then
			DRIVERS_PATH="."
		fi
		echo -e "${NC}"
		unzip "$DRIVERS_PATH/instantclient-*.zip" -d /opt/oracle > /dev/null 2>&1
	        echo "/opt/oracle/instantclient_18_3" > /etc/ld.so.conf.d/oracle-instantclient.conf
	        ldconfig
	        su $CURRENT_USER -c "echo export LD_LIBRARY_PATH=/opt/oracle/instantclient_18_3:$LD_LIBRARY_PATH >> $HOME/.bash_profile"
	        su $CURRENT_USER -c "echo export LD_LIBRARY_PATH=/opt/oracle/instantclient_18_3:$LD_LIBRARY_PATH >> $HOME/.bashrc"
	        su $CURRENT_USER -c "echo export PATH=/opt/oracle/instantclient_18_3:$PATH >> $HOME/.bash_profile"
	        su $CURRENT_USER -c "echo export PATH=/opt/oracle/instantclient_18_3:$PATH >> $HOME/.bashrc"
	        su $CURRENT_USER -c "source $HOME/.bashrc"
	        printf "instantclient,/opt/oracle/instantclient_18_3\n" | pecl -q install oci8
	        if (( $? >= 1 ))
		then
	        	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
	        	exit 1
		fi
		echo "extension=oci8.so" > /etc/php/${PHP_VERSION_INDEX}/mods-available/oci8.ini
	        phpenmod oci8
		
		php -m | grep oci8 > /dev/null 2>&1
		if (( $? >= 1 ))
	        then
	                echo -e  "${RD}\nExtension for OracleDB have errors...${NC}"
	        fi
		
	fi
fi
echo -e "${GN}PHP Extensions configured.\n${NC}"

echo -e "${GN}Step 4: Installing Nginx...\n${NC}"

# Check nginx installation in the system
ps aux | grep -v grep | grep nginx > /dev/null 2>&1
CHECK_NGINX_PROCESS=`echo $?`

dpkg -l | grep nginx | cut -d " " -f 3 | grep -E "nginx$" > /dev/null 2>&1
CHECK_NGINX_INSTALLATION=`echo $?`

if (( $CHECK_NGINX_PROCESS == 0 )) || (( $CHECK_NGINX_INSTALLATION == 0 ))
then
	echo -e  "${RD}Nginx detected in the system. Skipping installation Nginx. Configure Nginx manualy.\n${NC}"
else
        # Install nginx
        #Cheking running web server
        lsof -i :80 | grep LISTEN > /dev/null 2>&1
        if (( $? == 0 ))
        then
               	echo -e  "${RD}Some web server already running on http port.\n ${NC}"
               	echo -e  "${RD}Skipping installation Nginx. Install Nginx manualy.\n ${NC}"
        else
        	apt-get -qq install -y nginx
        	if (( $? >= 1 ))
            	  then
                	echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                	exit 1
        	fi
        # Change php fpm configuration file
        	sed -i 's/\;cgi\.fix\_pathinfo\=1/cgi\.fix\_pathinfo\=0/' $(php -i|sed -n '/^Loaded Configuration File => /{s:^.*> ::;p;}'| sed 's/cli/fpm/')	
        
        # Create nginx site entry
        	WEB_PATH=/etc/nginx/sites-available/default
                echo 'server {' > $WEB_PATH
                echo 'listen 80 default_server;' >> $WEB_PATH
                echo 'listen [::]:80 default_server ipv6only=on;' >> $WEB_PATH
                echo 'root /opt/dreamfactory/public;' >> $WEB_PATH
                echo 'index index.php index.html index.htm;' >> $WEB_PATH
                echo 'server_name server_domain_name_or_IP;' >> $WEB_PATH
                echo 'gzip on;' >> $WEB_PATH
                echo 'gzip_disable "msie6";' >> $WEB_PATH
                echo 'gzip_vary on;' >> $WEB_PATH
                echo 'gzip_proxied any;' >> $WEB_PATH
                echo 'gzip_comp_level 6;' >> $WEB_PATH
                echo 'gzip_buffers 16 8k;' >> $WEB_PATH
                echo 'gzip_http_version 1.1;' >> $WEB_PATH
                echo 'gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;' >> $WEB_PATH
                echo 'location / {' >> $WEB_PATH
                echo 'try_files $uri $uri/ /index.php?$args;}' >> $WEB_PATH
                echo 'error_page 404 /404.html;' >> $WEB_PATH
                echo 'error_page 500 502 503 504 /50x.html;' >> $WEB_PATH
                echo 'location = /50x.html {' >> $WEB_PATH
                echo 'root /usr/share/nginx/html;}' >> $WEB_PATH
                echo 'location ~ \.php$ {' >> $WEB_PATH
                echo 'try_files $uri =404;' >> $WEB_PATH
                echo 'fastcgi_split_path_info ^(.+\.php)(/.+)$;' >> $WEB_PATH
                echo "fastcgi_pass unix:/var/run/php/${PHP_VERSION}-fpm.sock;" >> $WEB_PATH
                echo 'fastcgi_index index.php;' >> $WEB_PATH
                echo 'fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' >> $WEB_PATH
                echo 'include fastcgi_params;}}' >> $WEB_PATH
        	
        
        	service ${PHP_VERSION}-fpm restart && service nginx restart
        
        	echo -e "${GN}Nginx installed.\n${NC}"
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

dpkg -l | grep mysql | cut -d " " -f 3 | grep -E "^mysql" | grep -E -v "^mysql-client" > /dev/null 2>&1
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
	if (( $CURRENT_OS == 8 ))
        then
        	apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
        	add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mariadb.petarmaric.com/repo/10.3/debian jessie main'
	elif (( $CURRENT_OS == 9 ))
        then
		apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
		add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mariadb.petarmaric.com/repo/10.3/debian stretch main'
	else
		echo -e "${RD} The script support only Debian 8 and 9 versions. Exit.\n ${NC}"
		exit 1
        fi
        
        apt-get -qq update
        apt-get -qq install -y mariadb-server
        
        if (( $? >= 1 ))
        then
                echo -e  "${RD}\nSome error while installing...Exit ${NC}"
                exit 1
        fi

	service mariadb start
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
	echo -e "${MG}Enter password for Database root user:\n ${NC} " 
	read -s DB_PASS
	
	# Test access to DB
	mysql -h localhost -u root -p$DB_PASS -e"quit" > /dev/null 2>&1
	if (( $? >= 1 ))
	then
		ACCESS=1
		until (( $ACCESS == 0 ))
		do
			echo -e "${RD}Password incorrect!\n ${NC}"
			echo -e "${MG}Enter correct password for root user:\n ${NC} "
			read -s DB_PASS
			mysql -h localhost -u root -p$DB_PASS -e"quit" > /dev/null 2>&1
			if (( $? == 0 ))
		       	then 
				ACCESS=0
		       	fi
		done        
	fi
	
	echo -e "${GN}Access confirmed.\n ${NC}"
	
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

su $CURRENT_USER -c "composer install --no-dev --ignore-platform-reqs"
if [[ $DB_INSTALLED == FALSE ]] 
then
	echo -e "\n "
	echo -e "${MG}******************************"
	echo -e "* DB for system table: mysql *"
	echo -e "* DB host: 127.0.0.1         *"
	echo -e "* DB port: 3306              *"
	echo -e "* DB name: dreamfactory      *"
	echo -e "* DB user: dfadmin           *"
	echo -e "* DB password: $(echo $DB_ADMIN_PASS | sed 's/['\'']//g')      *"
	echo -e "******************************${NC}\n"
	su $CURRENT_USER -c "php artisan df:env"
	sed -i 's/\#\#DB\_CHARSET\=utf8/DB\_CHARSET\=utf8/g' .env
	sed -i 's/\#\#DB\_COLLATION\=utf8\_unicode\_ci/DB\_COLLATION\=utf8\_unicode\_ci/g' .env
	echo -e "\n"
fi
if [[  $LICENSE_INSTALLED == TRUE && $DF_CLEAN_INSTALLATION == FALSE ]]
then
	mkdir -p /opt/dreamfactory/storage/framework/cache/data/55/bd/
	php artisan migrate --seed
	su $CURRENT_USER -c "php artisan config:clear"
else
	su $CURRENT_USER -c "php artisan df:setup"
fi
chmod -R 2775 storage/ bootstrap/cache/
chown -R www-data:$CURRENT_USER storage/ bootstrap/cache/
su $CURRENT_USER -c "php artisan cache:clear"
echo -e "\n${GN}Installation finished ${NC}!"
exit 0
